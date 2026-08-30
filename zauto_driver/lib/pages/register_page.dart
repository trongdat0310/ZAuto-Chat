import 'package:flutter/material.dart';

import '../services/auth_service.dart';


class RegisterPage
    extends StatefulWidget {
  const RegisterPage({
    super.key,
  });

  @override
  State<RegisterPage>
  createState() =>
      _RegisterPageState();
}


class _RegisterPageState
    extends State<RegisterPage> {

  final AuthService auth =
  AuthService();

  final nameController =
  TextEditingController();

  final phoneController =
  TextEditingController();

  final passwordController =
  TextEditingController();

  final confirmPasswordController =
  TextEditingController();
  String? nameError;
  String? phoneError;
  String? passwordError;
  String? confirmPasswordError;
  String? generalError;

  bool submitting = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool loading = false;

  Widget passwordRule(
      String text,
      bool passed,
      ) {

    return Row(
      mainAxisSize:
      MainAxisSize.min,

      children: [

        Icon(
          passed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,

          size: 17,

          color:
          passed
              ? Colors.green
              : Colors.grey,
        ),


        const SizedBox(
          width: 5,
        ),


        Text(
          text,

          style:
          TextStyle(
            fontSize: 12,

            color:
            passed
                ? Colors.green
                : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Future<void> register() async {

    if (submitting) {
      return;
    }


    final name =
    nameController.text.trim();

    final phone =
    phoneController.text.trim();

    final password =
        passwordController.text;

    final confirmPassword =
        confirmPasswordController.text;


    setState(() {
      nameError = null;
      phoneError = null;
      passwordError = null;
      confirmPasswordError = null;
      generalError = null;
    });


    bool valid = true;


    // ========================================
    // NAME
    // ========================================

    if (name.length < 2) {

      nameError =
      'Vui lòng nhập họ và tên';

      valid = false;
    }


    // ========================================
    // PHONE
    // ========================================

    if (phone.isEmpty) {

      phoneError =
      'Vui lòng nhập số điện thoại';

      valid = false;

    } else if (
    !RegExp(
      r'^[0-9]{9,15}$',
    ).hasMatch(phone)
    ) {

      phoneError =
      'Số điện thoại không hợp lệ';

      valid = false;
    }


    // ========================================
    // PASSWORD
    // ========================================

    final policyError =
    validateRegisterPassword(
      password,
    );


    if (policyError != null) {

      passwordError =
          policyError;

      valid = false;
    }


    // ========================================
    // CONFIRM PASSWORD
    // ========================================

    if (confirmPassword.isEmpty) {

      confirmPasswordError =
      'Vui lòng nhập lại mật khẩu';

      valid = false;

    } else if (
    confirmPassword !=
        password
    ) {

      confirmPasswordError =
      'Mật khẩu nhập lại không khớp';

      valid = false;
    }


    if (!valid) {

      setState(() {});

      return;
    }


    // ========================================
    // CALL API
    // ========================================

    setState(() {
      submitting = true;
    });


    try {

      await auth.register(
        name: name,
        phone: phone,
        password: password,
      );


      if (!mounted) {
        return;
      }


      // Đăng ký thành công.
      // Đóng RegisterPage và báo cho LoginPage.
      Navigator.of(context).pop(true);

    } catch (error) {

      if (!mounted) {
        return;
      }


      var message =
      error.toString()
          .replaceFirst(
        'Exception: ',
        '',
      );


      final lower =
      message.toLowerCase();


      setState(() {
        submitting = false;


        // So dien thoai da ton tai
        if (
        lower.contains(
          'phone',
        ) ||
            lower.contains(
              'so dien thoai',
            ) ||
            lower.contains(
              'điện thoại',
            ) ||
            lower.contains(
              'da ton tai',
            )
        ) {

          phoneError =
          'Số điện thoại này đã được đăng ký';

          return;
        }


        // Backend password policy
        if (
        lower.contains(
          'mat khau',
        )
        ) {

          passwordError =
          'Mật khẩu chưa đáp ứng yêu cầu';

          return;
        }


        generalError =
            message;
      });
    }
  }

  String? validateRegisterPassword(
      String password,
      ) {

    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }

    if (password.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }

    if (
    !RegExp(r'[A-Z]')
        .hasMatch(password)
    ) {
      return 'Cần ít nhất 1 chữ hoa A-Z';
    }

    if (
    !RegExp(r'[a-z]')
        .hasMatch(password)
    ) {
      return 'Cần ít nhất 1 chữ thường a-z';
    }

    if (
    !RegExp(r'[0-9]')
        .hasMatch(password)
    ) {
      return 'Cần ít nhất 1 chữ số 0-9';
    }

    if (
    !RegExp(
      r'[^A-Za-z0-9\s]',
    ).hasMatch(password)
    ) {
      return 'Cần ít nhất 1 ký tự đặc biệt';
    }

    return null;
  }


  void showError(
      String text,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }


  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {
    final password =
        passwordController.text;


    final hasLength =
        password.length >= 8;


    final hasUppercase =
    RegExp(
      r'[A-Z]',
    ).hasMatch(
      password,
    );


    final hasLowercase =
    RegExp(
      r'[a-z]',
    ).hasMatch(
      password,
    );


    final hasNumber =
    RegExp(
      r'[0-9]',
    ).hasMatch(
      password,
    );


    final hasSpecial =
    RegExp(
      r'[^A-Za-z0-9\s]',
    ).hasMatch(
      password,
    );

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Đăng ký',
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.all(24),

          children: [
            const SizedBox(
              height: 20,
            ),

            const Icon(
              Icons.person_add_alt_1,
              size: 72,
            ),

            const SizedBox(
              height: 24,
            ),

            const Text(
              'Tạo tài khoản',
              textAlign:
              TextAlign.center,

              style: TextStyle(
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Sau khi đăng ký bạn sẽ có thể liên kết tài khoản Zalo.',
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(
              height: 32,
            ),


            TextFormField(
              controller:
              nameController,

              onChanged: (_) {

                if (nameError != null) {

                  setState(() {
                    nameError = null;
                  });
                }
              },

              decoration:
              InputDecoration(
                labelText:
                'Họ và tên',

                border:
                const OutlineInputBorder(),

                errorText:
                nameError,
              ),
            ),


            const SizedBox(
              height: 16,
            ),


            TextFormField(
              controller:
              phoneController,

              keyboardType:
              TextInputType.phone,

              onChanged: (_) {

                if (phoneError != null) {

                  setState(() {
                    phoneError = null;
                  });
                }
              },

              decoration:
              InputDecoration(
                labelText:
                'Số điện thoại',

                border:
                const OutlineInputBorder(),

                errorText:
                phoneError,
              ),
            ),


            const SizedBox(
              height: 16,
            ),


            TextFormField(
              controller:
              passwordController,

              obscureText:
              hidePassword,

              enabled:
              !submitting,

              textInputAction:
              TextInputAction.next,

              onChanged: (value) {

                setState(() {
                  passwordError = null;
                  generalError = null;
                });
              },

              decoration:
              InputDecoration(

                labelText:
                'Mật khẩu',

                border:
                const OutlineInputBorder(),

                errorText:
                passwordError,

                suffixIcon:
                IconButton(

                  onPressed:
                  submitting
                      ? null
                      : () {

                    setState(() {
                      hidePassword =
                      !hidePassword;
                    });
                  },

                  icon:
                  Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),


            Wrap(
              spacing: 14,
              runSpacing: 8,

              children: [

                passwordRule(
                  '8+ ký tự',
                  hasLength,
                ),

                passwordRule(
                  'Chữ hoa A-Z',
                  hasUppercase,
                ),

                passwordRule(
                  'Chữ thường a-z',
                  hasLowercase,
                ),

                passwordRule(
                  'Số 0-9',
                  hasNumber,
                ),

                passwordRule(
                  'Ký tự đặc biệt',
                  hasSpecial,
                ),
              ],
            ),


            const SizedBox(
              height: 16,
            ),


            TextFormField(
              controller:
              confirmPasswordController,

              obscureText:
              hideConfirmPassword,

              enabled:
              !submitting,

              textInputAction:
              TextInputAction.done,

              onChanged: (value) {

                setState(() {
                  confirmPasswordError =
                  null;

                  generalError =
                  null;
                });
              },

              decoration:
              InputDecoration(

                labelText:
                'Nhập lại mật khẩu',

                border:
                const OutlineInputBorder(),

                errorText:
                confirmPasswordError,

                suffixIcon:
                IconButton(

                  onPressed:
                  submitting
                      ? null
                      : () {

                    setState(() {
                      hideConfirmPassword =
                      !hideConfirmPassword;
                    });
                  },

                  icon:
                  Icon(
                    hideConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),


// ========================================
// GENERAL ERROR
// ========================================

            if (generalError != null) ...[

              const SizedBox(
                height: 16,
              ),


              Container(
                padding:
                const EdgeInsets.all(
                  12,
                ),

                decoration:
                BoxDecoration(
                  color:
                  Theme.of(context)
                      .colorScheme
                      .errorContainer,

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Icon(
                      Icons.error_outline,

                      color:
                      Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                    ),


                    const SizedBox(
                      width: 10,
                    ),


                    Expanded(
                      child:
                      Text(
                        generalError!,

                        style:
                        TextStyle(
                          color:
                          Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],


            const SizedBox(
              height: 28,
            ),


// ========================================
// REGISTER BUTTON
// ========================================

            SizedBox(
              height: 56,

              child:
              FilledButton(
                onPressed:
                submitting
                    ? null
                    : register,

                child:
                submitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,

                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'ĐĂNG KÝ',

                  style:
                  TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}