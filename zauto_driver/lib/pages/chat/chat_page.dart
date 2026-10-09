import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';

import '../../services/backend_service.dart';
import '../../services/settings_service.dart';
import '../../services/chat_state_service.dart';
import '../../services/app_realtime_service.dart';
import '../../services/media_download_service.dart';

import 'chat_date_separator.dart';
import 'chat_sender_avatar.dart';
import 'chat_message_composer.dart';
import 'chat_app_bar.dart';
import 'chat_message_list.dart';
import 'chat_background.dart';
import 'chat_message_actions_sheet.dart';

import 'chat_realtime_controller.dart';
import 'chat_voice_controller.dart';
import 'chat_mark_read_controller.dart';
import 'chat_target_controller.dart';
import 'chat_messages_controller.dart';
import 'chat_actions_controller.dart';
import 'chat_media_controller.dart';
import 'chat_reply_controller.dart';

import 'voice_message_bubble.dart';
import 'file_message_bubble.dart';
import 'sticker_message_bubble.dart';
import 'video_message_bubble.dart';
import 'photo_message_bubble.dart';
import 'text_message_bubble.dart';

import 'simple_media_row.dart';
import 'video_viewer_page.dart';
import 'photo_viewer_page.dart';
import 'photo_media_row.dart';
import 'text_message_row.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;

  // Dung cho Lich su nhan sau nay.
  final String? targetMsgId;
  final String? targetCliMsgId;

  final AppRealtimeService realtimeService;

  const ChatPage({
    super.key,

    required this.realtimeService,

    required this.groupId,
    required this.groupName,
    required this.groupAvatar,

    this.targetMsgId,
    this.targetCliMsgId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ========================================
  // VOICE CONTROLLER
  // ========================================

  late final ChatRealtimeController realtimeController;

  late final ChatVoiceController voiceController;

  late final ChatMarkReadController markReadController;

  late final ChatTargetController targetController;

  late final ChatMessagesController messagesController;

  late final ChatActionsController actionsController;

  late final ChatMediaController mediaController;

  ChatPhotoAlbumIndex? photoAlbumIndex;

  late final ChatReplyController replyController;

  final ScrollController scrollController = ScrollController();

  final TextEditingController messageController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  final FocusNode messageFocusNode = FocusNode();

  bool canSendMessage = false;


  Timer? topNoticeTimer;

  bool showNewMessageButton = false;

  // Dung khi dang o context/history co hasMoreNewer.
  // Bam nut xuong se catch-up latest truoc,
  // sau do moi scroll xuong.
  bool scrollToLatestAfterReload = false;

  bool hasDeferredNewMessages = false;

  bool realtimeConnected = false;

  bool realtimeAuthFailed = false;

  String? initialLoadError;

  void _removeMessageFromUi(Map<String, dynamic> message) {
    if (!mounted) {
      return;
    }

    final removeIndex = messagesController.indexOfSame(
      messagesController.messages,
      message,
    );

    if (removeIndex < 0) {
      return;
    }

    setState(() {
      // ========================================
      // XOA HAN MESSAGE KHOI DANH SACH
      // ========================================

      messagesController.removeAt(removeIndex);

      targetController.adjustAfterMessageRemoval(removeIndex);

      // ========================================
      // NEU DANG REPLY MESSAGE VUA XOA
      // THI HUY REPLY
      // ========================================

      final replyingMessage = replyController.replyingToMessage;

      if (replyingMessage != null &&
          messagesController.isSameMessage(replyingMessage, message)) {
        replyController.clearReply();
      }
    });
  }

  bool _isRecallExpired(Map<String, dynamic> message) {
    final timestampMs = messageTimestampMs(message);

    // Khong ro timestamp thi
    // de backend quyet dinh.
    if (timestampMs == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final ageMs = now - timestampMs;

    if (ageMs < 0) {
      return false;
    }

    return ageMs >= const Duration(hours: 1).inMilliseconds;
  }

  final GlobalKey targetMessageKey = GlobalKey();

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);
  bool _quickTapAcceptEnabled = false;
  bool _quickAcceptBusy = false;

  Future<void> _loadQuickTapAccept() async {
    final settings = await SettingsService().load();
    if (mounted) setState(() => _quickTapAcceptEnabled = settings.quickTapAccept);
  }

  Future<void> _acceptChatMessage(Map<String, dynamic> message) async {
    if (!_quickTapAcceptEnabled || _quickAcceptBusy || message['isSelf'] == true) return;
    final msgId = (message['msgId'] ?? '').toString().trim();
    final cliMsgId = (message['cliMsgId'] ?? '').toString().trim();
    if (msgId.isEmpty && cliMsgId.isEmpty) return;

    _quickAcceptBusy = true;
    try {
      final pending = await backend.getMessages(
        limit: 500,
        groupId: widget.groupId,
        status: 'new',
      );
      Map<String, dynamic>? matched;
      for (final trip in pending) {
        final sourceMsgId = (trip['sourceMsgId'] ?? trip['zaloMessageId'] ?? '').toString();
        final sourceCliMsgId = (trip['sourceCliMsgId'] ?? trip['clientMessageId'] ?? '').toString();
        if ((msgId.isNotEmpty && msgId == sourceMsgId) ||
            (cliMsgId.isNotEmpty && cliMsgId == sourceCliMsgId)) {
          matched = trip;
          break;
        }
      }
      if (matched == null) return;
      final id = matched['id']?.toString();
      if (id == null || id.isEmpty) return;
      final settings = await SettingsService().load();
      await backend.acceptMessage(id, replyText: settings.acceptReplyText);
      if (mounted) _showTopNotice('Đã nhận cuốc');
    } catch (error) {
      if (mounted) _showTopNotice('Không thể nhận cuốc: $error');
    } finally {
      _quickAcceptBusy = false;
    }
  }



  @override
  void initState() {
    super.initState();

    _loadQuickTapAccept();
    ChatStateService.instance.openGroup(widget.groupId);

    messagesController = ChatMessagesController(
      backend: backend,
      groupId: widget.groupId,
    );

    actionsController = ChatActionsController(
      backend: backend,
      groupId: widget.groupId,
    );

    realtimeConnected = widget.realtimeService.isConnected;

    realtimeAuthFailed = widget.realtimeService.hasAuthFailed;

    mediaController = ChatMediaController();

    replyController = ChatReplyController();

    targetController = ChatTargetController(
      targetMsgId: widget.targetMsgId,

      targetCliMsgId: widget.targetCliMsgId,
    );

    markReadController = ChatMarkReadController(
      backend: backend,

      groupId: widget.groupId,
    );

    markReadController.start();

    realtimeController = ChatRealtimeController(
      realtimeService: widget.realtimeService,

      groupId: widget.groupId,

      onReloadRequested: (force) {
        _requestLatestReload(force: force);
      },

      onMarkReadRequested: () {
        markReadController.schedule();
      },

      onMessage: (incoming) {
        upsertRealtimeMessage(incoming);
      },

      onConnected: () {
        if (!mounted) {
          return;
        }

        setState(() {
          realtimeConnected = true;

          realtimeAuthFailed = false;
        });
      },

      onDisconnected: () {
        if (!mounted) {
          return;
        }

        setState(() {
          realtimeConnected = false;
        });
      },

      onAuthError: () {
        if (!mounted) {
          return;
        }

        setState(() {
          realtimeConnected = false;

          realtimeAuthFailed = true;
        });
      },
    );

    voiceController = ChatVoiceController();

    messageController.addListener(_handleComposerChanged);

    initializeChat();
  }

  void _handleComposerChanged() {
    final next = messageController.text.trim().isNotEmpty;

    if (next == canSendMessage) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      canSendMessage = next;
    });
  }

  void _startReply(Map<String, dynamic> message) {
    final error = replyController.startReply(message);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));

      return;
    }

    // Pre-fill @sender when replying to someone else's message.
    // Keep the composer untouched when replying to our own message.
    if (message['isSelf'] != true) {
      final senderName = (message['senderName'] ?? '').toString().trim().replaceFirst(RegExp(r'^@+'), '');
      if (senderName.isNotEmpty) {
        final mention = '@$senderName ';
        if (!messageController.text.startsWith(mention)) {
          messageController.text = '$mention${messageController.text}';
        }
        messageController.selection = TextSelection.collapsed(
          offset: messageController.text.length,
        );
      }
    }

    setState(() {});

    messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    if (!replyController.hasReply) {
      return;
    }

    setState(() {
      replyController.cancelReply();
    });
  }

  Future<void> _confirmUndoMessage(Map<String, dynamic> message) async {
    // ========================================
    // TIN QUA 1 GIO
    //
    // VAN HIEN NUT THU HOI,
    // NHUNG BAM VAO THI THONG BAO NGAY.
    // ========================================

    if (_isRecallExpired(message)) {
      _showTopNotice(
        'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thu hồi tin nhắn?'),

          content: const Text(
            'Tin nhắn này sẽ được thu hồi với mọi người trong nhóm Zalo.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },

              child: const Text('Hủy'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              child: const Text('Thu hồi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _undoMessage(message);
  }

  Future<void> _confirmDeleteMessage(Map<String, dynamic> message) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa tin nhắn?'),

          content: const Text(
            'Tin nhắn sẽ bị xóa ở phía bạn. Người khác trong nhóm Zalo vẫn có thể thấy tin nhắn.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },

              child: const Text('Hủy'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),

              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteMessage(message);
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final actionKey = actionsController.messageActionKey(message);

    if (actionKey.isEmpty || actionsController.deletingMessageKey != null) {
      return;
    }

    final msgId = message['msgId']?.toString().trim();

    final cliMsgId = message['cliMsgId']?.toString().trim();

    if ((msgId == null || msgId.isEmpty) &&
        (cliMsgId == null || cliMsgId.isEmpty)) {
      _showTopNotice('Tin nhắn thiếu ID để xóa');

      return;
    }

    final deleteFuture = actionsController.deleteMessage(
      actionKey: actionKey,

      msgId: msgId,

      cliMsgId: cliMsgId,
    );

    setState(() {});

    try {
      final deleted = await deleteFuture;

      if (!deleted) {
        return;
      }

      if (!mounted) {
        return;
      }

      // ========================================
      // API THANH CONG
      //
      // XOA HAN BUBBLE KHOI CHATPAGE.
      // ========================================

      _removeMessageFromUi(message);

      _showTopNotice('Đã xóa tin nhắn');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTopNotice('Xóa tin nhắn thất bại');

      debugPrint('DELETE MESSAGE ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _undoMessage(Map<String, dynamic> message) async {
    if (_isRecallExpired(message)) {
      _showTopNotice(
        'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
      );

      return;
    }

    final actionKey = actionsController.messageActionKey(message);

    if (actionKey.isEmpty || actionsController.undoingMessageKey != null) {
      return;
    }

    final isSelf = message['isSelf'] == true;

    if (!isSelf) {
      _showTopNotice('Chỉ có thể thu hồi tin nhắn của bạn');

      return;
    }

    final msgId = message['msgId']?.toString().trim() ?? '';

    final cliMsgId = message['cliMsgId']?.toString().trim() ?? '';

    if (msgId.isEmpty || cliMsgId.isEmpty) {
      _showTopNotice('Tin nhắn thiếu ID để thu hồi');

      return;
    }

    final undoFuture = actionsController.undoMessage(
      actionKey: actionKey,

      msgId: msgId,

      cliMsgId: cliMsgId,
    );

    setState(() {});

    try {
      final undone = await undoFuture;

      if (!undone) {
        return;
      }

      if (!mounted) {
        return;
      }

      // ========================================
      // KHONG TU SUA MESSAGE THANH recalled.
      //
      // DOI listener Zalo gui
      // conversation_message_updated VE.
      // ========================================

      _showTopNotice('Đã thu hồi tin nhắn');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final errorText = error.toString().replaceFirst('Exception: ', '');

      // ========================================
      // BACKEND XAC DINH DA QUA 1 GIO
      // ========================================

      if (errorText.contains('1 giờ')) {
        _showTopNotice(
          'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
        );
      } else {
        _showTopNotice('Thu hồi tin nhắn thất bại');
      }

      debugPrint('UNDO MESSAGE ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showMessageActions(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'normal';

    if (status == 'deleted_local') {
      return;
    }

    final isSelf = message['isSelf'] == true;

    final msgId = message['msgId']?.toString().trim() ?? '';

    final cliMsgId = message['cliMsgId']?.toString().trim() ?? '';

    final messageContent = message['content']?.toString() ?? '';

    final canReply = status == 'normal';

    final canCopy = status == 'normal' && messageContent.trim().isNotEmpty;

    final canUndo =
        isSelf && status == 'normal' && msgId.isNotEmpty && cliMsgId.isNotEmpty;

    final canDownload =
        status == 'normal' &&
        (mediaController.isPhotoMessage(message) ||
            mediaController.isVideoMessage(message));

    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (sheetContext) {
        return ChatMessageActionsSheet(
          canReply: canReply,

          canCopy: canCopy,

          canUndo: canUndo,

          canDownload: canDownload,

          onDownload: canDownload
              ? () {
                  return _downloadMessageMedia(message);
                }
              : null,

          onReply: () {
            _startReply(message);
          },

          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: messageContent));

            if (!mounted) {
              return;
            }

            _showTopNotice('Đã sao chép tin nhắn');
          },

          onUndo: () {
            _confirmUndoMessage(message);
          },

          onDelete: () {
            _confirmDeleteMessage(message);
          },
        );
      },
    );
  }

  void _showTopNotice(String message) {
    if (!mounted) {
      return;
    }

    topNoticeTimer?.cancel();

    final messenger = ScaffoldMessenger.of(context);

    // ========================================
    // XOA BANNER CU NEU DANG HIEN
    // ========================================

    messenger.hideCurrentMaterialBanner();

    // ========================================
    // HIEN THONG BAO NGAY DUOI APP BAR
    // ========================================

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: Theme.of(context).colorScheme.surface,

        elevation: 2,

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        leading: Icon(
          Icons.check_circle_outline_rounded,

          size: 20,

          color: Theme.of(context).colorScheme.primary,
        ),

        content: Text(
          message,

          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),

        // ========================================
        // MaterialBanner BAT BUOC actions
        // PHAI CO IT NHAT 1 WIDGET.
        //
        // DUNG SizedBox.shrink()
        // DE KHONG HIEN NUT THUA.
        // ========================================
        actions: const [SizedBox.shrink()],
      ),
    );

    // ========================================
    // TU DONG AN SAU 1.2 GIAY
    // ========================================

    topNoticeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  Future<void> _pickAndSendPhoto() async {
    if (actionsController.sendingPhoto ||
        actionsController.sendingMessage ||
        messagesController.loading ||
        targetController.seekingTarget) {
      return;
    }

    if (replyController.hasReply) {
      _showTopNotice('Trả lời bằng ảnh sẽ được hỗ trợ sau.');

      return;
    }

    List<XFile> pickedPhotos;

    try {
      pickedPhotos = await imagePicker.pickMultiImage(
        maxWidth: 2048,

        imageQuality: 90,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTopNotice('Không thể mở thư viện ảnh');

      debugPrint('MULTI IMAGE PICKER ERROR: $error');

      return;
    }

    if (pickedPhotos.isEmpty || !mounted) {
      return;
    }

    if (pickedPhotos.length > 10) {
      _showTopNotice('Mỗi lần chỉ chọn tối đa 10 ảnh');

      return;
    }

    final sendFuture = actionsController.sendPhotos(
      filePaths: pickedPhotos.map((photo) => photo.path).toList(),
    );

    setState(() {});

    try {
      final sent = await sendFuture;

      if (!sent) {
        return;
      }

      if (!mounted) {
        return;
      }

      if (pickedPhotos.length == 1) {
        _showTopNotice('Đã gửi ảnh');
      } else {
        _showTopNotice('Đã gửi ${pickedPhotos.length} ảnh');
      }

      // ========================================
      // REFRESH NGAY SAU KHI GUI ANH
      //
      // Realtime van la nguon chinh.
      //
      // Tuy nhien message do CHINH MINH gui
      // co the khong duoc websocket echo ve ngay.
      //
      // Vi vay:
      // 1. reload ngay
      // 2. reload lai sau 1 giay lam fallback
      // ========================================

      _requestLatestReload(force: true);

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) {
          return;
        }

        _requestLatestReload(force: true);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');

      _showTopNotice(message.isEmpty ? 'Gửi ảnh thất bại' : message);

      debugPrint('SEND PHOTOS ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendChatMessage() async {
    if (actionsController.sendingMessage ||
        actionsController.sendingPhoto) {
      return;
    }

    final text = messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    final wasNearBottom =
        !scrollController.hasClients ||
        (scrollController.position.pixels -
                scrollController.position.minScrollExtent) <
            140;

    // ========================================
    // REPLY TARGET
    // ========================================

    final replyMsgId = replyController.replyMsgId;

    final replyCliMsgId = replyController.replyCliMsgId;

    final sendFuture = actionsController.sendText(
      text: text,

      replyToMsgId: replyMsgId,

      replyToCliMsgId: replyCliMsgId,
    );

    setState(() {});

    try {
      final sent = await sendFuture;

      if (!sent) {
        return;
      }

      if (!mounted) {
        return;
      }

      messageController.clear();

      setState(() {
        replyController.clearReply();

        targetController.clearCurrentTarget();

        // ========================================
        // GUI TIN KHI DANG XEM HISTORY:
        //
        // Khong ep list thay doi ngay.
        // Cho user bam ↓ moi catch-up.
        // ========================================

        if (!wasNearBottom) {
          hasDeferredNewMessages = true;

          showNewMessageButton = true;
        }
      });

      // Giu focus hien tai tu nhien.
      // Khong requestFocus lai sau async send vi tren Android
      // co the lam IME dong mot nhip roi bat lai (keyboard flicker).

      // ========================================
      // CHI TU DONG CUON XUONG CUOI
      // NEU TRUOC KHI GUI USER DANG O GAN CUOI.
      //
      // Neu user dang xem tin cu:
      // - giu nguyen vi tri
      // - realtime message moi se hien nut ↓
      // ========================================

      if (wasNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _scrollToBottom();
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final errorText = error.toString().replaceFirst('Exception: ', '').trim();

      final lower = errorText.toLowerCase();

      final replyUnavailable =
          lower.contains('khong con co the tra loi') ||
          lower.contains('không còn có thể trả lời') ||
          lower.contains('khong tim thay tin nhan can tra loi') ||
          lower.contains('không tìm thấy tin nhắn cần trả lời');

      if (replyUnavailable) {
        setState(() {
          replyController.clearReply();
        });

        _showTopNotice('Tin nhắn gốc đã bị xóa hoặc thu hồi.');
      } else {
        _showTopNotice(
          errorText.isEmpty
              ? 'Gửi tin nhắn thất bại'
              : errorText,
        );
      }

      debugPrint('SEND MESSAGE ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _openVideo(Map<String, dynamic> message) async {
    final url = mediaController.messageMediaUrl(message);

    if (url == null || url.isEmpty) {
      _showTopNotice('Video không có đường dẫn');

      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) {
      _showTopNotice('Đường dẫn video không hợp lệ');

      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            return VideoViewerPage(videoUrl: url);
          },
        ),
      );

      debugPrint('OPEN VIDEO PAGE CLOSED');
    } catch (error) {
      debugPrint(
        'OPEN VIDEO NAVIGATION ERROR: '
        '$error',
      );

      if (!mounted) {
        return;
      }

      _showTopNotice('Không thể mở video');
    }
  }

  Future<void> _openFileMessage(Map<String, dynamic> message) async {
    final rawUrl = mediaController.messageMediaUrl(message);

    if (rawUrl == null || rawUrl.isEmpty) {
      _showTopNotice('Tệp không có đường dẫn');

      return;
    }

    final uri = Uri.tryParse(rawUrl);

    if (uri == null) {
      _showTopNotice('Đường dẫn tệp không hợp lệ');

      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        _showTopNotice('Không thể mở tệp');
      }
    } catch (error) {
      debugPrint('OPEN FILE ERROR: $error');

      if (!mounted) {
        return;
      }

      _showTopNotice('Không thể mở tệp');
    }
  }

  Future<void> initializeChat() async {
    // ========================================
    // 1. LOAD CHAT
    // ========================================

    await loadMessages();

    if (!mounted) {
      return;
    }

    // ========================================
    // 2. BAT REALTIME
    // ========================================

    realtimeController.start();

    // ========================================
    // 3. USER DA MO CONVERSATION
    // -> DANH DA DOC.
    // ========================================

    markReadController.schedule(immediate: true);
  }

  Future<void> loadMessages() async {
    targetController.resetForLoad();

    if (!mounted) {
      return;
    }

    setState(() {
      initialLoadError = null;
    });

    // ========================================
    // loadInitial() CHAY DONG BO DEN
    // await DAU TIEN.
    //
    // Vi vay loading=true DA DUOC SET
    // TRUOC setState() BEN DUOI.
    // ========================================

    final loadFuture = messagesController.loadInitial();

    setState(() {});

    try {
      await loadFuture;

      if (!mounted) {
        return;
      }

      // ========================================
      // MESSAGE DATA DA THAY DOI TRONG
      // CONTROLLER -> REBUILD UI.
      // ========================================

      setState(() {});

      // ========================================
      // DOI LISTVIEW BUILD
      // ========================================

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        return;
      }

      // ========================================
      // BAT DAU CHINH XAC O TIN MOI NHAT
      // ========================================

      await _jumpToBottomInitial();

      if (!mounted) {
        return;
      }

      // ========================================
      // MO TU LICH SU NHAN
      // ========================================

      if (targetController.hasTarget) {
        await _seekTargetFromLatest();

        return;
      }

      // ========================================
      // CHAT BINH THUONG
      // ========================================

      messagesController.setPaginationReady(true);

      Future.microtask(() => _ensureHistoryScrollable());
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();

      setState(() {
        targetController.finishSeeking();

        initialLoadError =
            message.isEmpty ? 'Không thể tải hội thoại.' : message;
      });
    }
  }

  Future<bool> _activateTargetAtIndex(int index) async {
    if (!mounted) {
      return false;
    }

    // ========================================
    // SET TARGET
    // ========================================

    setState(() {
      targetController.setFound(index);
    });

    // ========================================
    // CENTER TARGET
    // ========================================

    final centered = await _centerTargetMessage();

    if (!mounted) {
      return false;
    }

    if (!centered) {
      return false;
    }

    // ========================================
    // HIGHLIGHT
    // ========================================

    setState(() {
      targetController.showHighlight();
    });

    _removeTargetHighlightLater();

    return true;
  }

  Future<String> _resolveMissingMessageReason({
    String? msgId,
    String? cliMsgId,
  }) async {
    final safeMsgId = msgId?.trim() ?? '';

    final safeCliMsgId = cliMsgId?.trim() ?? '';

    if (safeMsgId.isEmpty && safeCliMsgId.isEmpty) {
      return 'not_found';
    }

    try {
      final result = await backend.findConversationMessage(
        groupId: widget.groupId,
        msgId: safeMsgId.isEmpty ? null : safeMsgId,
        cliMsgId: safeCliMsgId.isEmpty ? null : safeCliMsgId,
      );

      final reason = result['reason']?.toString().trim();

      if (reason == 'deleted_local' || reason == 'recalled') {
        return reason!;
      }

      final rawMessage = result['message'];

      if (rawMessage is Map) {
        final status = rawMessage['status']?.toString().trim();

        if (status == 'deleted_local' || status == 'recalled') {
          return status!;
        }
      }
    } catch (error) {
      debugPrint(
        'CHAT RESOLVE MISSING MESSAGE REASON ERROR: '
        '$error',
      );
    }

    return 'not_found';
  }

  Future<void> _seekTargetFromLatest() async {
    if (targetController.seekingTarget || !targetController.hasTarget) {
      return;
    }

    targetController.beginSeeking();

    messagesController.setPaginationReady(false);

    try {
      while (mounted) {
        // ========================================
        // TARGET DA NAM TRONG SO MESSAGE
        // DA LOAD CHUA?
        // ========================================

        final foundIndex = targetController.findTargetIndex(
          messagesController.messages,
        );

        if (foundIndex >= 0) {
          final activated = await _activateTargetAtIndex(foundIndex);

          if (!mounted) {
            return;
          }

          if (!activated) {
            debugPrint(
              'TARGET FOUND BUT CENTER FAILED: '
              'index=$foundIndex',
            );
          }

          return;
        }

        // ========================================
        // KHONG CON TIN CU DE TIM
        // ========================================

        if (!messagesController.hasMoreOlder) {
          final reason = await _resolveMissingMessageReason(
            msgId: targetController.targetMsgId,
            cliMsgId: targetController.targetCliMsgId,
          );

          if (!mounted) {
            return;
          }

          targetController.setError(reason);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTargetNotFound();
          });

          return;
        }

        final beforeId = messagesController.messages.first['id']?.toString();

        if (beforeId == null || beforeId.isEmpty) {
          final reason = await _resolveMissingMessageReason(
            msgId: targetController.targetMsgId,
            cliMsgId: targetController.targetCliMsgId,
          );

          if (!mounted) {
            return;
          }

          targetController.setError(reason);

          _showTargetNotFound();

          return;
        }

        // ========================================
        // LOAD THEM MOT PAGE TIN CU
        // ========================================

        final page = await messagesController.fetchOlderPage(
          beforeId: beforeId,
          limit: ChatTargetController.seekPageSize,
        );

        if (!mounted) {
          return;
        }

        final older = page.messages;

        final uniqueOlder = messagesController.uniqueAgainst(
          messagesController.messages,

          older,
        );

        if (uniqueOlder.isEmpty) {
          messagesController.markNoMoreOlder();

          continue;
        }

        setState(() {
          messagesController.prependOlderPage(
            uniqueOlder,

            hasBefore: page.hasBefore,
          );
        });

        // ========================================
        // DOI PAGE MOI DUOC BUILD
        // ========================================

        await WidgetsBinding.instance.endOfFrame;

        if (!mounted) {
          return;
        }

        // ========================================
        // CUC KY QUAN TRONG:
        //
        // KIEM TRA TARGET NGAY SAU KHI
        // PAGE MOI VUA DUOC THEM.
        //
        // NEU TARGET NAM TRONG PAGE NAY
        // THI DUNG NGAY TAI TARGET.
        //
        // KHONG CHAY QUA TARGET DEN CUOI PAGE.
        // ========================================

        final foundAfterLoad = targetController.findTargetIndex(
          messagesController.messages,
        );

        if (foundAfterLoad >= 0) {
          final activated = await _activateTargetAtIndex(foundAfterLoad);

          if (!mounted) {
            return;
          }

          if (!activated) {
            debugPrint(
              'TARGET FOUND AFTER LOAD '
              'BUT CENTER FAILED: '
              'index=$foundAfterLoad',
            );
          }

          return;
        }

        // ========================================
        // TARGET CHUA NAM TRONG PAGE VUA LOAD.
        //
        // BAY GIO MOI CHAY LEN DAU PAGE
        // DE TIEP TUC LOAD PAGE CU HON.
        // ========================================

        if (!scrollController.hasClients) {
          continue;
        }

        await scrollController.animateTo(
          scrollController.position.maxScrollExtent,

          duration: const Duration(milliseconds: 180),

          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      debugPrint('TARGET SEEK ERROR: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tìm tin nhắn: $error')),
        );
      }
    } finally {
      targetController.finishSeeking();

      if (mounted) {
        messagesController.setPaginationReady(true);
      }
    }
  }

  Future<void> _jumpToQuotedMessage(Map<String, dynamic> quote) async {
    if (targetController.seekingTarget) {
      return;
    }

    final quoteMsgId = quote['msgId']?.toString().trim();

    final quoteCliMsgId = quote['cliMsgId']?.toString().trim();

    // ========================================
    // QUOTE PHAI CO IT NHAT MOT ID
    // ========================================

    if ((quoteMsgId == null || quoteMsgId.isEmpty) &&
        (quoteCliMsgId == null || quoteCliMsgId.isEmpty)) {
      debugPrint(
        'QUOTE WITHOUT MESSAGE ID: '
        '${quote.keys.toList()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xác định tin nhắn gốc.')),
        );
      }

      return;
    }

    // ========================================
    // BAT DAU CHE DO TIM TARGET
    // ========================================

    targetController.cancelHighlightTimer();

    setState(() {
      targetController.beginSeeking(clearCurrentTarget: true);
    });

    messagesController.setPaginationReady(false);

    try {
      while (mounted) {
        // ========================================
        // 1. TARGET DA DUOC LOAD CHUA?
        // ========================================

        final foundIndex = targetController.findMessageIndexByIds(
          messagesController.messages,

          msgId: quoteMsgId,

          cliMsgId: quoteCliMsgId,
        );

        if (foundIndex >= 0) {
          final activated = await _activateTargetAtIndex(foundIndex);

          if (!mounted) {
            return;
          }

          if (!activated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã tìm thấy tin nhắn nhưng không thể cuộn tới vị trí đó.',
                ),
              ),
            );

            return;
          }

          debugPrint(
            'QUOTE TARGET FOUND: '
            'index=$foundIndex '
            'msgId=$quoteMsgId '
            'cliMsgId=$quoteCliMsgId',
          );

          return;
        }

        // ========================================
        // 2. CHUA TIM THAY
        // NHUNG KHONG CON HISTORY CU HON
        // ========================================

        if (!messagesController.hasMoreOlder ||
            messagesController.messages.isEmpty) {
          final reason = await _resolveMissingMessageReason(
            msgId: quoteMsgId,
            cliMsgId: quoteCliMsgId,
          );

          if (!mounted) {
            return;
          }

          final notice = switch (reason) {
            'deleted_local' => 'Tin nhắn gốc đã bị xóa.',
            'recalled' => 'Tin nhắn gốc đã được thu hồi.',
            _ => 'Không tìm thấy tin nhắn gốc trong lịch sử.',
          };

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notice)));

          return;
        }

        // ========================================
        // 3. LOAD THEM MESSAGE CU HON
        // ========================================

        final beforeId = messagesController.messages.first['id']?.toString();

        if (beforeId == null || beforeId.isEmpty) {
          return;
        }

        final page = await messagesController.fetchOlderPage(
          beforeId: beforeId,
          limit: ChatTargetController.seekPageSize,
        );

        if (!mounted) {
          return;
        }

        final older = page.messages;

        final uniqueOlder = messagesController.uniqueAgainst(
          messagesController.messages,

          older,
        );

        // ========================================
        // BACKEND KHONG TRA THEM DU LIEU
        // ========================================

        if (uniqueOlder.isEmpty) {
          messagesController.markNoMoreOlder();

          continue;
        }

        setState(() {
          messagesController.prependOlderPage(
            uniqueOlder,

            hasBefore: page.hasBefore,
          );
        });

        // ========================================
        // DOI LIST BUILD XONG ROI TIM LAI
        // ========================================

        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (error) {
      debugPrint(
        'JUMP TO QUOTED MESSAGE ERROR: '
        '$error',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở tin nhắn gốc: $error')),
        );
      }
    } finally {
      targetController.finishSeeking();

      if (mounted) {
        messagesController.setPaginationReady(true);
      }
    }
  }

  Future<bool> _centerTargetMessage() async {
    if (targetController.targetIndex == null) {
      return false;
    }

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || !scrollController.hasClients) {
      return false;
    }

    // ========================================
    // KHONG UOC LUONG BANG INDEX NUA.
    //
    // TA DI DAN VE PHIA TIN CU
    // CHO DEN KHI TARGET THUC SU DUOC BUILD.
    //
    // reverse:true
    //
    // min = moi nhat
    // max = cu nhat
    // ========================================

    const scanStep = 300.0;

    for (int attempt = 0; attempt < 200; attempt++) {
      if (!mounted) {
        return false;
      }

      // ========================================
      // TARGET DA DUOC BUILD
      // ========================================

      final targetContext = targetMessageKey.currentContext;

      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,

          alignment: 0.5,

          duration: const Duration(milliseconds: 220),

          curve: Curves.easeInOut,
        );

        return true;
      }

      if (!scrollController.hasClients) {
        return false;
      }

      final position = scrollController.position;

      final currentPixels = position.pixels;

      final maxPixels = position.maxScrollExtent;

      // ========================================
      // DA DEN TAN CUNG PHIA TIN CU
      // MA TARGET VAN CHUA BUILD
      // ========================================

      if (currentPixels >= maxPixels - 1) {
        break;
      }

      // ========================================
      // DI THEM MOT DOAN VE PHIA TIN CU
      // ========================================

      final nextPixels = (currentPixels + scanStep)
          .clamp(position.minScrollExtent, maxPixels)
          .toDouble();

      await scrollController.animateTo(
        nextPixels,

        duration: const Duration(milliseconds: 70),

        curve: Curves.linear,
      );

      // Cho Flutter build cac bubble
      // vua di vao viewport.
      await WidgetsBinding.instance.endOfFrame;
    }

    // ========================================
    // KIEM TRA LAN CUOI
    // ========================================

    final finalContext = targetMessageKey.currentContext;

    if (finalContext != null && finalContext.mounted) {
      await Scrollable.ensureVisible(
        finalContext,

        alignment: 0.5,

        duration: const Duration(milliseconds: 220),

        curve: Curves.easeInOut,
      );

      return true;
    }

    debugPrint(
      'TARGET CENTER FAILED: '
      'index=${targetController.targetIndex} '
      'messages=${messagesController.messages.length} '
      'pixels=${scrollController.position.pixels} '
      'max=${scrollController.position.maxScrollExtent}',
    );

    return false;
  }

  Future<void> loadOlderMessages() async {
    if (!messagesController.canLoadOlder) {
      return;
    }

    // ========================================
    // loadOlder() SE SET:
    //
    // loadingOlder = true
    // paginationReady = false
    //
    // TRUOC await DAU TIEN.
    // ========================================

    final loadFuture = messagesController.loadOlder();

    if (mounted) {
      setState(() {});
    }

    try {
      final addedCount = await loadFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        // ========================================
        // NEU MESSAGE CU DUOC PREPEND
        // THI TARGET INDEX HIEN TAI
        // PHAI DICH THEO.
        // ========================================

        if (addedCount > 0) {
          targetController.adjustAfterPrepend(addedCount);
        }
      });
    } catch (error) {
      debugPrint(
        'LOAD OLDER MESSAGES ERROR: '
        '$error',
      );

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _preserveViewportAfterNewContent({
    required double beforePixels,
    required double beforeMaxScrollExtent,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) {
        return;
      }

      final position = scrollController.position;

      // ========================================
      // CHIEU CAO CONTENT VUA DUOC THEM.
      // ========================================

      final addedExtent = position.maxScrollExtent - beforeMaxScrollExtent;

      if (addedExtent <= 0) {
        return;
      }

      // ========================================
      // reverse:true
      //
      // Tin moi nam phia bottom.
      //
      // Content tang bao nhieu thi tang
      // scroll offset bay nhieu de giu nguyen
      // bubble dang xem.
      // ========================================

      final targetPixels = (beforePixels + addedExtent)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if ((position.pixels - targetPixels).abs() < 0.5) {
        return;
      }

      // jumpTo, KHONG animateTo.
      //
      // Day la bu offset noi bo,
      // user khong duoc cam thay
      // day la mot thao tac scroll.
      scrollController.jumpTo(targetPixels);
    });
  }

  void _scrollToBottom() {
    if (!mounted) {
      return;
    }

    if (showNewMessageButton) {
      setState(() {
        showNewMessageButton = false;
      });
    }

    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.minScrollExtent,

      duration: const Duration(milliseconds: 350),

      curve: Curves.easeOut,
    );
  }

  void _jumpToLatestMessages() {
    if (!mounted) {
      return;
    }

    setState(() {
      showNewMessageButton = false;

      targetController.clearCurrentTarget();
    });

    // ========================================
    // CO MESSAGE MOI DANG DEFER
    // HOAC DANG O HISTORY CO newer.
    //
    // LOAD/CATCH-UP TRUOC ROI MOI XUONG.
    // ========================================

    if (hasDeferredNewMessages || messagesController.hasMoreNewer) {
      scrollToLatestAfterReload = true;

      _requestLatestReload(force: true);

      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _scrollToBottom();
    });
  }

  bool _isNearBottom({double threshold = 140}) {
    if (!scrollController.hasClients) {
      return true;
    }

    final position = scrollController.position;

    return position.pixels - position.minScrollExtent < threshold;
  }

  void _removeTargetHighlightLater() {
    targetController.scheduleHighlightRemoval(
      onExpired: () {
        if (!mounted) {
          return;
        }

        setState(() {});
      },
    );
  }

  void _showTargetNotFound() {
    if (!mounted) {
      return;
    }

    final canShow = targetController.markNoticeShown();

    if (!canShow) {
      return;
    }

    String description;

    switch (targetController.targetErrorReason) {
      case 'recalled':
        description = 'Tin nhắn này đã được thu hồi.';

        break;

      case 'deleted_local':
        description = 'Tin nhắn này đã bị xóa.';

        break;

      case 'not_found':
        description = 'Tin nhắn không còn tồn tại hoặc chưa được lưu trong lịch sử hội thoại.';

        break;

      default:
        description = 'Không thể tìm thấy tin nhắn gốc của cuốc này.';
    }

    showDialog<void>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.search_off_outlined),

              SizedBox(width: 10),

              Expanded(child: Text('Không tìm thấy tin nhắn')),
            ],
          ),

          content: Text(description),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ensureHistoryScrollable({int attempt = 0}) async {
    if (!mounted ||
        !messagesController.paginationReady ||
        messagesController.loading ||
        messagesController.loadingOlder ||
        !messagesController.hasMoreOlder ||
        messagesController.messages.isEmpty) {
      return;
    }

    // ========================================
    // DOI LISTVIEW BUILD XONG
    // ========================================

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || !messagesController.hasMoreOlder || attempt >= 10) {
      return;
    }

    // ========================================
    // DOI SCROLL CONTROLLER SAN SANG
    // ========================================

    if (!scrollController.hasClients) {
      if (attempt >= 10) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 60));

      return _ensureHistoryScrollable(attempt: attempt + 1);
    }

    final position = scrollController.position;

    // ========================================
    // DA DU TIN DE CUON
    // ========================================

    if (position.maxScrollExtent > 800) {
      return;
    }

    // ========================================
    // MAN HINH CHUA DU TIN
    //
    // TU DONG LOAD THEM TIN CU
    // KHONG CAN USER PHAI KEO
    // ========================================

    debugPrint(
      'CHAT AUTO FILL OLDER: '
      'messages=${messagesController.messages.length} '
      'hasMoreOlder=${messagesController.hasMoreOlder}',
    );

    await loadOlderMessages();

    if (!mounted || !messagesController.hasMoreOlder || attempt >= 10) {
      return;
    }

    // ========================================
    // NEU VAN CHUA DAY MAN HINH
    // LOAD THEM 1 PAGE NUA
    // ========================================

    await _ensureHistoryScrollable(attempt: attempt + 1);
  }

  void _requestLatestReload({bool force = false}) {
    messagesController.scheduleLatestReload(
      force: force,

      onApplied: _handleLatestReloadApplied,

      onError: _handleLatestReloadError,
    );
  }

  void _handleLatestReloadApplied(ChatMessagesReloadResult result) {
    if (!mounted) {
      return;
    }

    // ========================================
    // LUU VIEWPORT CU TRUOC KHI REBUILD.
    // ========================================

    final hadScrollPosition = scrollController.hasClients;

    final beforePixels = hadScrollPosition
        ? scrollController.position.pixels
        : 0.0;

    final beforeMaxScrollExtent = hadScrollPosition
        ? scrollController.position.maxScrollExtent
        : 0.0;

    final wasNearBottom = _isNearBottom();

    final shouldJumpToLatest = scrollToLatestAfterReload;

    scrollToLatestAfterReload = false;

    // Force reload da lay lai latest.
    // Khong con message nao dang deferred
    // o local nua.
    if (result.force) {
      hasDeferredNewMessages = false;
    }

    setState(() {
      if (wasNearBottom || shouldJumpToLatest) {
        showNewMessageButton = false;
      }
    });

    // ========================================
    // USER MUON XUONG LATEST
    // HOAC DANG O GAN BOTTOM.
    // ========================================

    if (wasNearBottom || shouldJumpToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _scrollToBottom();
      });
    } else if (hadScrollPosition) {
      // ========================================
      // USER DANG DOC TIN CU.
      //
      // Reload co them content moi thi
      // GIU NGUYEN VIEWPORT.
      // ========================================

      _preserveViewportAfterNewContent(
        beforePixels: beforePixels,

        beforeMaxScrollExtent: beforeMaxScrollExtent,
      );
    }

    debugPrint(
      'CHAT REALTIME RELOAD DONE: '
      'latest=${result.latestCount} '
      'total=${result.totalCount} '
      'force=${result.force}',
    );
  }

  void _handleLatestReloadError(Object error, StackTrace stackTrace) {
    if (scrollToLatestAfterReload && mounted) {
      scrollToLatestAfterReload = false;

      setState(() {
        // Cho user bam lai.
        showNewMessageButton = true;
      });
    }

    debugPrint(
      'CHAT REALTIME RELOAD ERROR: '
      '$error',
    );
  }

  void upsertRealtimeMessage(Map<String, dynamic> incoming) {
    if (!mounted) {
      return;
    }

    final incomingStatus = incoming['status']?.toString() ?? 'normal';

    final replyCleared =
        replyController.clearIfTargetUnavailable(incoming);

    if (replyCleared) {
      setState(() {});
    }

    // ========================================
    // MESSAGE DA XOA
    // ========================================

    if (incomingStatus == 'deleted_local') {
      _removeMessageFromUi(incoming);

      return;
    }

    // ========================================
    // BO EVENT KHONG HIEN THI
    // ========================================

    if (!messagesController.shouldDisplayMessage(incoming)) {
      debugPrint(
        'CHAT SKIP NON-DISPLAY MESSAGE: '
        'msgId=${incoming['msgId']} '
        'cliMsgId=${incoming['cliMsgId']} '
        'msgType=${incoming['msgType']}',
      );

      return;
    }

    final wasNearBottom = _isNearBottom();

    final existingIndex = messagesController.indexOfSame(
      messagesController.messages,
      incoming,
    );

    final isNewMessage = existingIndex < 0;

    // ========================================
    // QUAN TRONG:
    //
    // USER DANG XEM TIN CU
    // HOAC DANG O HISTORY CONTEXT.
    //
    // KHONG INSERT MESSAGE MOI VAO LIST.
    //
    // Neu insert vao reverse ListView,
    // index cua tat ca message bi dich
    // va viewport se rung / nhay.
    // ========================================

    final shouldDeferNewMessage =
        isNewMessage &&
        (!wasNearBottom ||
            targetController.targetIndex != null ||
            messagesController.hasMoreNewer);

    if (shouldDeferNewMessage) {
      setState(() {
        hasDeferredNewMessages = true;

        showNewMessageButton = true;
      });

      return;
    }

    // ========================================
    // MESSAGE DA TON TAI:
    // van cho phep update.
    //
    // MESSAGE MOI KHI USER DANG O BOTTOM:
    // insert binh thuong.
    // ========================================

    late final ChatMessageUpsertResult upsertResult;

    setState(() {
      upsertResult = messagesController.upsertRealtime(incoming);
    });

    // ========================================
    // MESSAGE MOI KHI USER DANG O CUOI
    // -> THEO XUONG DUOI.
    // ========================================

    if (upsertResult == ChatMessageUpsertResult.inserted &&
        wasNearBottom &&
        targetController.targetIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _scrollToBottom();
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!mounted) {
      return false;
    }

    // ========================================
    // USER TU CUON VE BOTTOM
    // -> AN NUT TIN MOI.
    //
    // Logic nay PHAI chay truoc
    // pagination guard.
    // ========================================

    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final metrics = notification.metrics;

      final nearBottom = metrics.pixels - metrics.minScrollExtent < 140;

      if (nearBottom) {
        // ========================================
        // USER TU KEO XUONG CUOI
        // NHUNG CON MESSAGE MOI CHUA LOAD.
        // ========================================

        if (hasDeferredNewMessages && !scrollToLatestAfterReload) {
          scrollToLatestAfterReload = true;

          _requestLatestReload(force: true);

          return false;
        }

        if (showNewMessageButton) {
          setState(() {
            showNewMessageButton = false;
          });
        }
      }
    }

    // ========================================
    // CAC GUARD BEN DUOI CHI DANH
    // CHO LOAD OLDER.
    // ========================================

    if (!messagesController.paginationReady ||
        targetController.seekingTarget ||
        messagesController.loading ||
        messagesController.loadingOlder ||
        messagesController.messages.isEmpty ||
        !messagesController.hasMoreOlder) {
      return false;
    }

    // ========================================
    // USER DANG KEO TRONG LIST
    // ========================================

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) {
        return false;
      }

      final delta = notification.scrollDelta ?? 0.0;

      final metrics = notification.metrics;

      final distanceToOlderEdge = metrics.maxScrollExtent - metrics.pixels;

      // reverse:true
      //
      // delta > 0 = di ve tin cu.
      if (delta > 0 && distanceToOlderEdge <= 500) {
        loadOlderMessages();
      }

      return false;
    }

    // ========================================
    // USER DA O SAT MEP TIN CU
    // VAN CO KEo THEM
    // ========================================

    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) {
        return false;
      }

      final metrics = notification.metrics;

      if (metrics.pixels >= metrics.maxScrollExtent - 5) {
        loadOlderMessages();
      }
    }

    return false;
  }

  Future<void> _jumpToBottomInitial({int attempt = 0}) async {
    if (!mounted) {
      return;
    }

    if (!scrollController.hasClients) {
      if (attempt >= 10) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 80));

      if (!mounted) {
        return;
      }

      return _jumpToBottomInitial(attempt: attempt + 1);
    }

    scrollController.jumpTo(scrollController.position.minScrollExtent);

    // Cho viewport on dinh
    // truoc khi bat dau seek.
    await WidgetsBinding.instance.endOfFrame;
  }

  // ========================================
  // TIME
  // ========================================

  String formatTime(dynamic timestamp) {
    final raw = int.tryParse(timestamp?.toString() ?? '');

    if (raw == null || raw <= 0) {
      return '';
    }

    final timestampMs = raw < 100000000000 ? raw * 1000 : raw;

    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();

    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  List<PhotoViewerItem> _buildPhotoViewerItems(
    List<Map<String, dynamic>> sourceMessages,
  ) {
    final result = <PhotoViewerItem>[];

    for (final message in sourceMessages) {
      final photoUrl = mediaController.extractPhotoUrl(message);

      if (photoUrl == null || photoUrl.isEmpty) {
        continue;
      }

      result.add(
        PhotoViewerItem(
          url: photoUrl,
          heroTag: mediaController.photoHeroTag(message),
        ),
      );
    }

    return result;
  }

  Future<PhotoViewerLoadResult> _loadOlderPhotoViewerItems() async {
    // ========================================
    // SO ANH TRUOC KHI LOAD THEM HISTORY
    // ========================================

    final beforePhotos = mediaController.allLoadedPhotoMessages(
      messagesController.messages,
    );

    final beforeCount = beforePhotos.length;

    var attempts = 0;

    // ========================================
    // MOT PAGE HISTORY CO THE KHONG CO ANH.
    //
    // VI VAY CO THE LOAD LIEN TIEP TOI DA
    // 6 PAGE DE TIM ANH CU HON.
    //
    // KHONG LOAD TOAN BO HISTORY MOT LUC.
    // ========================================

    while (mounted && messagesController.hasMoreOlder && attempts < 6) {
      attempts += 1;

      await loadOlderMessages();

      if (!mounted) {
        break;
      }

      final currentPhotos = mediaController.allLoadedPhotoMessages(
        messagesController.messages,
      );

      // ========================================
      // DA TIM THAY IT NHAT MOT ANH CU HON
      // ========================================

      if (currentPhotos.length > beforeCount) {
        return PhotoViewerLoadResult(
          items: _buildPhotoViewerItems(currentPhotos),

          hasMoreOlder: messagesController.hasMoreOlder,
        );
      }

      // ========================================
      // HET HISTORY
      // ========================================

      if (!messagesController.hasMoreOlder) {
        break;
      }
    }

    final photos = mediaController.allLoadedPhotoMessages(
      messagesController.messages,
    );

    return PhotoViewerLoadResult(
      items: _buildPhotoViewerItems(photos),

      hasMoreOlder: messagesController.hasMoreOlder,
    );
  }

  Future<void> _openPhotoViewer(Map<String, dynamic> message) async {
    // ========================================
    // TAT CA PHOTO HIEN DA LOAD
    //
    // KHONG PHAN BIET ALBUM.
    // ========================================

    final sourceMessages = mediaController.allLoadedPhotoMessages(
      messagesController.messages,
    );

    final viewerItems = _buildPhotoViewerItems(sourceMessages);

    if (viewerItems.isEmpty) {
      _showTopNotice('Không có ảnh để xem');

      return;
    }

    // ========================================
    // TIM DUNG ANH USER VUA BAM
    // ========================================

    final clickedHeroTag = mediaController.photoHeroTag(message);

    var initialIndex = viewerItems.indexWhere(
      (item) => item.heroTag == clickedHeroTag,
    );

    if (initialIndex < 0) {
      initialIndex = 0;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,

        transitionDuration: const Duration(milliseconds: 250),

        reverseTransitionDuration: const Duration(milliseconds: 220),

        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoViewerPage(
            items: viewerItems,

            initialIndex: initialIndex,

            // ========================================
            // PAGINATION
            // ========================================
            initialHasMoreOlder: messagesController.hasMoreOlder,

            onLoadOlder: _loadOlderPhotoViewerItems,
          );
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildStickerMessage(Map<String, dynamic> message) {
    final stickerUrl = mediaController.messageMediaUrl(message);

    return StickerMessageBubble(stickerUrl: stickerUrl);
  }

  Widget _buildVideoMessage(Map<String, dynamic> message) {
    final thumbUrl = mediaController.messageMediaThumbUrl(message);

    final width = double.tryParse(message['mediaWidth']?.toString() ?? '');

    final height = double.tryParse(message['mediaHeight']?.toString() ?? '');

    return VideoMessageBubble(
      thumbnailUrl: thumbUrl,

      mediaWidth: width,

      mediaHeight: height,

      onTap: () {
        _openVideo(message);
      },
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message) {
    final fileName = message['fileName']?.toString();

    final fileExtension = message['fileExtension']?.toString();

    final fileSize = message['mediaFileSize'];

    return FileMessageBubble(
      fileName: fileName,

      fileExtension: fileExtension,

      fileSize: fileSize,

      onTap: () {
        _openFileMessage(message);
      },
    );
  }

  Widget _buildVoiceMessage(Map<String, dynamic> message) {
    final colorScheme = Theme.of(context).colorScheme;

    // ========================================
    // URL
    // ========================================

    final url = message['mediaUrl']?.toString().trim();

    if (url == null || url.isEmpty) {
      return Text(
        '[Tin nhắn thoại]',
        style: TextStyle(color: colorScheme.onSurface),
      );
    }

    // ========================================
    // CAC DU LIEU KHONG DOI TRONG LUC PLAY
    //
    // TINH MOT LAN KHI MESSAGE DUOC BUILD.
    // KHONG TINH LAI MOI AUDIO TICK.
    // ========================================

    final rawDuration = message['mediaDuration'];

    final messageDuration = rawDuration is num
        ? Duration(milliseconds: rawDuration.toInt())
        : Duration.zero;

    final samples = message['waveformSamples'] is List
        ? message['waveformSamples'] as List
        : <dynamic>[];

    // ========================================
    // CHI VOICE BUBBLE NAY LANG NGHE PLAYER.
    //
    // ChatPage KHONG CON setState()
    // THEO AUDIO POSITION.
    // ========================================

    return AnimatedBuilder(
      animation: voiceController,

      builder: (context, child) {
        final isCurrentVoice = voiceController.isCurrent(url);

        final totalDuration =
            isCurrentVoice && voiceController.duration > Duration.zero
            ? voiceController.duration
            : messageDuration;

        final progress = isCurrentVoice && totalDuration.inMilliseconds > 0
            ? (voiceController.position.inMilliseconds /
                      totalDuration.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble()
            : 0.0;

        final isActuallyPlaying = voiceController.isVoicePlaying(url);

        return VoiceMessageBubble(
          samples: samples,

          duration: totalDuration,

          progress: progress,

          isPlaying: isActuallyPlaying,

          onToggle: () {
            voiceController.toggle(url);
          },
        );
      },
    );
  }

  Widget _buildPhotoMediaRow(Map<String, dynamic> message, int index) {
    final isSelf = message['isSelf'] == true;

    final senderName = message['senderName']?.toString() ?? 'Thành viên';

    // ========================================
    // ALBUM
    // ========================================

    final mediaGroupId = mediaController.mediaGroupId(message);

    final album = mediaGroupId != null
        ? (photoAlbumIndex?.albumFor(mediaGroupId, message) ??
            <Map<String, dynamic>>[message])
        : <Map<String, dynamic>>[message];

    // ========================================
    // PHOTO UI
    // ========================================

    final media = PhotoMessageBubble(
      album: album,

      resolvePhotoUrl: mediaController.extractPhotoUrl,

      resolvePhotoParams: mediaController.photoParams,

      resolveHeroTag: mediaController.photoHeroTag,

      onOpenPhoto: (selectedMessage) {
        _openPhotoViewer(selectedMessage);
      },

      onLongPressPhoto: (selectedMessage) {
        _showMessageActions(selectedMessage);
      },
    );

    // ========================================
    // STABLE KEY
    // ========================================

    final stableKey =
        mediaGroupId ??
        message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        index.toString();

    // ========================================
    // TARGET
    // ========================================

    final isTarget = index == targetController.targetIndex;

    // ========================================
    // ALBUM LAY TIME CUA ANH CUOI
    // ========================================

    final timestampMessage = album.isNotEmpty ? album.last : message;

    // ========================================
    // PHOTO MEDIA ROW
    // ========================================

    return PhotoMediaRow(
      swipeEnabled: true,
      rowKey: isTarget ? targetMessageKey : ValueKey('chat-media-$stableKey'),

      isSelf: isSelf,

      highlighted: isTarget && targetController.highlightTarget,

      senderName: senderName,

      senderAvatar: isSelf
          ? null
          : ChatSenderAvatar(
              senderName: senderName,

              avatarUrl: message['senderAvatar']?.toString(),
            ),

      media: media,

      timeText: formatTime(timestampMessage['timestamp']),

      onReply: () {
        _startReply(message);
      },

      onLongPress: () {
        _showMessageActions(message);
      },
    );
  }

  Widget _buildSimpleMediaRow(
    Map<String, dynamic> message,
    int index,
    Widget media,
  ) {
    final isSelf = message['isSelf'] == true;

    final senderName = message['senderName']?.toString() ?? 'Thành viên';

    final isTarget = index == targetController.targetIndex;

    final stableKey =
        message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        index.toString();

    return SimpleMediaRow(
      swipeEnabled: true,
      rowKey: isTarget ? targetMessageKey : ValueKey('chat-media-$stableKey'),

      isSelf: isSelf,

      highlighted: isTarget && targetController.highlightTarget,

      senderName: senderName,

      senderAvatar: isSelf
          ? null
          : ChatSenderAvatar(
              senderName: senderName,

              avatarUrl: message['senderAvatar']?.toString(),
            ),

      media: media,

      timeText: formatTime(message['timestamp']),

      onReply: () {
        _startReply(message);
      },

      onLongPress: () {
        _showMessageActions(message);
      },
    );
  }

  Future<void> _downloadMessageMedia(Map<String, dynamic> message) async {
    final isPhoto = mediaController.isPhotoMessage(message);

    final isVideo = mediaController.isVideoMessage(message);

    if (!isPhoto && !isVideo) {
      return;
    }

    final url = isPhoto
        ? mediaController.extractPhotoUrl(message)
        : mediaController.messageMediaUrl(message);

    if (url == null || url.isEmpty) {
      _showTopNotice('Không tìm thấy đường dẫn media');

      return;
    }

    _showTopNotice(isPhoto ? 'Đang tải ảnh...' : 'Đang tải video...');

    try {
      await MediaDownloadService.saveFromUrl(
        url: url,

        kind: isPhoto ? MediaDownloadKind.image : MediaDownloadKind.video,
      );

      if (!mounted) {
        return;
      }

      _showTopNotice(
        isPhoto ? 'Đã lưu ảnh vào thư viện' : 'Đã lưu video vào thư viện',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');

      _showTopNotice(message.isEmpty ? 'Tải xuống thất bại' : message);

      debugPrint(
        'MEDIA DOWNLOAD ERROR: '
        '$error',
      );
    }
  }

  // ========================================
  // MESSAGE BUBBLE
  // ========================================

  Widget buildMessage(Map<String, dynamic> message, int index) {
    final isSelf = message['isSelf'] == true;

    final status = message['status']?.toString() ?? 'normal';

    final isPhoto = mediaController.isPhotoMessage(message);

    // ========================================
    // MESSAGE DA XOA KHONG DUOC RENDER
    // ========================================

    if (status == 'deleted_local') {
      return const SizedBox.shrink();
    }

    // ========================================
    // PHOTO / PHOTO ALBUM
    //
    // KHONG CHAY VAO TEXT BUBBLE.
    //
    // 1 PHOTO
    // -> PHOTO DOC LAP.
    //
    // PHOTO ALBUM
    // -> GRID DOC LAP.
    // ========================================

    if (status == 'normal' && mediaController.isPhotoMessage(message)) {
      final mediaGroupId = mediaController.mediaGroupId(message);

      // ========================================
      // ALBUM:
      // CHI RENDER MOT LAN.
      // ========================================

      if (mediaGroupId != null) {
        final renderIndex =
            photoAlbumIndex?.renderIndexFor(
              mediaGroupId,
              targetIndex: targetController.targetIndex,
              messages: messagesController.messages,
              resolveGroupId: mediaController.mediaGroupId,
            ) ??
            -1;

        if (renderIndex != index) {
          return const SizedBox.shrink();
        }
      }

      return _buildPhotoMediaRow(message, index);
    }

    // ========================================
    // STICKER
    // ========================================

    if (status == 'normal' && mediaController.isStickerMessage(message)) {
      return _buildSimpleMediaRow(
        message,

        index,

        _buildStickerMessage(message),
      );
    }

    // ========================================
    // VIDEO
    // ========================================

    if (status == 'normal' && mediaController.isVideoMessage(message)) {
      return _buildSimpleMediaRow(message, index, _buildVideoMessage(message));
    }

    // ========================================
    // FILE
    // ========================================

    if (status == 'normal' && mediaController.isFileMessage(message)) {
      return _buildSimpleMediaRow(message, index, _buildFileMessage(message));
    }

    // ========================================
    // VOICE
    // ========================================

    if (status == 'normal' && mediaController.isVoiceMessage(message)) {
      return _buildSimpleMediaRow(message, index, _buildVoiceMessage(message));
    }

    final senderName = message['senderName']?.toString() ?? 'Thành viên';

    String content;

    if (status == 'recalled') {
      content = 'Tin nhắn đã được thu hồi';
    } else if (isPhoto) {
      content = '[Hình ảnh]';
    } else {
      content =
          message['content']?.toString() ??
          message['preview']?.toString() ??
          '[Tin nhắn]';
    }

    // ========================================
    // TARGET
    // ========================================

    final isTarget = index == targetController.targetIndex;

    final stableMessageId =
        message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        index.toString();

    // ========================================
    // QUOTE CUA ZALO
    //
    // zca-js:
    // fromD = ten nguoi gui tin goc
    // msg   = noi dung tin goc
    // ========================================

    final quote = replyController.extractQuote(message);

    final quoteSender = quote?['fromD']?.toString().trim();

    final quoteMessage = quote?['msg']?.toString().trim();

    VoidCallback? onQuoteTap;

    if (quote != null) {
      final quoteTarget = quote;

      onQuoteTap = () {
        _jumpToQuotedMessage(quoteTarget);
      };
    }

    final bubble = TextMessageBubble(
      isSelf: isSelf,

      isRecalled: status == 'recalled',

      senderName: senderName,

      content: content,

      timeText: formatTime(message['timestamp']),

      hasQuote: quote != null,

      quoteSender: quoteSender,

      quoteMessage: quoteMessage,

      onQuoteTap: onQuoteTap,
    );

    return TextMessageRow(
      rowKey: isTarget
          ? targetMessageKey
          : ValueKey('chat-message-$stableMessageId'),

      isSelf: isSelf,

      highlighted: isTarget && targetController.highlightTarget,

      swipeEnabled: status == 'normal',

      senderAvatar: isSelf
          ? null
          : ChatSenderAvatar(
              senderName: senderName,

              avatarUrl: message['senderAvatar']?.toString(),
            ),

      bubble: bubble,

      onTap: _quickTapAcceptEnabled && !isSelf && status == 'normal'
          ? () => _acceptChatMessage(message)
          : null,

      onReply: () {
        _startReply(message);
      },

      onLongPress: () {
        _showMessageActions(message);
      },
    );
  }

  Widget _buildMessageComposer() {
    final disabled =
        messagesController.loading ||
        targetController.seekingTarget ||
        realtimeAuthFailed;

    // ========================================
    // COMPOSER UI
    // ========================================

    return ChatMessageComposer(
      controller: messageController,

      focusNode: messageFocusNode,

      disabled: disabled,

      sendingMessage: actionsController.sendingMessage,

      sendingPhoto: actionsController.sendingPhoto,

      canSendMessage: canSendMessage,

      hasReply: replyController.hasReply,

      replySender: replyController.composerSender,

      replyContent: replyController.composerContent,

      onCancelReply: _cancelReply,

      onPickPhoto: _pickAndSendPhoto,

      onSend: _sendChatMessage,
    );
  }

  @override
  void dispose() {
    ChatStateService.instance.closeGroup(widget.groupId);

    markReadController.dispose();

    messagesController.dispose();

    actionsController.dispose();

    targetController.dispose();

    topNoticeTimer?.cancel();

    realtimeController.dispose();

    messageController.removeListener(_handleComposerChanged);

    messageController.dispose();

    voiceController.dispose();

    messageFocusNode.dispose();

    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    photoAlbumIndex = mediaController.buildPhotoAlbumIndex(
      messagesController.messages,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: ChatAppBar(
        groupName: widget.groupName,

        groupAvatar: widget.groupAvatar,
      ),

      body: Column(
        children: [
          if (!realtimeConnected)
            Material(
              color: realtimeAuthFailed
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (!realtimeAuthFailed)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          realtimeAuthFailed
                              ? 'Phiên realtime không hợp lệ. Vui lòng đăng nhập lại.'
                              : 'Đang kết nối lại realtime...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ========================================
          // KHU VUC NOI DUNG CHAT
          // ========================================

          Expanded(
            child: initialLoadError != null &&
                    !messagesController.loading &&
                    messagesController.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 56),
                          const SizedBox(height: 14),
                          const Text(
                            'Không thể tải hội thoại',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            initialLoadError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: loadMessages,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
              children: [
                Positioned.fill(
                  child: ChatBackground(
                    child: ChatMessageList(
                      loading: messagesController.loading,

                      messages: messagesController.messages,

                      scrollController: scrollController,

                      messageBuilder: buildMessage,

                      onScrollNotification: _handleScrollNotification,
                    ),
                  ),
                ),

                // ========================================
                // CO TIN NHAN MOI TRONG KHI
                // USER DANG XEM HISTORY.
                // ========================================
                if (showNewMessageButton)
                  Positioned(
                    right: 16,
                    bottom: 16,

                    child: Material(
                      elevation: 5,

                      color: Theme.of(context).colorScheme.surfaceContainerHigh,

                      shape: const CircleBorder(),

                      child: IconButton(
                        tooltip: 'Xuống tin nhắn mới nhất',

                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,

                          size: 30,

                          color: Theme.of(context).colorScheme.primary,
                        ),

                        onPressed: _jumpToLatestMessages,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ========================================
          // O NHAP TIN NHAN
          //
          // LUON NAM CO DINH DUOI MAN HINH.F
          // ========================================
          _buildMessageComposer(),
        ],
      ),
    );
  }
}
