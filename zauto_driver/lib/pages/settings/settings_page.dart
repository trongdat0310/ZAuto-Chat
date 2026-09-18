import 'package:flutter/material.dart';

import '../../services/theme_service.dart';
import '../../services/backend_service.dart';

import '../../config/app_config.dart';

import '../../controllers/settings_controller.dart';

import 'sound_settings_sheet.dart';
import 'message_filter_sheet.dart';
import 'interface_settings_sheet.dart';
import 'accept_reply_editor_sheet.dart';
import 'settings_tile.dart';

class SettingsPage extends StatefulWidget {
  final SettingsController settingsController;

  const SettingsPage({super.key, required this.settingsController});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  // ========================================
  // GIAO DIEN
  // ========================================

  String selectedTheme = ThemeService.currentKey;

  late int currentTripDisplaySeconds;
  late double notificationFontSize;

  late String currentAcceptButtonPosition;
  late String currentAcceptReplyText;

  bool showImages = true;

  bool deduplicateMessages = true;

  bool showVoiceMessages = true;

  bool transcribeVoiceMessages = false;

  // ========================================
  // GIAO DIEN VA TUONG TAC
  // ========================================

  void openInterfaceSettings() {
    showModalBottomSheet<void>(
      context: context,

      isScrollControlled: true,

      useSafeArea: true,

      showDragHandle: true,

      builder: (_) {
        return InterfaceSettingsSheet(
          settingsController: widget.settingsController,

          backend: backend,

          initialTheme: selectedTheme,

          initialFontSize: notificationFontSize,

          initialTripDisplaySeconds: currentTripDisplaySeconds,

          initialAcceptButtonPosition: currentAcceptButtonPosition,

          onTripDisplaySecondsChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              currentTripDisplaySeconds = value;
            });
          },

          onAcceptButtonPositionChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              currentAcceptButtonPosition = value;
            });
          },

          // ========================================
          // THEME
          // ========================================
          onThemeChanged: (value) async {
            if (!mounted) {
              return;
            }

            setState(() {
              selectedTheme = value;
            });

            await widget.settingsController.updateTheme(value);
          },

          // ========================================
          // FONT SIZE
          // ========================================
          onFontSizeChanged: (value) async {
            if (!mounted) {
              return;
            }

            setState(() {
              notificationFontSize = value;
            });

            await widget.settingsController.updateFontSize(value);
          },
        );
      },
    );
  }

  Future<void> loadMessageSettings() async {
    try {
      final settings = await backend.getMessageSettings();

      if (!mounted) {
        return;
      }

      final rawWindow = settings['dedupeWindowSeconds'];

      final savedSeconds = rawWindow is num ? rawWindow.toInt() : null;

      setState(() {
        deduplicateMessages = settings['deduplicateMessages'] != false;

        if (savedSeconds == 5 || savedSeconds == 10 || savedSeconds == 15) {
          currentTripDisplaySeconds = savedSeconds!;
        }
      });

      if (savedSeconds == 5 || savedSeconds == 10 || savedSeconds == 15) {
        await widget.settingsController.updateTripDisplaySeconds(savedSeconds!);
      }
    } catch (error) {
      debugPrint('LOAD MESSAGE SETTINGS ERROR: $error');
    }
  }

  Future<void> openAcceptReplyTextEditor() async {
    final result = await showModalBottomSheet<String>(
      context: context,

      isScrollControlled: true,

      useSafeArea: true,

      showDragHandle: true,

      builder: (sheetContext) {
        return AcceptReplyEditorSheet(initialText: currentAcceptReplyText);
      },
    );

    if (result == null || result.trim().isEmpty || !mounted) {
      return;
    }

    final value = result.trim();

    // ========================================
    // UPDATE UI
    // ========================================

    setState(() {
      currentAcceptReplyText = value;
    });

    // ========================================
    // SAVE SETTINGS
    // ========================================

    try {
      await widget.settingsController.updateAcceptReplyText(value);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu nội dung trả lời: $error')),
      );
    }
  }

  // ========================================
  // BO LOC TIN NHAN
  // ========================================

  void openMessageFilters() {
    showModalBottomSheet<void>(
      context: context,

      isScrollControlled: true,

      useSafeArea: true,

      showDragHandle: true,

      builder: (_) {
        return MessageFilterSheet(
          backend: backend,

          initialShowImages: showImages,

          initialDeduplicateMessages: deduplicateMessages,

          initialShowVoiceMessages: showVoiceMessages,

          initialTranscribeVoiceMessages: transcribeVoiceMessages,

          // ========================================
          // IMAGE
          // ========================================
          onShowImagesChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              showImages = value;
            });
          },

          // ========================================
          // DEDUPE
          // ========================================
          onDeduplicateMessagesChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              deduplicateMessages = value;
            });
          },

          // ========================================
          // VOICE
          // ========================================
          onShowVoiceMessagesChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              showVoiceMessages = value;
            });
          },

          // ========================================
          // TRANSCRIBE
          // ========================================
          onTranscribeVoiceMessagesChanged: (value) {
            if (!mounted) {
              return;
            }

            setState(() {
              transcribeVoiceMessages = value;
            });
          },
        );
      },
    );
  }

  void _settingsChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ========================================
  // SOUND
  // ANH SO 5 CHUA DUOC GUI
  // ========================================

  void openSoundSettings() {
    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      useSafeArea: true,

      builder: (context) {
        return SoundSettingsSheet(
          settingsController: widget.settingsController,
        );
      },
    );
  }

  // ========================================
  // MAIN
  // ========================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),

        children: [
          const Center(
            child: Text(
              'Cài đặt',

              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 28),

          // ========================================
          // MAIN SETTINGS
          // ========================================
          Card(
            clipBehavior: Clip.antiAlias,

            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.palette_outlined,

                  title: 'Giao diện và Tương tác',

                  subtitle: 'Chủ đề, cỡ chữ, thẻ cuốc...',

                  onTap: openInterfaceSettings,
                ),

                const Divider(height: 1),

                SettingsTile(
                  icon: Icons.filter_alt_outlined,

                  title: 'Bộ lọc tin nhắn',

                  subtitle: 'Hình ảnh, tin thoại, lọc trùng...',

                  onTap: openMessageFilters,
                ),

                const Divider(height: 1),

                SettingsTile(
                  icon: Icons.volume_up_outlined,

                  title: 'Âm thanh và Đọc thông báo',

                  subtitle: 'Chuông báo cuốc mới, đọc nội dung cuốc',

                  onTap: openSoundSettings,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'TRẢ LỜI',

            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),

          const SizedBox(height: 10),

          // ========================================
          // REPLY - CHUA LAM
          // ========================================
          Card(
            clipBehavior: Clip.antiAlias,

            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.edit_outlined,

                  title: 'Nội dung trả lời',

                  subtitle: '"$currentAcceptReplyText"',

                  onTap: openAcceptReplyTextEditor,
                ),

                const Divider(height: 1),

                SettingsTile(
                  icon: Icons.list_alt_outlined,

                  title: 'Mẫu trả lời',

                  subtitle: '4 mẫu hệ thống',

                  enabled: false,

                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(Icons.lock_outline),

                      SizedBox(width: 8),

                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    widget.settingsController.addListener(_settingsChanged);

    final settings = widget.settingsController.settings;

    selectedTheme = settings.themeMode.name;

    currentTripDisplaySeconds = settings.tripDisplaySeconds;

    notificationFontSize = settings.chatFontSize;

    currentAcceptButtonPosition = settings.acceptButtonPosition;

    currentAcceptReplyText = settings.acceptReplyText;

    loadMessageSettings();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsChanged);

    super.dispose();
  }
}
