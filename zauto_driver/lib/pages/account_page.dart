import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';


class AccountPage
    extends StatefulWidget {

  final Future<void> Function()
  onLogout;

  final Future<void> Function()
  onAuthChanged;

  final Future<void> Function()
  onAccountDeleted;


  const AccountPage({
    super.key,
    required this.onLogout,
    required this.onAuthChanged,
    required this.onAccountDeleted,
  });


  @override
  State<AccountPage>
  createState() =>
      _AccountPageState();
}


class _AccountPageState
    extends State<AccountPage> {

  final BackendService backend =
  BackendService(
    baseUrl:
    AppConfig.backendUrl,
  );


  Map<String, dynamic>?
  profile;


  bool loading =
  true;


  bool unlinking =
  false;


  String? error;


  Timer? refreshTimer;


  @override
  void initState() {
    super.initState();

    loadProfile();


    refreshTimer =
        Timer.periodic(
          const Duration(
            seconds: 10,
          ),

              (_) {
            loadProfile(
              silent: true,
            );
          },
        );
  }


  @override
  void dispose() {

    refreshTimer?.cancel();

    super.dispose();
  }


  // ========================================
  // LOAD PROFILE
  // ========================================

  Future<void> loadProfile({
    bool silent = false,
  }) async {

    if (!silent) {

      setState(() {
        loading = true;
        error = null;
      });
    }


    try {

      final result =
      await backend
          .getProfile();


      if (!mounted) {
        return;
      }


      setState(() {
        profile = result;
        loading = false;
        error = null;
      });

    } catch (e) {

      if (!mounted) {
        return;
      }


      setState(() {
        loading = false;

        if (!silent) {
          error =
              e.toString();
        }
      });
    }
  }

  Future<void> editName() async {

    final currentName =
        profile?['user']?['name']
            ?.toString() ??
            '';


    String draftName =
        currentName;


    final newName =
    await showDialog<String>(
      context:
      context,

      barrierDismissible:
      false,

      builder:
          (dialogContext) {

        return AlertDialog(
          title:
          const Text(
            'Đổi tên',
          ),

          content:
          TextFormField(
            initialValue:
            currentName,

            autofocus:
            true,

            textInputAction:
            TextInputAction.done,

            onChanged:
                (value) {

              draftName =
                  value;
            },

            onFieldSubmitted:
                (value) {

              Navigator.of(
                dialogContext,
              ).pop(
                value.trim(),
              );
            },

            decoration:
            const InputDecoration(
              labelText:
              'Tên hiển thị',

              border:
              OutlineInputBorder(),
            ),
          ),

          actions: [

            TextButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop();
              },

              child:
              const Text(
                'HỦY',
              ),
            ),


            FilledButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop(
                  draftName.trim(),
                );
              },

              child:
              const Text(
                'LƯU',
              ),
            ),
          ],
        );
      },
    );


    if (!mounted) {
      return;
    }


    if (
    newName == null ||
        newName.trim().isEmpty
    ) {
      return;
    }


    if (
    newName.trim() ==
        currentName.trim()
    ) {

      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Tên không thay đổi',
          ),
        ),
      );

      return;
    }


    try {

      await backend
          .updateProfileName(
        newName.trim(),
      );


      if (!mounted) {
        return;
      }


      // Chỉ refresh AccountPage.
      // KHÔNG refresh AuthGate.
      await loadProfile(
        silent: true,
      );


      if (!mounted) {
        return;
      }


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Đã cập nhật tên',
          ),
        ),
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Lỗi: $error',
          ),
        ),
      );
    }
  }

  Future<void> changePassword() async {

    String currentPassword = '';
    String newPassword = '';
    String confirmPassword = '';

    String? currentPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    String? generalError;

    bool submitting = false;

    bool hideCurrentPassword = true;
    bool hideNewPassword = true;
    bool hideConfirmPassword = true;


    final success =
    await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {

        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {

            // ========================================
            // PASSWORD RULE STATES
            // ========================================

            final hasLength =
                newPassword.length >= 8;

            final hasUppercase =
            RegExp(
              r'[A-Z]',
            ).hasMatch(
              newPassword,
            );

            final hasLowercase =
            RegExp(
              r'[a-z]',
            ).hasMatch(
              newPassword,
            );

            final hasNumber =
            RegExp(
              r'[0-9]',
            ).hasMatch(
              newPassword,
            );

            final hasSpecial =
            RegExp(
              r'[^A-Za-z0-9\s]',
            ).hasMatch(
              newPassword,
            );


            // ========================================
            // PASSWORD RULE WIDGET
            // ========================================

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
                        : Icons
                        .radio_button_unchecked,

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
                          : Colors
                          .grey
                          .shade700,
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
                currentPasswordError =
                null;

                newPasswordError =
                null;

                confirmPasswordError =
                null;

                generalError =
                null;
              });


              bool valid =
              true;


              // ========================================
              // CURRENT PASSWORD
              // ========================================

              if (
              currentPassword.isEmpty
              ) {

                currentPasswordError =
                'Vui lòng nhập mật khẩu hiện tại';

                valid =
                false;
              }


              // ========================================
              // NEW PASSWORD POLICY
              // ========================================

              if (newPassword.isEmpty) {

                newPasswordError =
                'Vui lòng nhập mật khẩu mới';

                valid =
                false;

              } else if (!hasLength) {

                newPasswordError =
                'Mật khẩu phải có ít nhất 8 ký tự';

                valid =
                false;

              } else if (!hasUppercase) {

                newPasswordError =
                'Cần ít nhất 1 chữ hoa A-Z';

                valid =
                false;

              } else if (!hasLowercase) {

                newPasswordError =
                'Cần ít nhất 1 chữ thường a-z';

                valid =
                false;

              } else if (!hasNumber) {

                newPasswordError =
                'Cần ít nhất 1 chữ số 0-9';

                valid =
                false;

              } else if (!hasSpecial) {

                newPasswordError =
                'Cần ít nhất 1 ký tự đặc biệt';

                valid =
                false;

              } else if (
              newPassword ==
                  currentPassword
              ) {

                newPasswordError =
                'Mật khẩu mới phải khác mật khẩu hiện tại';

                valid =
                false;
              }


              // ========================================
              // CONFIRM
              // ========================================

              if (
              confirmPassword.isEmpty
              ) {

                confirmPasswordError =
                'Vui lòng nhập lại mật khẩu mới';

                valid =
                false;

              } else if (
              confirmPassword !=
                  newPassword
              ) {

                confirmPasswordError =
                'Mật khẩu nhập lại không khớp';

                valid =
                false;
              }


              if (!valid) {

                setDialogState(() {});

                return;
              }


              // ========================================
              // CALL BACKEND
              // ========================================

              setDialogState(() {
                submitting =
                true;
              });


              try {

                await backend
                    .changePassword(
                  currentPassword:
                  currentPassword,

                  newPassword:
                  newPassword,
                );


                if (
                !dialogContext.mounted
                ) {
                  return;
                }


                Navigator.of(
                  dialogContext,
                ).pop(true);

              } catch (error) {

                if (
                !dialogContext.mounted
                ) {
                  return;
                }


                var message =
                error.toString();


                message =
                    message.replaceFirst(
                      'Exception: ',
                      '',
                    );


                setDialogState(() {

                  submitting =
                  false;


                  final lower =
                  message
                      .toLowerCase();


                  if (
                  lower.contains(
                    'mat khau hien tai khong dung',
                  )
                  ) {

                    currentPasswordError =
                    'Mật khẩu hiện tại không đúng';

                  } else {

                    generalError =
                        message;
                  }
                });
              }
            }


            // ========================================
            // DIALOG
            // ========================================

            return AlertDialog(

              insetPadding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
                vertical: 24,
              ),


              title:
              const Text(
                'Đổi mật khẩu',
              ),


              content:
              SingleChildScrollView(

                child:
                SizedBox(

                  width:
                  double.maxFinite,


                  child:
                  Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,

                    children: [

                      // ========================================
                      // CURRENT PASSWORD
                      // ========================================

                      TextFormField(
                        autofocus: true,

                        obscureText:
                        hideCurrentPassword,

                        enabled:
                        !submitting,

                        textInputAction:
                        TextInputAction.next,

                        onChanged:
                            (value) {

                          setDialogState(() {

                            currentPassword =
                                value;

                            currentPasswordError =
                            null;
                          });
                        },

                        decoration:
                        InputDecoration(

                          labelText:
                          'Mật khẩu hiện tại',

                          border:
                          const OutlineInputBorder(),

                          errorText:
                          currentPasswordError,

                          suffixIcon:
                          IconButton(

                            onPressed:
                            submitting
                                ? null
                                : () {

                              setDialogState(
                                    () {

                                  hideCurrentPassword =
                                  !hideCurrentPassword;
                                },
                              );
                            },

                            icon:
                            Icon(

                              hideCurrentPassword
                                  ? Icons
                                  .visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),


                      const SizedBox(
                        height: 16,
                      ),


                      // ========================================
                      // NEW PASSWORD
                      // ========================================

                      TextFormField(
                        obscureText:
                        hideNewPassword,

                        enabled:
                        !submitting,

                        textInputAction:
                        TextInputAction.next,

                        onChanged:
                            (value) {

                          // Quan trong:
                          // rebuild checklist moi lan go.
                          setDialogState(() {

                            newPassword =
                                value;

                            newPasswordError =
                            null;

                            generalError =
                            null;
                          });
                        },

                        decoration:
                        InputDecoration(

                          labelText:
                          'Mật khẩu mới',

                          border:
                          const OutlineInputBorder(),

                          errorText:
                          newPasswordError,

                          suffixIcon:
                          IconButton(

                            onPressed:
                            submitting
                                ? null
                                : () {

                              setDialogState(
                                    () {

                                  hideNewPassword =
                                  !hideNewPassword;
                                },
                              );
                            },

                            icon:
                            Icon(

                              hideNewPassword
                                  ? Icons
                                  .visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),


                      const SizedBox(
                        height: 10,
                      ),


                      // ========================================
                      // REALTIME PASSWORD CHECKLIST
                      // ========================================

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
                        height: 18,
                      ),


                      // ========================================
                      // CONFIRM PASSWORD
                      // ========================================

                      TextFormField(
                        obscureText:
                        hideConfirmPassword,

                        enabled:
                        !submitting,

                        textInputAction:
                        TextInputAction.done,

                        onChanged:
                            (value) {

                          setDialogState(() {

                            confirmPassword =
                                value;

                            confirmPasswordError =
                            null;
                          });
                        },

                        onFieldSubmitted:
                            (_) {

                          if (!submitting) {
                            submit();
                          }
                        },

                        decoration:
                        InputDecoration(

                          labelText:
                          'Nhập lại mật khẩu mới',

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

                              setDialogState(
                                    () {

                                  hideConfirmPassword =
                                  !hideConfirmPassword;
                                },
                              );
                            },

                            icon:
                            Icon(

                              hideConfirmPassword
                                  ? Icons
                                  .visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),


                      // ========================================
                      // GENERAL ERROR
                      // ========================================

                      if (
                      generalError !=
                          null
                      ) ...[

                        const SizedBox(
                          height: 16,
                        ),


                        Container(
                          padding:
                          const EdgeInsets
                              .all(
                            12,
                          ),

                          decoration:
                          BoxDecoration(

                            color:
                            Theme.of(
                              context,
                            )
                                .colorScheme
                                .errorContainer,

                            borderRadius:
                            BorderRadius
                                .circular(
                              8,
                            ),
                          ),

                          child:
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              Icon(
                                Icons
                                    .error_outline,

                                color:
                                Theme.of(
                                  context,
                                )
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
                                    Theme.of(
                                      context,
                                    )
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

                        const SizedBox(
                          height: 18,
                        ),

                        const Center(
                          child:
                          CircularProgressIndicator(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),


              actions: [

                TextButton(
                  onPressed:
                  submitting
                      ? null
                      : () {

                    Navigator.of(
                      dialogContext,
                    ).pop(
                      false,
                    );
                  },

                  child:
                  const Text(
                    'HỦY',
                  ),
                ),


                FilledButton(
                  onPressed:
                  submitting
                      ? null
                      : submit,

                  child:
                  Text(
                    submitting
                        ? 'ĐANG ĐỔI...'
                        : 'ĐỔI MẬT KHẨU',
                  ),
                ),
              ],
            );
          },
        );
      },
    );


    // ========================================
    // SUCCESS
    // ========================================

    if (
    success != true ||
        !mounted
    ) {
      return;
    }


    ScaffoldMessenger
        .of(context)
        .showSnackBar(

      const SnackBar(
        content:
        Text(
          'Đổi mật khẩu thành công',
        ),
      ),
    );
  }

  Future<void> deleteAccount() async {

    String password = '';

    String? passwordError;
    String? generalError;

    bool deleting = false;
    bool hidePassword = true;


    final deleted =
    await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {

        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {

            Future<void> submit() async {

              if (deleting) {
                return;
              }


              setDialogState(() {
                passwordError = null;
                generalError = null;
              });


              if (password.isEmpty) {

                setDialogState(() {
                  passwordError =
                  'Vui lòng nhập mật khẩu để xác nhận';
                });

                return;
              }


              setDialogState(() {
                deleting = true;
              });


              try {

                await backend
                    .deleteAccount(
                  password,
                );


                if (
                !dialogContext.mounted
                ) {
                  return;
                }


                Navigator.of(
                  dialogContext,
                ).pop(true);

              } catch (error) {

                if (
                !dialogContext.mounted
                ) {
                  return;
                }


                var message =
                error
                    .toString()
                    .replaceFirst(
                  'Exception: ',
                  '',
                );


                final lower =
                message.toLowerCase();


                setDialogState(() {

                  deleting = false;


                  if (
                  lower.contains(
                    'mat khau khong dung',
                  ) ||
                      lower.contains(
                        'mật khẩu không đúng',
                      )
                  ) {

                    passwordError =
                    'Mật khẩu không đúng';

                  } else {

                    generalError =
                        message;
                  }
                });
              }
            }


            return AlertDialog(

              insetPadding:
              const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),


              title:
              const Row(
                children: [

                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      'Xóa tài khoản?',
                    ),
                  ),
                ],
              ),


              content:
              SingleChildScrollView(

                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,

                  children: [

                    const Text(
                      'Hành động này sẽ xóa vĩnh viễn tài khoản và dữ liệu ZAUTO của bạn.',
                    ),


                    const SizedBox(
                      height: 12,
                    ),


                    const Text(
                      'Dữ liệu sẽ bị xóa:',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),


                    const SizedBox(
                      height: 6,
                    ),


                    const Text(
                      '• Phiên Zalo đã liên kết\n'
                          '• Nhóm theo dõi\n'
                          '• Bộ lọc\n'
                          '• Lịch sử cuốc\n'
                          '• Thiết bị nhận thông báo',
                    ),


                    const SizedBox(
                      height: 20,
                    ),


                    TextFormField(
                      autofocus: true,

                      obscureText:
                      hidePassword,

                      enabled:
                      !deleting,

                      textInputAction:
                      TextInputAction.done,

                      onChanged:
                          (value) {

                        setDialogState(() {
                          password =
                              value;

                          passwordError =
                          null;

                          generalError =
                          null;
                        });
                      },

                      onFieldSubmitted:
                          (_) {

                        if (!deleting) {
                          submit();
                        }
                      },

                      decoration:
                      InputDecoration(
                        labelText:
                        'Nhập mật khẩu để xác nhận',

                        border:
                        const OutlineInputBorder(),

                        errorText:
                        passwordError,

                        suffixIcon:
                        IconButton(
                          onPressed:
                          deleting
                              ? null
                              : () {

                            setDialogState(() {
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


                    if (
                    generalError != null
                    ) ...[

                      const SizedBox(
                        height: 14,
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
                            8,
                          ),
                        ),

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


                    if (deleting) ...[

                      const SizedBox(
                        height: 18,
                      ),

                      const Center(
                        child:
                        CircularProgressIndicator(),
                      ),
                    ],
                  ],
                ),
              ),


              actions: [

                TextButton(
                  onPressed:
                  deleting
                      ? null
                      : () {

                    Navigator.of(
                      dialogContext,
                    ).pop(false);
                  },

                  child:
                  const Text(
                    'HỦY',
                  ),
                ),


                FilledButton(
                  onPressed:
                  deleting
                      ? null
                      : submit,

                  style:
                  FilledButton.styleFrom(
                    backgroundColor:
                    Colors.red,
                  ),

                  child:
                  Text(
                    deleting
                        ? 'ĐANG XÓA...'
                        : 'XÓA TÀI KHOẢN',
                  ),
                ),
              ],
            );
          },
        );
      },
    );


    if (
    deleted != true ||
        !mounted
    ) {
      return;
    }


    // Backend da xoa user.
    // Bay gio chi xoa JWT local
    // va quay ve Login.
    await widget
        .onAccountDeleted();
  }

  // ========================================
  // STATUS LABEL
  // ========================================

  String workerLabel(
      String status,
      ) {

    switch (status) {

      case 'running':
        return 'Hoạt động';

      case 'reconnecting':
        return 'Đang kết nối lại';

      case 'offline':
        return 'Đang chờ Internet';

      case 'needs_relink':
        return 'Cần liên kết lại Zalo';

      case 'starting':
        return 'Đang khởi động';

      case 'error':
        return 'Có lỗi';

      default:
        return 'Đã dừng';
    }
  }


  Color workerColor(
      BuildContext context,
      String status,
      ) {

    switch (status) {

      case 'running':
        return Colors.green;

      case 'reconnecting':
      case 'starting':
        return Colors.orange;

      case 'offline':
        return Colors.orange;

      case 'needs_relink':
      case 'error':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }


  // ========================================
  // RELINK
  // ========================================

  Future<void> relinkZalo() async {

    final confirmed =
    await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {

        return AlertDialog(
          title:
          const Text(
            'Liên kết lại Zalo',
          ),

          content:
          const Text(
            'Phiên Zalo hiện tại sẽ được xóa và bạn sẽ cần quét mã QR để liên kết lại.',
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.of(
                  dialogContext,
                ).pop(false);
              },

              child:
              const Text(
                'HỦY',
              ),
            ),


            FilledButton(
              onPressed: () {

                Navigator.of(
                  dialogContext,
                ).pop(true);
              },

              child:
              const Text(
                'TIẾP TỤC',
              ),
            ),
          ],
        );
      },
    );


    if (confirmed != true) {
      return;
    }


    if (!mounted) {
      return;
    }


    setState(() {
      unlinking = true;
    });


    try {

      await backend
          .unlinkZalo();


      if (!mounted) {
        return;
      }


      await widget
          .onAuthChanged();

    } catch (error) {

      if (!mounted) {
        return;
      }


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Không thể liên kết lại: $error',
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {
          unlinking = false;
        });
      }
    }
  }


  // ========================================
  // UNLINK
  // ========================================

  Future<void>
  unlinkZalo() async {

    final confirmed =
    await showDialog<bool>(
      context:
      context,

      builder:
          (context) {

        return AlertDialog(
          title:
          const Text(
            'Ngắt liên kết Zalo?',
          ),

          content:
          const Text(
            'ZAUTO sẽ ngừng theo dõi các nhóm Zalo cho đến khi bạn liên kết lại.',
          ),

          actions: [

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
              const Text(
                'HỦY',
              ),
            ),


            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
              const Text(
                'NGẮT LIÊN KẾT',
              ),
            ),
          ],
        );
      },
    );


    if (confirmed != true) {
      return;
    }


    setState(() {
      unlinking = true;
    });


    try {

      await backend
          .unlinkZalo();


      await widget
          .onAuthChanged();

    } catch (e) {

      if (!mounted) {
        return;
      }


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Lỗi: $e',
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {
          unlinking = false;
        });
      }
    }
  }


  // ========================================
  // LOGOUT
  // ========================================

  Future<void>
  logout() async {

    final confirmed =
    await showDialog<bool>(
      context:
      context,

      builder:
          (context) {

        return AlertDialog(
          title:
          const Text(
            'Đăng xuất?',
          ),

          content:
          const Text(
            'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',
          ),

          actions: [

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
              const Text(
                'HỦY',
              ),
            ),


            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
              const Text(
                'ĐĂNG XUẤT',
              ),
            ),
          ],
        );

      },
    );


    if (confirmed == true) {
      await widget.onLogout();
    }
  }


  // ========================================
  // ROW
  // ========================================

  Widget infoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child:
      Row(
        children: [

          Icon(
            icon,
            size: 22,
          ),


          const SizedBox(
            width: 14,
          ),


          Expanded(
            child:
            Text(
              title,
              style:
              const TextStyle(
                fontSize: 15,
              ),
            ),
          ),


          Flexible(
            child:
            Text(
              value,
              textAlign:
              TextAlign.right,

              style:
              TextStyle(
                fontSize: 15,
                fontWeight:
                FontWeight.w600,

                color:
                valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    if (
    loading &&
        profile == null
    ) {

      return const Scaffold(
        body:
        Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }


    if (
    error != null &&
        profile == null
    ) {

      return Scaffold(
        appBar:
        AppBar(
          title:
          const Text(
            'Tài khoản',
          ),
        ),

        body:
        Center(
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [

              Text(
                error!,
              ),


              const SizedBox(
                height: 16,
              ),


              FilledButton(
                onPressed:
                loadProfile,

                child:
                const Text(
                  'THỬ LẠI',
                ),
              ),
            ],
          ),
        ),
      );
    }


    final user =
    Map<String, dynamic>.from(
      profile?['user'] ??
          {},
    );


    final worker =
    Map<String, dynamic>.from(
      profile?['worker'] ??
          {},
    );


    final network =
    Map<String, dynamic>.from(
      profile?['network'] ??
          {},
    );


    final name =
        user['name']
            ?.toString() ??
            'Người dùng';


    final phone =
        user['phone']
            ?.toString() ??
            '';


    final membership =
        user['membership']
            ?.toString()
            .toUpperCase() ??
            'FREE';


    final zaloLinked =
        user['zaloLinked'] ==
            true;


    final workerStatus =
        worker['status']
            ?.toString() ??
            'stopped';


    final networkState =
        network['state']
            ?.toString() ??
            'unknown';


    final needRelink =
        workerStatus ==
            'needs_relink' ||
            workerStatus ==
                'error';


    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Tài khoản',
        ),

        actions: [

          IconButton(
            onPressed:
                () =>
                loadProfile(),

            icon:
            const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),


      body:
      RefreshIndicator(
        onRefresh:
        loadProfile,

        child:
        ListView(
          padding:
          const EdgeInsets.all(
            16,
          ),

          children: [

            // =================================
            // USER CARD
            // =================================

            Card(
              child:
              Padding(
                padding:
                const EdgeInsets.all(
                  20,
                ),

                child:
                Column(
                  children: [

                    CircleAvatar(
                      radius: 34,

                      child:
                      Text(
                        name.isNotEmpty
                            ? name[0]
                            .toUpperCase()
                            : '?',

                        style:
                        const TextStyle(
                          fontSize: 28,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),


                    const SizedBox(
                      height: 12,
                    ),


                    Text(
                      name,

                      style:
                      Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),


                    const SizedBox(
                      height: 4,
                    ),


                    Text(
                      phone,
                    ),


                    const SizedBox(
                      height: 8,
                    ),


                    Chip(
                      label:
                      Text(
                        membership,
                      ),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(
              height: 12,
            ),


            // =================================
            // SYSTEM STATUS
            // =================================

            Card(
              child:
              Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),

                child:
                Column(
                  children: [

                    infoRow(
                      icon:
                      Icons.cloud_outlined,

                      title:
                      'Máy chủ',

                      value:
                      networkState ==
                          'online'
                          ? 'Online'
                          : networkState ==
                          'offline'
                          ? 'Mất Internet'
                          : 'Đang kiểm tra',

                      valueColor:
                      networkState ==
                          'online'
                          ? Colors.green
                          : Colors.orange,
                    ),


                    const Divider(
                      height: 1,
                    ),


                    infoRow(
                      icon:
                      Icons.chat_outlined,

                      title:
                      'Zalo',

                      value:
                      zaloLinked
                          ? 'Đã liên kết'
                          : 'Chưa liên kết',

                      valueColor:
                      zaloLinked
                          ? Colors.green
                          : Colors.red,
                    ),


                    const Divider(
                      height: 1,
                    ),


                    infoRow(
                      icon:
                      Icons.sensors,

                      title:
                      'Theo dõi realtime',

                      value:
                      workerLabel(
                        workerStatus,
                      ),

                      valueColor:
                      workerColor(
                        context,
                        workerStatus,
                      ),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            // =================================
            // NEED RELINK
            // =================================

            if (needRelink)
              Card(
                child:
                Padding(
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),

                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,

                    children: [

                      const Row(
                        children: [

                          Icon(
                            Icons.warning_amber_rounded,
                            color:
                            Colors.orange,
                          ),

                          SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child:
                            Text(
                              'Phiên Zalo cần được liên kết lại.',
                              style:
                              TextStyle(
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),


                      const SizedBox(
                        height: 14,
                      ),


                      FilledButton.icon(
                        onPressed:
                        unlinking
                            ? null
                            : relinkZalo,

                        icon:
                        const Icon(
                          Icons.qr_code,
                        ),

                        label:
                        const Text(
                          'LIÊN KẾT LẠI ZALO',
                        ),
                      ),
                    ],
                  ),
                ),
              ),


            if (needRelink)
              const SizedBox(
                height: 16,
              ),


            // =================================
// ACTIONS
// =================================

// ========================================
// DOI TEN
// ========================================

            OutlinedButton.icon(
              onPressed:
              unlinking
                  ? null
                  : editName,

              icon:
              const Icon(
                Icons.edit_outlined,
              ),

              label:
              const Text(
                'ĐỔI TÊN',
              ),
            ),


            const SizedBox(
              height: 10,
            ),

            OutlinedButton.icon(
              onPressed:
              unlinking
                  ? null
                  : changePassword,

              icon:
              const Icon(
                Icons.lock_outline,
              ),

              label:
              const Text(
                'ĐỔI MẬT KHẨU',
              ),
            ),


// ========================================
// NGAT ZALO
// ========================================

            if (
            zaloLinked &&
                !needRelink
            )
              OutlinedButton.icon(
                onPressed:
                unlinking
                    ? null
                    : unlinkZalo,

                icon:
                const Icon(
                  Icons.link_off,
                ),

                label:
                const Text(
                  'NGẮT LIÊN KẾT ZALO',
                ),
              ),


            if (
            zaloLinked &&
                !needRelink
            )
              const SizedBox(
                height: 10,
              ),


// ========================================
// LOGOUT
// ========================================

            OutlinedButton.icon(
              onPressed:
              unlinking
                  ? null
                  : logout,

              icon:
              const Icon(
                Icons.logout,
              ),

              label:
              const Text(
                'ĐĂNG XUẤT',
              ),
            ),


            if (unlinking) ...[
              const SizedBox(
                height: 20,
              ),

              const Center(
                child:
                CircularProgressIndicator(),
              ),
            ],

// ========================================
// DELETE ACCOUNT
// ========================================
            const SizedBox(
              height: 18,
            ),


            const Divider(),


            const SizedBox(
              height: 8,
            ),


            OutlinedButton.icon(
              onPressed:
              unlinking
                  ? null
                  : deleteAccount,

              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                Colors.red,
              ),

              icon:
              const Icon(
                Icons.delete_forever_outlined,
              ),

              label:
              const Text(
                'XÓA TÀI KHOẢN',
              ),
            ),
          ],
        ),
      ),
    );
  }
}