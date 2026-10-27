import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onAuthenticated});

  final Future<void> Function() onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService auth = AuthService();

  final phoneController = TextEditingController();

  final passwordController = TextEditingController();

  bool loading = false;

  bool hidePassword = true;

  Future<void> login() async {
    if (loading) return;

    final phone = phoneController.text.trim();

    final password = passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      showError('Vui lòng nhập email hoặc số điện thoại và mật khẩu.');

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final user = await auth.login(phone: phone, password: password);

      if (!mounted) return;
      if (user['mustChangePassword'] == true) {
        final changed = await _forcePasswordChange(password);
        if (!changed || !mounted) return;
      }
      await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;

      showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<bool> _forcePasswordChange(String temporaryPassword) async {
    String newPassword = '';
    String confirmPassword = '';

    String? newPasswordError;
    String? confirmPasswordError;
    String? generalError;

    bool submitting = false;

    bool hideNewPassword = true;
    bool hideConfirmPassword = true;

    final success = await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;

            // ========================================
            // PASSWORD RULE STATES
            // ========================================

            final hasLength = newPassword.length >= 8;

            final hasUppercase = RegExp(r'[A-Z]').hasMatch(newPassword);

            final hasLowercase = RegExp(r'[a-z]').hasMatch(newPassword);

            final hasNumber = RegExp(r'[0-9]').hasMatch(newPassword);

            final hasSpecial = RegExp(r'[^A-Za-z0-9\s]').hasMatch(newPassword);

            // ========================================
            // PASSWORD RULE WIDGET
            // ========================================

            Widget passwordRule(String text, bool passed) {
              return Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Icon(
                    passed ? Icons.check_circle : Icons.radio_button_unchecked,

                    size: 17,

                    color: passed
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 5),

                  Text(
                    text,

                    style: TextStyle(
                      fontSize: 12,

                      color: passed
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }

            // ========================================
            // SUBMIT
            // ========================================

            Future<void> submit() async {
              if (submitting) {
                return;
              }

              setDialogState(() {
                currentPasswordError = null;

                newPasswordError = null;

                confirmPasswordError = null;

                generalError = null;
              });

              bool valid = true;

              // ========================================
              // NEW PASSWORD POLICY
              // ========================================

              if (newPassword.isEmpty) {
                newPasswordError = 'Vui lòng nhập mật khẩu mới';

                valid = false;
              } else if (!hasLength) {
                newPasswordError = 'Mật khẩu phải có ít nhất 8 ký tự';

                valid = false;
              } else if (!hasUppercase) {
                newPasswordError = 'Cần ít nhất 1 chữ hoa A-Z';

                valid = false;
              } else if (!hasLowercase) {
                newPasswordError = 'Cần ít nhất 1 chữ thường a-z';

                valid = false;
              } else if (!hasNumber) {
                newPasswordError = 'Cần ít nhất 1 chữ số 0-9';

                valid = false;
              } else if (!hasSpecial) {
                newPasswordError = 'Cần ít nhất 1 ký tự đặc biệt';

                valid = false;
              }

              // ========================================
              // CONFIRM
              // ========================================

              if (confirmPassword.isEmpty) {
                confirmPasswordError = 'Vui lòng nhập lại mật khẩu mới';

                valid = false;
              } else if (confirmPassword != newPassword) {
                confirmPasswordError = 'Mật khẩu nhập lại không khớp';

                valid = false;
              }

              if (!valid) {
                setDialogState(() {});

                return;
              }

              // ========================================
              // CALL BACKEND
              // ========================================

              setDialogState(() {
                submitting = true;
              });

              try {
                await auth.changeRecoveredPassword(
                  currentPassword: temporaryPassword,

                  newPassword: newPassword,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                var message = error.toString();

                message = message.replaceFirst('Exception: ', '');

                setDialogState(() {
                  submitting = false;

                  generalError = message;
                });
              }
            }

            // ========================================
            // DIALOG
            // ========================================

            return PopScope(
              canPop: false,
              child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),

              title: const Text('Bắt buộc đổi mật khẩu'),

              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      // ========================================
                      // NEW PASSWORD
                      // ========================================
                      TextFormField(
                        obscureText: hideNewPassword,

                        enabled: !submitting,

                        textInputAction: TextInputAction.next,

                        onChanged: (value) {
                          // Quan trong:
                          // rebuild checklist moi lan go.
                          setDialogState(() {
                            newPassword = value;

                            newPasswordError = null;

                            generalError = null;
                          });
                        },

                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',

                          border: const OutlineInputBorder(),

                          errorText: newPasswordError,

                          suffixIcon: IconButton(
                            onPressed: submitting
                                ? null
                                : () {
                                    setDialogState(() {
                                      hideNewPassword = !hideNewPassword;
                                    });
                                  },

                            icon: Icon(
                              hideNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ========================================
                      // REALTIME PASSWORD CHECKLIST
                      // ========================================
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,

                        children: [
                          passwordRule('8+ ký tự', hasLength),

                          passwordRule('Chữ hoa A-Z', hasUppercase),

                          passwordRule('Chữ thường a-z', hasLowercase),

                          passwordRule('Số 0-9', hasNumber),

                          passwordRule('Ký tự đặc biệt', hasSpecial),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ========================================
                      // CONFIRM PASSWORD
                      // ========================================
                      TextFormField(
                        obscureText: hideConfirmPassword,

                        enabled: !submitting,

                        textInputAction: TextInputAction.done,

                        onChanged: (value) {
                          setDialogState(() {
                            confirmPassword = value;

                            confirmPasswordError = null;
                          });
                        },

                        onFieldSubmitted: (_) {
                          if (!submitting) {
                            submit();
                          }
                        },

                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',

                          border: const OutlineInputBorder(),

                          errorText: confirmPasswordError,

                          suffixIcon: IconButton(
                            onPressed: submitting
                                ? null
                                : () {
                                    setDialogState(() {
                                      hideConfirmPassword =
                                          !hideConfirmPassword;
                                    });
                                  },

                            icon: Icon(
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
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,

                            borderRadius: BorderRadius.circular(8),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Icon(
                                Icons.error_outline,

                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  generalError!,

                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (submitting) ...[
                        const SizedBox(height: 18),

                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),

              actions: [
                FilledButton(
                  onPressed: submitting ? null : submit,

                  child: Text(submitting ? 'ĐANG ĐỔI...' : 'ĐỔI MẬT KHẨU'),
                ),
              ],
              ),
            );
          },
        );
      },
    );

    return success == true;
  }

  Future<void> forgotPassword() async {
    String email = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quên mật khẩu'),
        content: TextFormField(
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onChanged: (value) => email = value.trim(),
          decoration: const InputDecoration(labelText: 'Email đã đăng ký'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Gửi')),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      showError('Vui lòng nhập email hợp lệ.');
      return;
    }
    try {
      await auth.forgotPassword(email);
      if (mounted) {
        showError('Nếu email đã đăng ký, mật khẩu mới sẽ được gửi đến hộp thư.');
      }
    } catch (error) {
      if (mounted) showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> openRegister() async {
    final registered = await Navigator.push<bool>(
      context,

      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );

    if (registered != true || !mounted) {
      return;
    }

    // RegisterPage da dang ky thanh cong
    // va AuthService da luu JWT.
    await widget.onAuthenticated();
  }

  void showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),

          children: [
            const SizedBox(height: 60),

            const CircleAvatar(
              radius: 48,

              child: Icon(Icons.local_taxi, size: 50),
            ),

            const SizedBox(height: 28),

            const Text(
              'Đăng nhập',
              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Đăng nhập để quản lý Zalo và nhận cuốc.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            TextField(
              controller: phoneController,

              keyboardType: TextInputType.emailAddress,

              textInputAction: TextInputAction.next,

              decoration: const InputDecoration(
                labelText: 'Email hoặc số điện thoại',

                prefixIcon: Icon(Icons.person_outline),

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,

              obscureText: hidePassword,

              onSubmitted: (_) => login(),

              decoration: InputDecoration(
                labelText: 'Mật khẩu',

                prefixIcon: const Icon(Icons.lock_outline),

                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },

                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),

                border: const OutlineInputBorder(),
              ),
            ),

            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: forgotPassword, child: const Text("Quên mật khẩu?"))),

            const SizedBox(height: 12),

            SizedBox(
              height: 56,

              child: FilledButton(
                onPressed: loading ? null : login,

                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'ĐĂNG NHẬP',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                const Text('Chưa có tài khoản?'),

                TextButton(
                  onPressed: openRegister,

                  child: const Text('Đăng ký'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
