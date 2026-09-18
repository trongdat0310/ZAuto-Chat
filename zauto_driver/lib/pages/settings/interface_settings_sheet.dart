import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';
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
  late String selectedTheme;

  late double notificationFontSize;

  late int currentTripDisplaySeconds;

  late String currentAcceptButtonPosition;

  @override
  void initState() {
    super.initState();

    selectedTheme = widget.initialTheme;

    notificationFontSize = widget.initialFontSize;

    currentTripDisplaySeconds = widget.initialTripDisplaySeconds;

    currentAcceptButtonPosition = widget.initialAcceptButtonPosition;
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

            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
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
                // THEME
                // ========================================

                Padding(
                  padding: const EdgeInsets.all(18),

                  child: Row(
                    children: [
                      const Text('Giao diện', style: TextStyle(fontSize: 16)),

                      const Spacer(),

                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'light',

                            label: Text('Sáng'),
                          ),

                          ButtonSegment<String>(
                            value: 'dark',

                            label: Text('Tối'),
                          ),

                          ButtonSegment<String>(
                            value: 'system',

                            label: Text('Hệ thống'),
                          ),
                        ],

                        selected: {selectedTheme},

                        showSelectedIcon: false,

                        onSelectionChanged: (value) async {
                          if (value.isEmpty) {
                            return;
                          }

                          final selected = value.first;

                          setState(() {
                            selectedTheme = selected;
                          });

                          await widget.onThemeChanged(selected);
                        },
                      ),
                    ],
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

                            style: TextStyle(fontSize: 16),
                          ),

                          const Spacer(),

                          Text(
                            notificationFontSize.round().toString(),

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

                        divisions: 20,

                        value: notificationFontSize,

                        onChanged: (value) {
                          setState(() {
                            notificationFontSize = value;
                          });
                        },

                        onChangeEnd: (value) async {
                          await widget.onFontSizeChanged(value);
                        },
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

              style: TextStyle(
                fontSize: 13,

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
                  title: const Text('Thời gian hiện thông báo'),

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
                const SwitchListTile(
                  value: false,

                  onChanged: null,

                  title: Text('Chạm vào tin nhắn để nhận nhanh'),

                  secondary: Icon(Icons.lock_outline),
                ),

                const Divider(height: 1),

                // ========================================
                // SWIPE REPLY
                // GIU NGUYEN DISABLED
                // ========================================
                const SwitchListTile(
                  value: false,

                  onChanged: null,

                  title: Text('Vuốt để trả lời thông báo'),

                  secondary: Icon(Icons.lock_outline),
                ),

                const Divider(height: 1),

                // ========================================
                // ACCEPT BUTTON POSITION
                // ========================================
                ListTile(
                  title: const Text('Vị trí nút nhận'),

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

                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
