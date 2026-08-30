import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_page.dart';


class LoginPage
    extends StatefulWidget {

  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });


  final Future<void> Function()
  onAuthenticated;


  @override
  State<LoginPage>
  createState() =>
      _LoginPageState();
}


class _LoginPageState
    extends State<LoginPage> {

  final AuthService auth =
  AuthService();


  final phoneController =
  TextEditingController();

  final passwordController =
  TextEditingController();


  bool loading = false;

  bool hidePassword = true;


  Future<void> login() async {
    if (loading) return;


    final phone =
    phoneController.text.trim();

    final password =
        passwordController.text;


    if (
    phone.isEmpty ||
        password.isEmpty
    ) {
      showError(
        'Vui lòng nhập số điện thoại và mật khẩu.',
      );

      return;
    }


    setState(() {
      loading = true;
    });


    try {
      await auth.login(
        phone: phone,
        password: password,
      );

      if (!mounted) return;

      await widget.onAuthenticated();

    } catch (error) {
      if (!mounted) return;

      showError(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );

    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }


  Future<void> openRegister() async {

    final registered =
    await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const RegisterPage(),
      ),
    );


    if (
    registered != true ||
        !mounted
    ) {
      return;
    }


    // RegisterPage da dang ky thanh cong
    // va AuthService da luu JWT.
    await widget
        .onAuthenticated();
  }


  void showError(
      String text,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(text),
      ),
    );
  }


  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();

    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.all(24),

          children: [
            const SizedBox(
              height: 60,
            ),


            const CircleAvatar(
              radius: 48,

              child: Icon(
                Icons.local_taxi,
                size: 50,
              ),
            ),


            const SizedBox(
              height: 28,
            ),


            const Text(
              'Đăng nhập',
              textAlign:
              TextAlign.center,

              style: TextStyle(
                fontSize: 32,
                fontWeight:
                FontWeight.bold,
              ),
            ),


            const SizedBox(
              height: 8,
            ),


            const Text(
              'Đăng nhập để quản lý Zalo và nhận cuốc.',
              textAlign:
              TextAlign.center,
            ),


            const SizedBox(
              height: 40,
            ),


            TextField(
              controller:
              phoneController,

              keyboardType:
              TextInputType.phone,

              textInputAction:
              TextInputAction.next,

              decoration:
              const InputDecoration(
                labelText:
                'Số điện thoại',

                prefixIcon:
                Icon(
                  Icons.phone_outlined,
                ),

                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 16,
            ),


            TextField(
              controller:
              passwordController,

              obscureText:
              hidePassword,

              onSubmitted:
                  (_) => login(),

              decoration:
              InputDecoration(
                labelText:
                'Mật khẩu',

                prefixIcon:
                const Icon(
                  Icons.lock_outline,
                ),

                suffixIcon:
                IconButton(
                  onPressed: () {
                    setState(() {
                      hidePassword =
                      !hidePassword;
                    });
                  },

                  icon: Icon(
                    hidePassword
                        ? Icons
                        .visibility_outlined
                        : Icons
                        .visibility_off_outlined,
                  ),
                ),

                border:
                const OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 28,
            ),


            SizedBox(
              height: 56,

              child:
              FilledButton(
                onPressed:
                loading
                    ? null
                    : login,

                child:
                loading
                    ? const SizedBox(
                  width: 22,
                  height: 22,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
                    : const Text(
                  'ĐĂNG NHẬP',
                  style:
                  TextStyle(
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [
                const Text(
                  'Chưa có tài khoản?',
                ),

                TextButton(
                  onPressed:
                  openRegister,

                  child:
                  const Text(
                    'Đăng ký',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}