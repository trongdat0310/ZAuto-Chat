import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService auth = AuthService();

  final nameController = TextEditingController();

  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  String? emailError;

  final passwordController = TextEditingController();

  final confirmPasswordController = TextEditingController();
  String? nameError;
  String? phoneError;
  String? passwordError;
  String? confirmPasswordError;
  String? generalError;

  bool submitting = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool acceptedTerms = false;

  bool loading = false;

  late final TapGestureRecognizer termsTapRecognizer;

  Future<void> openTermsOfService() async {
    final uri = Uri.parse(
      'https://zchatauto.io.vn/dieu-khoan-su-dung.html',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showError('Không thể mở trang điều khoản sử dụng');
      }
    } catch (_) {
      if (mounted) {
        showError('Không thể mở trang điều khoản sử dụng');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    termsTapRecognizer = TapGestureRecognizer()..onTap = openTermsOfService;
  }

  Widget passwordRule(String text, bool passed) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(
          passed ? Icons.check_circle : Icons.radio_button_unchecked,

          size: 17,

          color: passed ? Colors.green : Colors.grey,
        ),

        const SizedBox(width: 5),

        Text(
          text,

          style: TextStyle(
            fontSize: 12,

            color: passed ? Colors.green : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Future<void> register() async {
    if (submitting) {
      return;
    }

    final name = nameController.text.trim();

    final phone = phoneController.text.trim();
    final email = emailController.text.trim();

    final password = passwordController.text;

    final confirmPassword = confirmPasswordController.text;

    setState(() {
      nameError = null;
      phoneError = null;
      emailError = null;
      passwordError = null;
      confirmPasswordError = null;
      generalError = null;
    });

    bool valid = true;

    // ========================================
    // NAME
    // ========================================

    if (name.length < 2) {
      nameError = 'Vui lòng nhập họ và tên';

      valid = false;
    }

    // ========================================
    // PHONE
    // ========================================

    if (phone.isEmpty) {
      phoneError = 'Vui lòng nhập số điện thoại';

      valid = false;
    } else if (!RegExp(r'^[0-9]{9,15}$').hasMatch(phone)) {
      phoneError = 'Số điện thoại không hợp lệ';

      valid = false;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      emailError = 'Vui lòng nhập email hợp lệ';
      valid = false;
    }

    // ========================================
    // PASSWORD
    // ========================================

    final policyError = validateRegisterPassword(password);

    if (policyError != null) {
      passwordError = policyError;

      valid = false;
    }

    // ========================================
    // CONFIRM PASSWORD
    // ========================================

    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Vui lòng nhập lại mật khẩu';

      valid = false;
    } else if (confirmPassword != password) {
      confirmPasswordError = 'Mật khẩu nhập lại không khớp';

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
      await auth.register(name: name, phone: phone, email: email, password: password);

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

      var message = error.toString().replaceFirst('Exception: ', '');

      final lower = message.toLowerCase();

      setState(() {
        submitting = false;

        // So dien thoai da ton tai
        if (lower.contains('phone') ||
            lower.contains('so dien thoai') ||
            lower.contains('điện thoại') ||
            lower.contains('da ton tai')) {
          phoneError = 'Số điện thoại này đã được đăng ký';

          return;
        }

        if (lower.contains('email')) {
          emailError = message;
          return;
        }

        // Backend password policy
        if (lower.contains('mat khau')) {
          passwordError = 'Mật khẩu chưa đáp ứng yêu cầu';

          return;
        }

        generalError = message;
      });
    }
  }

  String? validateRegisterPassword(String password) {
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }

    if (password.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Cần ít nhất 1 chữ hoa A-Z';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Cần ít nhất 1 chữ thường a-z';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Cần ít nhất 1 chữ số 0-9';
    }

    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      return 'Cần ít nhất 1 ký tự đặc biệt';
    }

    return null;
  }

  void showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    termsTapRecognizer.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const formBlue = Color(0xFF2376CE);
    const formBorder = Color(0xFFC5C7CD);
    final password = passwordController.text;
    final canSubmit = !submitting && acceptedTerms;

    InputDecoration fieldDecoration({
      required String hint,
      required IconData icon,
      String? errorText,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon, size: 27, color: colors.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFFB5B7BF), fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: formBorder,
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: formBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.error, width: 1.6),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 42,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Quay lại',
                      onPressed: submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 32),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Center(
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/AvatarApp.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Đăng ký ZChatAuto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Đăng ký tài khoản mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),

                  TextFormField(
                    controller: nameController,
                    enabled: !submitting,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onChanged: (_) {
                      if (nameError != null) {
                        setState(() => nameError = null);
                      }
                    },
                    decoration: fieldDecoration(
                      hint: 'Họ và tên',
                      icon: Icons.person_rounded,
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 22),

                  TextFormField(
                    controller: phoneController,
                    enabled: !submitting,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onChanged: (_) {
                      if (phoneError != null) {
                        setState(() => phoneError = null);
                      }
                    },
                    decoration: fieldDecoration(
                      hint: 'Số điện thoại',
                      icon: Icons.phone_rounded,
                      errorText: phoneError,
                    ),
                  ),
                  const SizedBox(height: 22),

                  TextFormField(
                    controller: emailController,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (emailError != null) {
                        setState(() => emailError = null);
                      }
                    },
                    decoration: fieldDecoration(
                      hint: 'Email',
                      icon: Icons.email_rounded,
                      errorText: emailError,
                    ),
                  ),
                  const SizedBox(height: 22),

                  TextFormField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    enabled: !submitting,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) {
                      setState(() {
                        passwordError = null;
                        generalError = null;
                      });
                    },
                    decoration: fieldDecoration(
                      hint: 'Mật khẩu',
                      icon: Icons.lock_rounded,
                      errorText: passwordError,
                      suffixIcon: IconButton(
                        onPressed: submitting
                            ? null
                            : () => setState(
                                  () => hidePassword = !hidePassword,
                                ),
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),

                  if (password.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 7,
                      children: [
                        passwordRule('8+ ký tự', password.length >= 8),
                        passwordRule(
                          'Chữ hoa A-Z',
                          RegExp(r'[A-Z]').hasMatch(password),
                        ),
                        passwordRule(
                          'Chữ thường a-z',
                          RegExp(r'[a-z]').hasMatch(password),
                        ),
                        passwordRule(
                          'Số 0-9',
                          RegExp(r'[0-9]').hasMatch(password),
                        ),
                        passwordRule(
                          'Ký tự đặc biệt',
                          RegExp(r'[^A-Za-z0-9\\s]').hasMatch(password),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),

                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: hideConfirmPassword,
                    enabled: !submitting,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) {
                      setState(() {
                        confirmPasswordError = null;
                        generalError = null;
                      });
                    },
                    onFieldSubmitted: (_) {
                      if (canSubmit) register();
                    },
                    decoration: fieldDecoration(
                      hint: 'Nhập lại mật khẩu',
                      icon: Icons.lock_rounded,
                      errorText: confirmPasswordError,
                      suffixIcon: IconButton(
                        onPressed: submitting
                            ? null
                            : () => setState(
                                  () => hideConfirmPassword =
                                      !hideConfirmPassword,
                                ),
                        icon: Icon(
                          hideConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),

                  if (generalError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        generalError!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: acceptedTerms,
                            onChanged: submitting
                                ? null
                                : (value) => setState(
                                      () => acceptedTerms = value ?? false,
                                    ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(fontSize: 15.5),
                                children: [
                                  const TextSpan(text: 'Tôi đồng ý với '),
                                  TextSpan(
                                    text: 'Điều kiện & điều khoản',
                                    recognizer: termsTapRecognizer,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: canSubmit ? register : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: formBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Tiếp tục',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(
                        child: Text(
                          'Bạn đã có tài khoản? ',
                          style: TextStyle(fontSize: 15.5),
                        ),
                      ),
                      InkWell(
                        onTap: submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(
                          'Đăng nhập',
                          style: TextStyle(
                            color: formBlue,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
