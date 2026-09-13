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

  List<Map<String, dynamic>>
  notificationGroups = [];

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

      final groups =
      await backend
          .getGroups();


      if (!mounted) {
        return;
      }


      setState(() {
        profile = result;
        notificationGroups = groups;
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

  Widget _sectionTitle(
      String title,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        12,
        22,
        12,
        10,
      ),
      child:
      Text(
        title,
        style:
        TextStyle(
          fontSize: 14,
          fontWeight:
          FontWeight.w500,
          letterSpacing:
          0.8,
          color:
          colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final foreground =
    danger
        ? colorScheme.error
        : colorScheme.onSurface;

    final iconBackground =
    danger
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    return InkWell(
      onTap:
      onTap,

      child:
      Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),

        child:
        Row(
          children: [

            Container(
              width: 46,
              height: 46,

              decoration:
              BoxDecoration(
                color:
                iconBackground,
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
              ),

              alignment:
              Alignment.center,

              child:
              Icon(
                icon,
                size: 24,
                color:
                foreground,
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                mainAxisSize:
                MainAxisSize.min,

                children: [

                  Text(
                    title,
                    style:
                    TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w500,
                      color:
                      foreground,
                    ),
                  ),

                  if (
                  subtitle != null &&
                      subtitle.isNotEmpty
                  ) ...[

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      style:
                      TextStyle(
                        fontSize: 13,
                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard({
    required List<Widget> children,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      decoration:
      BoxDecoration(
        color:
        colorScheme.surfaceContainer,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border:
        Border.all(
          color:
          colorScheme.outline
              .withValues(
            alpha: 0.45,
          ),
        ),
      ),

      clipBehavior:
      Clip.antiAlias,

      child:
      Column(
        children:
        children,
      ),
    );
  }

  void _showTopMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger
        .of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
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

      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }


    if (
    error != null &&
        profile == null
    ) {

      return Center(

        child:
        Padding(
          padding:
          const EdgeInsets.all(
            24,
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [

              Text(
                error!,
                textAlign:
                TextAlign.center,
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

    final zaloProfile =
    Map<String, dynamic>.from(
      profile?['zaloProfile'] ??
          {},
    );


    final zaloAvatar =
        zaloProfile['avatar']
            ?.toString()
            .trim() ??
            '';


    final zaloPhone =
    (
        zaloProfile['phone'] ??
            zaloProfile['phoneNumber'] ??
            ''
    )
        .toString()
        .trim();

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


    final needRelink =
        workerStatus ==
            'needs_relink' ||
            workerStatus ==
                'error';


    // ========================================
    // SO NHOM
    //
    // Neu backend chua tra groups,
    // khong tu bịa so.
    // ========================================

    final totalGroups =
        notificationGroups.length;


    final enabledGroups =
        notificationGroups
            .where(
              (group) =>
          group['enabled'] ==
              true,
        )
            .length;


    final groupText =
    totalGroups > 0
        ? '$enabledGroups/$totalGroups nhóm nhận thông báo'
        : '0/0 nhóm nhận thông báo';


    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return RefreshIndicator(

      onRefresh:
      loadProfile,


      child:
      ListView(

        padding:
        const EdgeInsets.fromLTRB(
          16,
          34,
          16,
          30,
        ),


        children: [

          // ========================================
          // HEADER
          // ========================================

          Padding(

            padding:
            const EdgeInsets.symmetric(
              horizontal: 8,
            ),

            child:
            Row(

              crossAxisAlignment:
              CrossAxisAlignment.center,

              children: [

                CircleAvatar(

                  radius:
                  46,

                  backgroundColor:
                  colorScheme
                      .primaryContainer,

                  child:
                  Icon(
                    Icons
                        .person_rounded,

                    size:
                    52,

                    color:
                    colorScheme
                        .primary,
                  ),
                ),


                const SizedBox(
                  width:
                  18,
                ),


                Expanded(

                  child:
                  Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Text(

                        name,

                        maxLines:
                        1,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(

                          fontSize:
                          25,

                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),


                      const SizedBox(
                        height:
                        4,
                      ),


                      Text(

                        phone,

                        style:
                        TextStyle(

                          fontSize:
                          17,

                          color:
                          colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),


                IconButton(

                  tooltip:
                  'Làm mới',

                  onPressed:
                  loadProfile,

                  icon:
                  const Icon(
                    Icons
                        .notifications_none_rounded,

                    size:
                    30,
                  ),
                ),
              ],
            ),
          ),


          // ========================================
          // DA LIEN KET
          // ========================================

          _sectionTitle(
            'ĐÃ LIÊN KẾT',
          ),


          _accountCard(

            children: [

              // ==================================
              // USER
              // ==================================

              Padding(

                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  16,
                ),

                child:
                Row(

                  children: [

                    CircleAvatar(

                      radius:
                      31,

                      backgroundColor:
                      colorScheme
                          .surfaceContainerHighest,

                      backgroundImage:
                      zaloAvatar.isNotEmpty
                          ? NetworkImage(
                        zaloAvatar,
                      )
                          : null,

                      child:
                      zaloAvatar.isEmpty
                          ? Icon(
                        Icons.person_rounded,

                        size:
                        34,

                        color:
                        colorScheme
                            .onSurfaceVariant,
                      )
                          : null,
                    ),

                    const SizedBox(
                      width:
                      14,
                    ),


                    Expanded(

                      child:
                      Column(

                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        mainAxisSize:
                        MainAxisSize.min,

                        children: [

                          Text(

                            zaloProfile['name']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                                true
                                ? zaloProfile['name']
                                .toString()
                                .trim()
                                : name,

                            maxLines:
                            1,

                            overflow:
                            TextOverflow
                                .ellipsis,

                            style:
                            const TextStyle(

                              fontSize:
                              18,

                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),


                          if (
                          zaloPhone.isNotEmpty
                          ) ...[

                            const SizedBox(
                              height:
                              4,
                            ),

                            Text(

                              zaloPhone,

                              style:
                              TextStyle(

                                fontSize:
                                14,

                                color:
                                colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              Divider(
                height:
                1,

                color:
                colorScheme
                    .outline
                    .withValues(
                  alpha:
                  0.35,
                ),
              ),


              // ==================================
              // CONNECTION
              // ==================================

              Padding(

                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  8,
                ),

                child:
                Row(

                  children: [

                    Icon(
                      Icons
                          .link_rounded,

                      size:
                      30,

                      color:
                      zaloLinked
                          ? Colors.green
                          : colorScheme
                          .error,
                    ),


                    const SizedBox(
                      width:
                      14,
                    ),


                    Text(

                      zaloLinked
                          ? 'Đang kết nối'
                          : 'Chưa liên kết',

                      style:
                      TextStyle(

                        fontSize:
                        17,

                        fontWeight:
                        FontWeight.w500,

                        color:
                        zaloLinked
                            ? Colors.green
                            : colorScheme
                            .error,
                      ),
                    ),
                  ],
                ),
              ),


              // ==================================
              // GROUP NOTIFICATION
              // ==================================

              Padding(

                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  14,
                ),

                child:
                Row(

                  children: [

                    Icon(

                      Icons
                          .notifications_none_rounded,

                      size:
                      30,

                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),


                    const SizedBox(
                      width:
                      14,
                    ),


                    Text(

                      groupText,

                      style:
                      const TextStyle(

                        fontSize:
                        17,

                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),


              // ==================================
              // UNLINK
              // ==================================

              Padding(

                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  16,
                ),

                child:
                SizedBox(

                  width:
                  double.infinity,

                  height:
                  48,

                  child:
                  OutlinedButton.icon(

                    onPressed:
                    unlinking
                        ? null
                        : unlinkZalo,

                    icon:
                    Icon(
                      Icons
                          .link_off_rounded,

                      color:
                      colorScheme.error,
                    ),

                    label:
                    Text(
                      'Gỡ liên kết',

                      style:
                      TextStyle(
                        color:
                        colorScheme.error,

                        fontSize:
                        16,
                      ),
                    ),

                    style:
                    OutlinedButton.styleFrom(

                      side:
                      BorderSide(
                        color:
                        colorScheme
                            .outline
                            .withValues(
                          alpha:
                          0.5,
                        ),
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),


          // ========================================
          // THONG TIN CA NHAN
          // ========================================

          _sectionTitle(
            'THÔNG TIN CÁ NHÂN',
          ),


          _accountCard(

            children: [

              _accountTile(

                icon:
                Icons.lock_outline_rounded,

                title:
                'Đổi mật khẩu',

                onTap:
                unlinking
                    ? null
                    : changePassword,
              ),


              Divider(
                height:
                1,

                indent:
                78,

                color:
                colorScheme
                    .outline
                    .withValues(
                  alpha:
                  0.35,
                ),
              ),


              _accountTile(

                icon:
                Icons.person_outline_rounded,

                title:
                'Thông tin thành viên',

                subtitle:
                membership == 'FREE'
                    ? 'Miễn phí'
                    : membership,

                onTap:
                editName,
              ),
            ],
          ),


          // ========================================
          // HO TRO
          // ========================================

          _sectionTitle(
            'HỖ TRỢ',
          ),


          _accountCard(

            children: [

              _accountTile(

                icon:
                Icons.language_rounded,

                title:
                'Trang chủ',

                onTap:
                    () {
                  _showTopMessage(
                    'Trang chủ',
                  );
                },
              ),


              Divider(
                height:
                1,

                indent:
                78,

                color:
                colorScheme
                    .outline
                    .withValues(
                  alpha:
                  0.35,
                ),
              ),


              _accountTile(

                icon:
                Icons.description_outlined,

                title:
                'Hướng dẫn sử dụng',

                onTap:
                    () {
                  _showTopMessage(
                    'Hướng dẫn sử dụng',
                  );
                },
              ),


              Divider(
                height:
                1,

                indent:
                78,

                color:
                colorScheme
                    .outline
                    .withValues(
                  alpha:
                  0.35,
                ),
              ),


              _accountTile(

                icon:
                Icons.support_agent_rounded,

                title:
                'Hỗ trợ khách hàng',

                onTap:
                    () {
                  _showTopMessage(
                    'Hỗ trợ khách hàng',
                  );
                },
              ),
            ],
          ),


          // ========================================
          // NEED RELINK
          // ========================================

          if (needRelink) ...[

            const SizedBox(
              height:
              16,
            ),

            Container(

              padding:
              const EdgeInsets.all(
                16,
              ),

              decoration:
              BoxDecoration(

                color:
                colorScheme
                    .errorContainer,

                borderRadius:
                BorderRadius.circular(
                  18,
                ),
              ),

              child:
              Row(

                children: [

                  Icon(
                    Icons
                        .warning_amber_rounded,

                    color:
                    colorScheme
                        .onErrorContainer,
                  ),

                  const SizedBox(
                    width:
                    12,
                  ),

                  Expanded(

                    child:
                    Text(

                      'Phiên Zalo cần được liên kết lại.',

                      style:
                      TextStyle(

                        color:
                        colorScheme
                            .onErrorContainer,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  IconButton(

                    onPressed:
                    relinkZalo,

                    icon:
                    const Icon(
                      Icons
                          .qr_code_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],


          // ========================================
          // THAO TAC NGUY HIEM
          // ========================================

          _sectionTitle(
            'THAO TÁC NGUY HIỂM',
          ),


          _accountCard(

            children: [

              _accountTile(

                icon:
                Icons.logout_rounded,

                title:
                'Đăng xuất',

                danger:
                true,

                onTap:
                unlinking
                    ? null
                    : logout,
              ),


              Divider(
                height:
                1,

                indent:
                78,

                color:
                colorScheme
                    .outline
                    .withValues(
                  alpha:
                  0.35,
                ),
              ),


              _accountTile(

                icon:
                Icons.delete_outline_rounded,

                title:
                'Xóa tài khoản',

                subtitle:
                'Xóa vĩnh viễn tài khoản khỏi hệ thống',

                danger:
                true,

                onTap:
                unlinking
                    ? null
                    : deleteAccount,
              ),
            ],
          ),


          const SizedBox(
            height:
            24,
          ),
        ],
      ),
    );
  }
}