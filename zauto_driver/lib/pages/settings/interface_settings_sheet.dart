import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';
import '../../theme/app_typography.dart';
import '../../services/backend_service.dart';

class InterfaceSettingsSheet extends StatefulWidget {
  final SettingsController settingsController;

  final BackendService backend;

  final String initialTheme;

  final double initialFontSize;

  final int initialTripDisplaySeconds;

  final String initialAcceptButtonPosition;

  final Future<void> Function(String value) onThemeChanged;

  final Future<void> Function(double value) onFontSizeChanged;

  final ValueChanged<int> onTripDisplaySecondsChanged;

  final ValueChanged<String> onAcceptButtonPositionChanged;

  const InterfaceSettingsSheet({
    super.key,

    required this.settingsController,

    required this.backend,

    required this.initialTheme,

    required this.initialFontSize,

    required this.initialTripDisplaySeconds,

    required this.initialAcceptButtonPosition,

    required this.onThemeChanged,

    required this.onFontSizeChanged,

    required this.onTripDisplaySecondsChanged,

    required this.onAcceptButtonPositionChanged,
  });

  @override
  State<InterfaceSettingsSheet> createState() => _InterfaceSettingsSheetState();
}

class _InterfaceSettingsSheetState extends State<InterfaceSettingsSheet> {
  late bool quickTapAccept;
  late bool swipeToReply;

  late String selectedTheme;

  late double notificationFontSize;

  late int currentTripDisplaySeconds;

  late String currentAcceptButtonPosition;

  @override
  void initState() {
    super.initState();

    quickTapAccept = widget.settingsController.settings.quickTapAccept;
    swipeToReply = widget.settingsController.settings.swipeToReply;
    selectedTheme = widget.initialTheme;

    notificationFontSize = widget.initialFontSize;

    currentTripDisplaySeconds = widget.initialTripDisplaySeconds;

    currentAcceptButtonPosition = widget.initialAcceptButtonPosition;
  }

  Widget _themeOption({
    required String value,
    required String label,
    required ColorScheme colors,
  }) {
    final isSelected = selectedTheme == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Chế độ $label',
        child: Material(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            key: ValueKey('theme-option-$value'),
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              if (selectedTheme == value) {
                return;
              }
              setState(() {
                selectedTheme = value;
              });
              await widget.onThemeChanged(value);
            },
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _themePicker(ColorScheme colors) {
    return Container(
      key: const ValueKey('theme-picker'),
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _themeOption(value: 'light', label: 'Sáng', colors: colors),
          _themeOption(value: 'dark', label: 'Tối', colors: colors),
          _themeOption(value: 'system', label: 'Hệ thống', colors: colors),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        6,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Giao diện và Tương tác',

            style: AppTypography.sheetTitle,
          ),

          const SizedBox(height: 22),

          // ========================================
          // GIAO DIEN + FONT
          // ========================================
          Card(
            clipBehavior: Clip.antiAlias,

            child: Column(
              children: [
                // ========================================
                // THEME: label and compact three-way control on one row.
                // ========================================
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Respect accessibility text sizes on narrow devices.
                      if (constraints.maxWidth < 260 ||
                          MediaQuery.textScalerOf(context).scale(17) > 24) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Giao diện',
                              style: AppTypography.settingsItemTitle,
                            ),
                            const SizedBox(height: 12),
                            _themePicker(colorScheme),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Giao diện',
                            style: AppTypography.settingsItemTitle,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _themePicker(colorScheme)),
                        ],
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // ========================================
                // FONT SIZE
                // ========================================
                Padding(
                  padding: const EdgeInsets.all(18),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          const Text(
                            'Cỡ chữ thông báo',

                            style: AppTypography.settingsItemTitle,
                          ),

                          const Spacer(),

                          Text(
                            notificationFontSize % 1 == 0
                                ? notificationFontSize.toInt().toString()
                                : notificationFontSize.toStringAsFixed(1),

                            style: TextStyle(
                              fontSize: 16,

                              fontWeight: FontWeight.bold,

                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),

                      Slider(
                        min: 10,

                        max: 30,

                        divisions: 40,

                        value: notificationFontSize,

                        label:
                            notificationFontSize.toStringAsFixed(1),

                        onChanged: (value) {
                          setState(() {
                            notificationFontSize = value;
                          });

                          widget.settingsController
                              .previewFontSize(
                            value,
                          );
                        },

                        onChangeEnd: (value) async {
                          await widget.onFontSizeChanged(value);
                        },
                      ),

                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(
                          color:
                              colorScheme.surfaceContainerHighest,

                          borderRadius:
                              BorderRadius.circular(12),
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Xem trước thông báo',

                              style: AppTypography.settingsItemDescription.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Có cuốc Thái Bình đi Nội Bài giá 650k',

                              style: TextStyle(
                                fontSize:
                                    notificationFontSize,

                                fontWeight:
                                    FontWeight.w600,

                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Center(
            child: Text(
              'TƯƠNG TÁC VỚI THẺ CUỐC',

              style: AppTypography.sectionTitle.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            clipBehavior: Clip.antiAlias,

            child: Column(
              children: [
                // ========================================
                // TRIP DISPLAY TIME
                // ========================================

                ListTile(
                  title: const Text(
                    'Thời gian hiện thông báo',
                    style: AppTypography.settingsItemTitle,
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Text(
                        '${currentTripDisplaySeconds}s',

                        style: TextStyle(
                          color: colorScheme.primary,

                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(width: 6),

                      const Icon(Icons.chevron_right),
                    ],
                  ),

                  onTap: openTripDurationPicker,
                ),

                const Divider(height: 1),

                // ========================================
                // QUICK ACCEPT
                // GIU NGUYEN DISABLED
                // ========================================
                SwitchListTile(
 value: quickTapAccept,
 onChanged: (value) async { setState(() => quickTapAccept = value); await widget.settingsController.updateQuickTapAccept(value); },
 title: const Text(
   'Chạm vào tin nhắn để nhận nhanh',
   style: AppTypography.settingsItemTitle,
 ),
 subtitle: Text(
   'Chạm vào thẻ cuốc để nhận',
   style: AppTypography.settingsItemDescription.copyWith(
     color: colorScheme.onSurfaceVariant,
   ),
 ),
),

                const Divider(height: 1),

                // ========================================
                // SWIPE REPLY
                // GIU NGUYEN DISABLED
                // ========================================
                SwitchListTile(
 value: swipeToReply,
 onChanged: (value) async { setState(() => swipeToReply = value); await widget.settingsController.updateSwipeToReply(value); },
 title: const Text(
   'Vuốt để trả lời thông báo',
   style: AppTypography.settingsItemTitle,
 ),
 subtitle: Text(
   'Vuốt trái thẻ cuốc ở Home để nhập trả lời',
   style: AppTypography.settingsItemDescription.copyWith(
     color: colorScheme.onSurfaceVariant,
   ),
 ),
),

                const Divider(height: 1),

                // ========================================
                // ACCEPT BUTTON POSITION
                // ========================================
                ListTile(
                  title: const Text(
                    'Vị trí nút nhận',
                    style: AppTypography.settingsItemTitle,
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Text(
                        currentAcceptButtonPosition == 'left'
                            ? 'Bên trái'
                            : 'Bên phải',

                        style: TextStyle(
                          color: colorScheme.primary,

                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(width: 6),

                      const Icon(Icons.chevron_right),
                    ],
                  ),

                  onTap: openAcceptButtonPositionPicker,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // PICK 5 / 10 / 15 GIAY
  // ========================================

  Future<void> openTripDurationPicker() async {
    await showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (pickerContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Padding(
                  padding: EdgeInsets.all(12),

                  child: Text(
                    'Thời gian hiện thông báo',

                    style: AppTypography.sheetTitle,
                  ),
                ),
                RadioGroup<int>(
                  groupValue: currentTripDisplaySeconds,

                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }

                    final oldValue = currentTripDisplaySeconds;

                    // ========================================
                    // 1. UPDATE UI NGAY
                    // ========================================

                    setState(() {
                      currentTripDisplaySeconds = value;
                    });

                    widget.onTripDisplaySecondsChanged(
                      currentTripDisplaySeconds,
                    );

                    // ========================================
                    // 2. UPDATE HOME PAGE
                    // ========================================

                    await widget.settingsController.updateTripDisplaySeconds(
                      value,
                    );

                    try {
                      // ========================================
                      // LUU THOI GIAN LEN BACKEND
                      // ========================================

                      await widget.backend.updateMessageSettings(
                        dedupeWindowSeconds: value,
                      );

                      // ========================================
                      // KIEM TRA STATE SETTINGS PAGE
                      // ========================================

                      if (!mounted) {
                        return;
                      }

                      // ========================================
                      // KIEM TRA CONTEXT CUA PICKER
                      // SAU ASYNC GAP
                      // ========================================

                      if (!pickerContext.mounted) {
                        return;
                      }

                      // ========================================
                      // DONG PICKER 5 / 10 / 15 GIAY
                      // ========================================

                      Navigator.of(pickerContext).pop();
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }

                      // ========================================
                      // ROLLBACK NEU BACKEND LOI
                      // ========================================

                      setState(() {
                        currentTripDisplaySeconds = oldValue;
                      });

                      widget.onTripDisplaySecondsChanged(oldValue);

                      await widget.settingsController.updateTripDisplaySeconds(
                        oldValue,
                      );

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Không thể lưu thời gian thông báo: $error',
                          ),
                        ),
                      );
                    }
                  },

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      for (final seconds in [5, 10, 15])
                        RadioListTile<int>(
                          value: seconds,

                          title: Text('$seconds giây'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openAcceptButtonPositionPicker() async {
    await showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (pickerContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Padding(
                  padding: EdgeInsets.all(12),

                  child: Text(
                    'Vị trí nút nhận',

                    style: AppTypography.sheetTitle,
                  ),
                ),

                RadioGroup<String>(
                  groupValue: currentAcceptButtonPosition,

                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      currentAcceptButtonPosition = value;
                    });

                    widget.onAcceptButtonPositionChanged(
                      currentAcceptButtonPosition,
                    );

                    await widget.settingsController.updateAcceptButtonPosition(
                      value,
                    );

                    if (!pickerContext.mounted) {
                      return;
                    }

                    Navigator.of(pickerContext).pop();
                  },

                  child: const Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      RadioListTile<String>(
                        value: 'left',

                        title: Text('Bên trái'),

                        secondary: Icon(Icons.arrow_back),
                      ),

                      RadioListTile<String>(
                        value: 'right',

                        title: Text('Bên phải'),

                        secondary: Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
