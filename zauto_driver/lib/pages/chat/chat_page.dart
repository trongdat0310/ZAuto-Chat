import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../config/app_config.dart';

import '../../services/backend_service.dart';
import '../../services/chat_state_service.dart';

import 'chat_date_separator.dart';
import 'chat_sender_avatar.dart';
import 'chat_message_composer.dart';
import 'chat_app_bar.dart';
import 'chat_message_list.dart';
import 'chat_background.dart';
import 'voice_message_bubble.dart';
import 'file_message_bubble.dart';
import 'sticker_message_bubble.dart';
import 'simple_media_row.dart';
import 'video_viewer_page.dart';
import 'video_message_bubble.dart';
import 'photo_viewer_page.dart';
import 'photo_message_bubble.dart';
import 'photo_media_row.dart';
import 'text_message_bubble.dart';
import 'text_message_row.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;

  // Dung cho Lich su nhan sau nay.
  final String? targetMsgId;
  final String? targetCliMsgId;

  const ChatPage({
    super.key,

    required this.groupId,
    required this.groupName,
    required this.groupAvatar,

    this.targetMsgId,
    this.targetCliMsgId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  // ========================================
  // VOICE PLAYER
  // ========================================

  final AudioPlayer voicePlayer = AudioPlayer();

  String? playingVoiceUrl;

  Duration voicePosition = Duration.zero;

  Duration voiceDuration = Duration.zero;

  final ScrollController scrollController = ScrollController();

  final TextEditingController messageController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  bool sendingPhoto = false;

  final FocusNode messageFocusNode = FocusNode();

  bool sendingMessage = false;

  String? undoingMessageKey;

  String? deletingMessageKey;

  bool canSendMessage = false;

  // ========================================
  // MESSAGE DANG DUOC REPLY
  // ========================================

  Map<String, dynamic>? replyingToMessage;

  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;

  // ========================================
  // MARK READ
  // ========================================

  Timer? markReadTimer;

  bool markReadInFlight = false;

  bool markReadPending = false;

  // Chỉ đánh dấu đã đọc khi app
  // thực sự đang foreground.
  bool appIsActive = true;

  Timer? realtimeReloadTimer;

  Timer? targetHighlightTimer;

  Timer? topNoticeTimer;

  int? targetIndex;

  String? targetErrorReason;

  bool highlightTarget = false;

  bool targetNoticeShown = false;

  bool isSameMessage(Map<String, dynamic> a, Map<String, dynamic> b) {
    const keys = ['msgId', 'cliMsgId', 'id'];

    for (final key in keys) {
      final aValue = a[key]?.toString();

      final bValue = b[key]?.toString();

      if (aValue != null &&
          aValue.isNotEmpty &&
          bValue != null &&
          bValue.isNotEmpty &&
          aValue == bValue) {
        return true;
      }
    }
    return false;
  }

  String _messageActionKey(Map<String, dynamic> message) {
    return message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        '';
  }

  void _removeMessageFromUi(Map<String, dynamic> message) {
    if (!mounted) {
      return;
    }

    final removeIndex = messages.indexWhere(
      (item) => isSameMessage(item, message),
    );

    if (removeIndex < 0) {
      return;
    }

    setState(() {
      // ========================================
      // XOA HAN MESSAGE KHOI DANH SACH
      // ========================================

      messages.removeAt(removeIndex);

      // ========================================
      // SUA TARGET INDEX NEU MESSAGE BI XOA
      // NAM TRUOC / DUNG TARGET
      // ========================================

      if (targetIndex != null) {
        if (targetIndex == removeIndex) {
          targetIndex = null;

          highlightTarget = false;
        } else if (removeIndex < targetIndex!) {
          targetIndex = targetIndex! - 1;
        }
      }

      // ========================================
      // NEU DANG REPLY MESSAGE VUA XOA
      // THI HUY REPLY
      // ========================================

      if (replyingToMessage != null &&
          isSameMessage(replyingToMessage!, message)) {
        replyingToMessage = null;
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

  int _findMessageIndexByIds({String? msgId, String? cliMsgId}) {
    final safeMsgId = msgId?.trim() ?? '';

    final safeCliMsgId = cliMsgId?.trim() ?? '';

    return messages.indexWhere((message) {
      final messageMsgId = message['msgId']?.toString().trim() ?? '';

      final messageCliMsgId = message['cliMsgId']?.toString().trim() ?? '';

      final sameMsgId =
          safeMsgId.isNotEmpty &&
          messageMsgId.isNotEmpty &&
          safeMsgId == messageMsgId;

      final sameCliMsgId =
          safeCliMsgId.isNotEmpty &&
          messageCliMsgId.isNotEmpty &&
          safeCliMsgId == messageCliMsgId;

      return sameMsgId || sameCliMsgId;
    });
  }

  final GlobalKey targetMessageKey = GlobalKey();

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  List<Map<String, dynamic>> messages = [];

  bool loading = true;

  static const int pageSize = 50;

  bool loadingOlder = false;

  bool hasMoreOlder = false;

  bool hasMoreNewer = false;

  // Khong cho pagination chay
  // truoc khi scroll target / scroll bottom
  // lan dau hoan tat.
  bool paginationReady = false;

  // ========================================
  // DANG TU DONG TIM TARGET TU TIN MOI NHAT
  // ========================================

  bool seekingTarget = false;

  // Moi lan tim target load 30 tin cu.
  static const int targetSeekPageSize = 30;

  @override
  void initState() {
    super.initState();

    ChatStateService.instance.openGroup(widget.groupId);

    _setupVoicePlayer();

    WidgetsBinding.instance.addObserver(this);

    final lifecycleState = WidgetsBinding.instance.lifecycleState;

    appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

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
    final status = message['status']?.toString() ?? 'normal';

    // ========================================
    // KHONG REPLY TIN DA THU HOI / XOA
    // ========================================

    if (status != 'normal') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tin nhắn này không còn có thể trả lời.')),
      );

      return;
    }

    final msgId = message['msgId']?.toString();

    final cliMsgId = message['cliMsgId']?.toString();

    if ((msgId == null || msgId.isEmpty) &&
        (cliMsgId == null || cliMsgId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn này chưa có ID Zalo để trả lời.'),
        ),
      );

      return;
    }

    setState(() {
      replyingToMessage = Map<String, dynamic>.from(message);
    });

    messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    if (replyingToMessage == null) {
      return;
    }

    setState(() {
      replyingToMessage = null;
    });
  }

  void _setupVoicePlayer() {
    voicePlayer.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }

      setState(() {
        voicePosition = position;
      });
    });

    voicePlayer.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }

      setState(() {
        voiceDuration = duration;
      });
    });

    voicePlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        playingVoiceUrl = null;

        voicePosition = Duration.zero;
      });
    });
  }

  Future<void> _toggleVoice(String url) async {
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) {
      return;
    }

    // ========================================
    // DANG PHAT CHINH VOICE NAY
    // ========================================

    if (playingVoiceUrl == trimmedUrl) {
      if (voicePlayer.state == PlayerState.playing) {
        await voicePlayer.pause();
      } else {
        await voicePlayer.resume();
      }

      if (!mounted) {
        return;
      }

      setState(() {});

      return;
    }

    // ========================================
    // CHUYEN SANG VOICE KHAC
    // ========================================

    await voicePlayer.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      playingVoiceUrl = trimmedUrl;

      voicePosition = Duration.zero;

      voiceDuration = Duration.zero;
    });

    await voicePlayer.play(UrlSource(trimmedUrl));
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
    final actionKey = _messageActionKey(message);

    if (actionKey.isEmpty || deletingMessageKey != null) {
      return;
    }

    final msgId = message['msgId']?.toString().trim();

    final cliMsgId = message['cliMsgId']?.toString().trim();

    if ((msgId == null || msgId.isEmpty) &&
        (cliMsgId == null || cliMsgId.isEmpty)) {
      _showTopNotice('Tin nhắn thiếu ID để xóa');

      return;
    }

    setState(() {
      deletingMessageKey = actionKey;
    });

    try {
      await backend.deleteConversationMessage(
        groupId: widget.groupId,

        msgId: msgId,

        cliMsgId: cliMsgId,
      );

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
        setState(() {
          deletingMessageKey = null;
        });
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

    final actionKey = _messageActionKey(message);

    if (actionKey.isEmpty || undoingMessageKey != null) {
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

    setState(() {
      undoingMessageKey = actionKey;
    });

    try {
      await backend.undoConversationMessage(
        groupId: widget.groupId,

        msgId: msgId,

        cliMsgId: cliMsgId,
      );

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
        setState(() {
          undoingMessageKey = null;
        });
      }
    }
  }

  void _showMessageActions(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'normal';

    // ========================================
    // MESSAGE DA XOA LOCAL
    // KHONG CON ACTION NAO NUA
    // ========================================

    if (status == 'deleted_local') {
      return;
    }

    final isSelf = message['isSelf'] == true;

    final msgId = message['msgId']?.toString().trim() ?? '';

    final cliMsgId = message['cliMsgId']?.toString().trim() ?? '';

    final messageContent = message['content']?.toString() ?? '';

    // ========================================
    // QUYEN CUA TUNG ACTION
    // ========================================

    final canReply = status == 'normal';

    final canCopy = status == 'normal' && messageContent.trim().isNotEmpty;

    final canUndo =
        isSelf && status == 'normal' && msgId.isNotEmpty && cliMsgId.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // ========================================
              // TRA LOI
              // ========================================

              if (canReply)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),

                  title: const Text('Trả lời'),

                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _startReply(message);
                  },
                ),

              // ========================================
              // SAO CHEP
              // ========================================
              if (canCopy)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),

                  title: const Text('Sao chép'),

                  onTap: () async {
                    Navigator.of(sheetContext).pop();

                    await Clipboard.setData(
                      ClipboardData(text: messageContent),
                    );

                    if (!mounted) {
                      return;
                    }

                    _showTopNotice('Đã sao chép tin nhắn');
                  },
                ),

              // ========================================
              // THU HOI
              //
              // CHI TIN CUA CHINH MINH.
              //
              // KHONG KIEM TRA 1 GIO O DAY
              // VI TA VAN MUON HIEN NUT THU HOI.
              //
              // _confirmUndoMessage SE THONG BAO
              // NEU DA QUA 1 GIO.
              // ========================================
              if (canUndo)
                ListTile(
                  leading: Icon(
                    Icons.undo_rounded,

                    color: Theme.of(context).colorScheme.error,
                  ),

                  title: Text(
                    'Thu hồi',

                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),

                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _confirmUndoMessage(message);
                  },
                ),

              // ========================================
              // XOA LOCAL
              //
              // CO CHO CA TIN CUA MINH
              // VA TIN CUA NGUOI KHAC.
              //
              // TIN RECALLED CUNG CO THE XOA.
              // ========================================
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,

                  color: Theme.of(context).colorScheme.error,
                ),

                title: Text(
                  'Xóa',

                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),

                onTap: () {
                  Navigator.of(sheetContext).pop();

                  _confirmDeleteMessage(message);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
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
    if (sendingPhoto || sendingMessage || loading || seekingTarget) {
      return;
    }

    if (replyingToMessage != null) {
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

    setState(() {
      sendingPhoto = true;
    });

    try {
      await backend.sendConversationPhotos(
        groupId: widget.groupId,

        filePaths: pickedPhotos.map((photo) => photo.path).toList(),
      );

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

      scheduleRealtimeReload(force: true);

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) {
          return;
        }

        scheduleRealtimeReload(force: true);
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
        setState(() {
          sendingPhoto = false;
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    if (sendingMessage) {
      return;
    }

    final text = messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    // ========================================
    // REPLY TARGET
    // ========================================

    final replyMessage = replyingToMessage;

    final replyMsgId = replyMessage?['msgId']?.toString();

    final replyCliMsgId = replyMessage?['cliMsgId']?.toString();

    // ========================================
    // KHOA NUT SEND
    // ========================================

    setState(() {
      sendingMessage = true;
    });

    try {
      await backend.sendConversationMessage(
        groupId: widget.groupId,

        text: text,

        replyToMsgId: replyMsgId,

        replyToCliMsgId: replyCliMsgId,
      );

      if (!mounted) {
        return;
      }

      messageController.clear();

      setState(() {
        replyingToMessage = null;

        targetIndex = null;

        highlightTarget = false;
      });

      messageFocusNode.requestFocus();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTopNotice('Gửi tin nhắn thất bại');

      debugPrint('SEND MESSAGE ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {
          sendingMessage = false;
        });
      }
    }
  }

  // ========================================
  // SCHEDULE MARK READ
  //
  // Debounce de album 4 anh hoac nhieu
  // message lien tuc khong tao 4-10 request.
  // ========================================

  void _scheduleMarkConversationRead({bool immediate = false}) {
    if (!mounted || !appIsActive) {
      return;
    }

    markReadTimer?.cancel();

    if (immediate) {
      unawaited(_markConversationReadNow());

      return;
    }

    markReadTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !appIsActive) {
        return;
      }

      unawaited(_markConversationReadNow());
    });
  }

  // ========================================
  // MARK READ NOW
  // ========================================

  Future<void> _markConversationReadNow() async {
    if (!mounted || !appIsActive) {
      return;
    }

    // ========================================
    // Neu request truoc van dang chay,
    // ghi nho rang can chay them 1 lan.
    // ========================================

    if (markReadInFlight) {
      markReadPending = true;

      return;
    }

    markReadInFlight = true;

    try {
      await backend.markConversationRead(groupId: widget.groupId);

      debugPrint('CHAT MARK READ: ${widget.groupId}');
    } catch (error) {
      // Mark read loi KHONG DUOC
      // lam hong ChatPage.
      debugPrint('CHAT MARK READ ERROR: $error');
    } finally {
      markReadInFlight = false;

      // ========================================
      // Trong luc request dang chay
      // co message moi den.
      //
      // Chay them mot lan nua.
      // ========================================

      if (markReadPending) {
        markReadPending = false;

        _scheduleMarkConversationRead();
      }
    }
  }

  Future<void> _openVideo(Map<String, dynamic> message) async {
    final url = _messageMediaUrl(message);

    debugPrint(
      'OPEN VIDEO CALLED: '
      'mediaUrl=$url',
    );

    if (url == null || url.isEmpty) {
      _showTopNotice('Video không có đường dẫn');

      debugPrint('OPEN VIDEO ABORT: EMPTY URL');

      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) {
      _showTopNotice('Đường dẫn video không hợp lệ');

      debugPrint('OPEN VIDEO ABORT: INVALID URL');

      return;
    }

    try {
      debugPrint('OPEN VIDEO NAVIGATING...');

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
    final rawUrl = _messageMediaUrl(message);

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

  // ========================================
  // APP LIFECYCLE
  // ========================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = appIsActive;

    appIsActive = state == AppLifecycleState.resumed;

    // ========================================
    // APP RA BACKGROUND
    //
    // Khong duoc tu coi message la da doc.
    // ========================================

    if (!appIsActive) {
      markReadTimer?.cancel();

      return;
    }

    // ========================================
    // USER QUAY LAI APP
    //
    // Neu ChatPage nay van dang mo,
    // coi conversation hien tai la da doc.
    // ========================================

    if (!wasActive && mounted) {
      _scheduleMarkConversationRead(immediate: true);
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

    startRealtime();

    // ========================================
    // 3. USER DA MO CONVERSATION
    // -> DANH DA DOC.
    // ========================================

    _scheduleMarkConversationRead(immediate: true);
  }

  bool get hasTarget {
    return (widget.targetMsgId != null && widget.targetMsgId!.isNotEmpty) ||
        (widget.targetCliMsgId != null && widget.targetCliMsgId!.isNotEmpty);
  }

  int _findTargetIndex() {
    final safeTargetMsgId = widget.targetMsgId?.trim() ?? '';

    final safeTargetCliMsgId = widget.targetCliMsgId?.trim() ?? '';

    // ========================================
    // QUAN TRONG:
    //
    // Neu co targetMsgId,
    // CHI tim bang msgId.
    //
    // KHONG duoc de cliMsgId cua message khac
    // ghi de ket qua.
    // ========================================

    if (safeTargetMsgId.isNotEmpty) {
      return messages.indexWhere((message) {
        final messageMsgId = message['msgId']?.toString().trim() ?? '';

        return messageMsgId.isNotEmpty && messageMsgId == safeTargetMsgId;
      });
    }

    // ========================================
    // CHI KHI KHONG CO msgId
    // MOI FALLBACK SANG cliMsgId.
    // ========================================

    if (safeTargetCliMsgId.isNotEmpty) {
      return messages.indexWhere((message) {
        final messageCliMsgId = message['cliMsgId']?.toString().trim() ?? '';

        return messageCliMsgId.isNotEmpty &&
            messageCliMsgId == safeTargetCliMsgId;
      });
    }

    return -1;
  }

  Future<void> loadMessages() async {
    paginationReady = false;

    seekingTarget = false;

    if (mounted) {
      setState(() {
        loading = true;

        targetIndex = null;

        highlightTarget = false;
      });
    }

    try {
      // ========================================
      // LUON BAT DAU TU TIN MOI NHAT
      //
      // CA CHAT BINH THUONG
      // VA MO TU LICH SU NHAN
      // DEU GIONG NHAU.
      // ========================================

      final page = await backend.getConversationMessagesPage(
        groupId: widget.groupId,

        limit: pageSize,
      );

      if (!mounted) {
        return;
      }

      final loadedMessages = _extractMessages(page['messages']);

      setState(() {
        messages = loadedMessages;

        hasMoreOlder = page['hasBefore'] == true;

        // ========================================
        // TA BAT DAU TU LATEST.
        //
        // VI VAY KHONG BAO GIO CAN
        // PAGINATION NEWER.
        // ========================================

        hasMoreNewer = false;

        targetErrorReason = null;

        loading = false;
      });

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

      if (hasTarget) {
        await _seekTargetFromLatest();

        return;
      }

      // ========================================
      // CHAT BINH THUONG
      // ========================================

      paginationReady = true;

      Future.microtask(() => _ensureHistoryScrollable());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;

        seekingTarget = false;
      });

      paginationReady = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải hội thoại: $error')),
      );
    }
  }

  Future<void> _seekTargetFromLatest() async {
    if (seekingTarget || !hasTarget) {
      return;
    }

    seekingTarget = true;

    paginationReady = false;

    try {
      while (mounted) {
        // ========================================
        // TARGET DA NAM TRONG SO MESSAGE
        // DA LOAD CHUA?
        // ========================================

        final foundIndex = _findTargetIndex();

        if (foundIndex >= 0) {
          setState(() {
            targetIndex = foundIndex;

            targetErrorReason = null;
          });

          final centered = await _centerTargetMessage();

          if (!mounted) {
            return;
          }

          if (!centered) {
            debugPrint(
              'TARGET FOUND BUT CENTER FAILED: '
              'index=$foundIndex',
            );

            return;
          }

          setState(() {
            highlightTarget = true;
          });

          _removeTargetHighlightLater();

          return;
        }

        // ========================================
        // KHONG CON TIN CU DE TIM
        // ========================================

        if (!hasMoreOlder) {
          targetErrorReason = 'not_found';

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTargetNotFound();
          });

          return;
        }

        final beforeId = messages.first['id']?.toString();

        if (beforeId == null || beforeId.isEmpty) {
          targetErrorReason = 'not_found';

          _showTargetNotFound();

          return;
        }

        // ========================================
        // LOAD THEM MOT PAGE TIN CU
        // ========================================

        final page = await backend.getConversationMessagesPage(
          groupId: widget.groupId,

          limit: targetSeekPageSize,

          beforeId: beforeId,
        );

        if (!mounted) {
          return;
        }

        final older = _extractMessages(page['messages']);

        final uniqueOlder = older.where((incoming) {
          return !messages.any((existing) => isSameMessage(existing, incoming));
        }).toList();

        if (uniqueOlder.isEmpty) {
          hasMoreOlder = false;

          continue;
        }

        setState(() {
          messages = [...uniqueOlder, ...messages];

          hasMoreOlder = page['hasBefore'] == true;
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

        final foundAfterLoad = _findTargetIndex();

        if (foundAfterLoad >= 0) {
          setState(() {
            targetIndex = foundAfterLoad;

            targetErrorReason = null;
          });

          final centered = await _centerTargetMessage();

          if (!mounted) {
            return;
          }

          if (!centered) {
            debugPrint(
              'TARGET FOUND AFTER LOAD '
              'BUT CENTER FAILED: '
              'index=$foundAfterLoad',
            );

            return;
          }

          setState(() {
            highlightTarget = true;
          });

          _removeTargetHighlightLater();

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
      seekingTarget = false;

      if (mounted) {
        paginationReady = true;
      }
    }
  }

  Future<void> _jumpToQuotedMessage(Map<String, dynamic> quote) async {
    if (seekingTarget) {
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

    targetHighlightTimer?.cancel();

    setState(() {
      seekingTarget = true;

      targetIndex = null;

      highlightTarget = false;
    });

    paginationReady = false;

    try {
      while (mounted) {
        // ========================================
        // 1. TARGET DA DUOC LOAD CHUA?
        // ========================================

        final foundIndex = _findMessageIndexByIds(
          msgId: quoteMsgId,

          cliMsgId: quoteCliMsgId,
        );

        if (foundIndex >= 0) {
          setState(() {
            targetIndex = foundIndex;
          });

          // ========================================
          // DUA TIN GOC VAO GIUA MAN HINH
          // ========================================

          final centered = await _centerTargetMessage();

          if (!mounted) {
            return;
          }

          if (!centered) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã tìm thấy tin nhắn nhưng không thể cuộn tới vị trí đó.',
                ),
              ),
            );

            return;
          }

          // ========================================
          // HIGHLIGHT SAU KHI DA CENTER
          // ========================================

          setState(() {
            highlightTarget = true;
          });

          _removeTargetHighlightLater();

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

        if (!hasMoreOlder || messages.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không tìm thấy tin nhắn gốc trong lịch sử.'),
              ),
            );
          }

          return;
        }

        // ========================================
        // 3. LOAD THEM MESSAGE CU HON
        // ========================================

        final beforeId = messages.first['id']?.toString();

        if (beforeId == null || beforeId.isEmpty) {
          return;
        }

        final page = await backend.getConversationMessagesPage(
          groupId: widget.groupId,

          limit: targetSeekPageSize,

          beforeId: beforeId,
        );

        if (!mounted) {
          return;
        }

        final older = _extractMessages(page['messages']);

        final uniqueOlder = older.where((incoming) {
          return !messages.any((existing) => isSameMessage(existing, incoming));
        }).toList();

        // ========================================
        // BACKEND KHONG TRA THEM DU LIEU
        // ========================================

        if (uniqueOlder.isEmpty) {
          hasMoreOlder = false;

          continue;
        }

        setState(() {
          messages = [...uniqueOlder, ...messages];

          hasMoreOlder = page['hasBefore'] == true;
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
      seekingTarget = false;

      if (mounted) {
        paginationReady = true;
      }
    }
  }

  Future<bool> _centerTargetMessage() async {
    if (targetIndex == null) {
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
      'index=$targetIndex '
      'messages=${messages.length} '
      'pixels=${scrollController.position.pixels} '
      'max=${scrollController.position.maxScrollExtent}',
    );

    return false;
  }

  Future<void> loadOlderMessages() async {
    if (!paginationReady || loadingOlder || !hasMoreOlder || messages.isEmpty) {
      return;
    }

    final beforeId = messages.first['id']?.toString();

    if (beforeId == null || beforeId.isEmpty) {
      return;
    }

    loadingOlder = true;

    // ========================================
    // KHOA PAGINATION TRONG LUC LOAD
    // ========================================

    paginationReady = false;

    try {
      final page = await backend.getConversationMessagesPage(
        groupId: widget.groupId,

        limit: pageSize,

        beforeId: beforeId,
      );

      if (!mounted) {
        return;
      }

      final older = _extractMessages(page['messages']);

      debugPrint(
        'TARGET SEEK PAGE: '
        'older=${older.length} '
        'hasBefore=${page['hasBefore']} '
        'currentTotal=${messages.length} '
        'targetMsgId=${widget.targetMsgId} '
        'targetCliMsgId=${widget.targetCliMsgId}',
      );

      // ========================================
      // CHONG TRUNG MESSAGE
      // ========================================

      final uniqueOlder = older.where((incoming) {
        return !messages.any((existing) => isSameMessage(existing, incoming));
      }).toList();

      setState(() {
        if (uniqueOlder.isNotEmpty) {
          // ========================================
          // VAN GIU MESSAGES THEO THU TU:
          //
          // CU NHAT
          // ...
          // MOI NHAT
          // ========================================

          messages = [...uniqueOlder, ...messages];

          // ========================================
          // TARGET INDEX TRONG MANG BI DICH
          // ========================================

          if (targetIndex != null) {
            targetIndex = targetIndex! + uniqueOlder.length;
          }
        }

        hasMoreOlder = page['hasBefore'] == true;
      });

      // ========================================
      // QUAN TRONG:
      //
      // KHONG CON:
      // oldOffset
      // oldMaxExtent
      // newMaxExtent
      // addedExtent
      // jumpTo(...)
      //
      // reverse ListView SE TU GIU VI TRI
      // ========================================
    } catch (error) {
      debugPrint('LOAD OLDER MESSAGES ERROR: $error');
    } finally {
      loadingOlder = false;

      if (mounted) {
        paginationReady = true;
      }
    }
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.minScrollExtent,

      duration: const Duration(milliseconds: 350),

      curve: Curves.easeOut,
    );
  }

  void _removeTargetHighlightLater() {
    // Neu user bam mot quote khac
    // trong luc target cu dang highlight,
    // huy timer cu.
    targetHighlightTimer?.cancel();

    targetHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() {
        highlightTarget = false;
      });
    });
  }

  void _showTargetNotFound() {
    if (!mounted || targetNoticeShown) {
      return;
    }

    targetNoticeShown = true;

    String description;

    switch (targetErrorReason) {
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

  void startRealtime() {
    realtimeSubscription?.cancel();

    realtimeSubscription = backend.connectRealtime().listen(
      (event) {
        if (!mounted) {
          return;
        }

        final type = event['type']?.toString();

        // ========================================
        // BACKEND VUA YEU CAU AUTH
        // ========================================

        if (type == 'auth_required') {
          return;
        }

        // ========================================
        // WEBSOCKET VUA KET NOI / KET NOI LAI
        //
        // CUC KY QUAN TRONG:
        //
        // Co the backend da sync old_messages
        // TRUOC KHI Flutter WebSocket ket noi lai.
        //
        // Vi vay moi lan authenticated,
        // ChatPage phai hoi backend lay latest.
        //
        // Nhu vay khong phu thuoc vao viec
        // co nhan duoc conversation_history_synced
        // hay khong.
        // ========================================

        if (type == 'authenticated') {
          debugPrint(
            'CHAT REALTIME AUTHENTICATED '
            '-> reload latest messages',
          );

          scheduleRealtimeReload(force: true);

          _scheduleMarkConversationRead();

          return;
        }

        // ========================================
        // BACKEND VUA DONG BO TIN NHAN BI LO
        // ========================================

        if (type == 'conversation_history_synced') {
          final rawSyncData = event['data'];

          if (rawSyncData is Map) {
            final syncData = Map<String, dynamic>.from(rawSyncData);

            final syncGroupId = syncData['groupId']?.toString();

            // Chi reload neu history vua sync
            // thuoc group dang mo.
            if (syncGroupId == widget.groupId) {
              debugPrint(
                'CHAT HISTORY SYNCED: '
                'group=$syncGroupId '
                'count=${syncData['count']}',
              );

              scheduleRealtimeReload(force: true);
            }
          }

          _scheduleMarkConversationRead();

          return;
        }

        // ========================================
        // AUTH LOI
        // ========================================

        if (type == 'auth_error') {
          debugPrint('CHAT REALTIME AUTH ERROR');

          return;
        }

        // ========================================
        // MESSAGE REALTIME BINH THUONG
        // ========================================

        if (type != 'conversation_message' &&
            type != 'conversation_message_updated') {
          return;
        }

        final rawData = event['data'];

        if (rawData is! Map) {
          return;
        }

        final data = Map<String, dynamic>.from(rawData);

        final eventGroupId = data['groupId']?.toString();

        // ========================================
        // CHI NHAN MESSAGE CUA GROUP DANG MO
        // ========================================

        if (eventGroupId != widget.groupId) {
          return;
        }

        final rawMessage = data['message'];

        if (rawMessage is! Map) {
          scheduleRealtimeReload();

          return;
        }

        final incoming = Map<String, dynamic>.from(rawMessage);

        upsertRealtimeMessage(incoming);

        // ========================================
        // DANG MO DUNG GROUP NAY
        // + APP DANG FOREGROUND
        // + TIN CUA NGUOI KHAC
        //
        // -> COI LA DA DOC.
        // ========================================

        if (type == 'conversation_message' && incoming['isSelf'] != true) {
          _scheduleMarkConversationRead();
        }
      },

      onError: (error) {
        debugPrint('CHAT REALTIME ERROR: $error');
      },
    );
  }

  Future<void> _ensureHistoryScrollable({int attempt = 0}) async {
    if (!mounted ||
        !paginationReady ||
        loading ||
        loadingOlder ||
        !hasMoreOlder ||
        messages.isEmpty) {
      return;
    }

    // ========================================
    // DOI LISTVIEW BUILD XONG
    // ========================================

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
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
      'messages=${messages.length} '
      'hasMoreOlder=$hasMoreOlder',
    );

    await loadOlderMessages();

    if (!mounted || !hasMoreOlder || attempt >= 10) {
      return;
    }

    // ========================================
    // NEU VAN CHUA DAY MAN HINH
    // LOAD THEM 1 PAGE NUA
    // ========================================

    await _ensureHistoryScrollable(attempt: attempt + 1);
  }

  void scheduleRealtimeReload({bool force = false}) {
    realtimeReloadTimer?.cancel();

    realtimeReloadTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }

      // ========================================
      // DANG XEM HISTORY CU
      //
      // REALTIME BINH THUONG:
      // KHONG DUOC NHAY VE HIEN TAI.
      //
      // NHUNG NEU:
      // - websocket vua reconnect
      // - backend vua sync message bi lo
      //
      // force = true
      // THI PHAI LAY LATEST.
      // ========================================

      if (hasMoreNewer && !force) {
        return;
      }

      try {
        final page = await backend.getConversationMessagesPage(
          groupId: widget.groupId,

          limit: pageSize,
        );

        if (!mounted) {
          return;
        }

        final latest = _extractMessages(page['messages']);

        // ========================================
        // USER CO DANG O GAN CUOI CHAT KHONG?
        //
        // reverse:true
        // minScrollExtent = tin moi nhat.
        // ========================================

        final wasNearBottom =
            !scrollController.hasClients ||
            (scrollController.position.pixels -
                    scrollController.position.minScrollExtent) <
                140;

        setState(() {
          for (final incoming in latest) {
            final existingIndex = messages.indexWhere(
              (existing) => isSameMessage(existing, incoming),
            );

            if (existingIndex >= 0) {
              // ========================================
              // MESSAGE DA CO
              //
              // UPDATE:
              // - recall
              // - thay doi server
              // ========================================

              messages[existingIndex] = incoming;
            } else {
              // ========================================
              // MESSAGE MOI / MESSAGE VUA CATCH UP
              // ========================================

              messages.add(incoming);
            }
          }

          // ========================================
          // SAP XEP:
          // CU NHAT -> MOI NHAT
          // ========================================

          messages.sort((a, b) {
            final aTime = int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;

            final bTime = int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;

            return aTime.compareTo(bTime);
          });

          // Sau khi force lay latest,
          // ta dang co dau moi nhat.
          if (force) {
            hasMoreNewer = false;
          }
        });

        // ========================================
        // NEU USER DANG O CUOI CHAT
        // THI GIU MAN HINH O CUOI.
        //
        // NEU USER DANG DOC TIN CU
        // THI KHONG KEo MAN HINH.
        // ========================================

        if (wasNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            _scrollToBottom();
          });
        }

        debugPrint(
          'CHAT REALTIME RELOAD DONE: '
          'latest=${latest.length} '
          'total=${messages.length} '
          'force=$force',
        );
      } catch (error) {
        debugPrint(
          'CHAT REALTIME RELOAD ERROR: '
          '$error',
        );
      }
    });
  }

  void upsertRealtimeMessage(Map<String, dynamic> incoming) {
    if (!mounted) {
      return;
    }

    final incomingStatus = incoming['status']?.toString() ?? 'normal';

    // ========================================
    // MESSAGE DA XOA
    //
    // BIEN MAT HOAN TOAN KHOI UI.
    // ========================================

    if (incomingStatus == 'deleted_local') {
      _removeMessageFromUi(incoming);

      return;
    }

    // ========================================
    // KHONG CHO EVENT RONG TRO THANH
    // BUBBLE [Tin nhắn]
    // ========================================

    if (!_shouldDisplayMessage(incoming)) {
      debugPrint(
        'CHAT SKIP NON-DISPLAY MESSAGE: '
        'msgId=${incoming['msgId']} '
        'cliMsgId=${incoming['cliMsgId']} '
        'msgType=${incoming['msgType']}',
      );

      return;
    }

    // ========================================
    // USER DANG O GAN CUOI CHAT?
    // ========================================

    final wasNearBottom =
        !scrollController.hasClients ||
        (scrollController.position.pixels -
                scrollController.position.minScrollExtent) <
            140;

    final index = messages.indexWhere((item) => isSameMessage(item, incoming));

    // ========================================
    // DANG XEM MOT DOAN HISTORY CU
    //
    // NEU PHIA SAU VAN CON MESSAGE CHUA LOAD,
    // KHONG APPEND MOT MESSAGE REALTIME MOI VAO
    // GIUA HISTORY.
    // ========================================

    if (index < 0 && hasMoreNewer) {
      return;
    }

    setState(() {
      if (index >= 0) {
        // ========================================
        // UPDATE MESSAGE DA CO
        // ========================================

        messages[index] = incoming;
      } else {
        // ========================================
        // MESSAGE MOI
        // ========================================

        messages.add(incoming);
      }
    });

    // ========================================
    // MESSAGE MOI + USER DANG O CUOI CHAT
    // -> TU DONG CUON THEO
    // ========================================

    if (index < 0 && wasNearBottom && targetIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _scrollToBottom();
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!mounted ||
        !paginationReady ||
        seekingTarget ||
        loading ||
        loadingOlder ||
        messages.isEmpty ||
        !hasMoreOlder) {
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

  bool _shouldDisplayMessage(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'normal';

    if (status == 'deleted_local') {
      return false;
    }

    if (status == 'recalled') {
      return true;
    }

    final content = message['content']?.toString().trim() ?? '';

    if (content.isNotEmpty) {
      return true;
    }

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    const stringAttachmentTypes = <String>{
      'chat.photo',

      'chat.sticker',

      'chat.video',
      'chat.video.msg',

      'share.file',
      'chat.file',
      'chat.file.msg',

      'chat.gif',

      'chat.voice',
      'chat.voice.msg',
      'chat.audio',
    };

    if (stringAttachmentTypes.contains(msgType)) {
      return true;
    }

    final numericType = int.tryParse(msgType);

    const numericAttachmentTypes = <int>{31, 32, 44, 46, 49};

    return numericType != null && numericAttachmentTypes.contains(numericType);
  }

  List<Map<String, dynamic>> _extractMessages(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(_shouldDisplayMessage)
        .toList();
  }

  Future<void> _jumpToBottomInitial({int attempt = 0}) async {
    if (!mounted) {
      return;
    }

    if (!scrollController.hasClients) {
      if (attempt >= 10) {
        debugPrint('JUMP TO LATEST FAILED');

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

  Map<String, dynamic>? _extractQuote(Map<String, dynamic> message) {
    // ========================================
    // 1. rawData LA message.data TU zca-js
    // ========================================

    final raw = message['rawData'];

    if (raw is Map) {
      final rawMap = Map<String, dynamic>.from(raw);

      final quote = rawMap['quote'];

      if (quote is Map) {
        return Map<String, dynamic>.from(quote);
      }
    }

    // ========================================
    // 2. FALLBACK NEU SAU NAY BACKEND
    // DUA quote LEN CAP MESSAGE
    // ========================================

    final directQuote = message['quote'];

    if (directQuote is Map) {
      return Map<String, dynamic>.from(directQuote);
    }

    return null;
  }

  Map<String, dynamic>? _extractPhotoContent(Map<String, dynamic> message) {
    final raw = message['rawData'];

    if (raw is! Map) {
      return null;
    }

    final rawMap = Map<String, dynamic>.from(raw);

    final content = rawMap['content'];

    if (content is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(content);
  }

  String? _extractPhotoUrl(Map<String, dynamic> message) {
    final content = _extractPhotoContent(message);

    if (content == null) {
      return null;
    }

    // ========================================
    // 1. HREF
    //
    // Payload that cua Zalo:
    // content.href = URL anh.
    // ========================================

    final href = content['href']?.toString().trim();

    if (href != null && href.isNotEmpty) {
      return href;
    }

    // ========================================
    // 2. FALLBACK THUMB
    // ========================================

    final thumb = content['thumb']?.toString().trim();

    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }

    return null;
  }

  String _photoHeroTag(Map<String, dynamic> message) {
    final id = message['id']?.toString().trim();

    if (id != null && id.isNotEmpty) {
      return 'chat-photo-$id';
    }

    final msgId = message['msgId']?.toString().trim();

    if (msgId != null && msgId.isNotEmpty) {
      return 'chat-photo-$msgId';
    }

    final cliMsgId = message['cliMsgId']?.toString().trim();

    if (cliMsgId != null && cliMsgId.isNotEmpty) {
      return 'chat-photo-$cliMsgId';
    }

    // ========================================
    // FALLBACK ON DINH TRONG PHIEN APP
    // ========================================

    return 'chat-photo-${identityHashCode(message)}';
  }

  List<Map<String, dynamic>> _allLoadedPhotoMessages() {
    final photos = messages.where((item) {
      // ========================================
      // CHI LAY PHOTO DANG TON TAI
      // ========================================

      final status = item['status']?.toString() ?? 'normal';

      if (status != 'normal') {
        return false;
      }

      if (!_isPhotoMessage(item)) {
        return false;
      }

      final url = _extractPhotoUrl(item);

      return url != null && url.isNotEmpty;
    }).toList();

    // ========================================
    // SAP XEP THEO THOI GIAN CHAT
    //
    // CU -> MOI
    //
    // KHONG QUAN TAM:
    // - album nao
    // - mediaGroupId nao
    // ========================================

    photos.sort((a, b) {
      final aTime = int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;

      final bTime = int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;

      // ========================================
      // NEU CUNG TIMESTAMP
      // THI DUNG THU TU TRONG ALBUM
      // DE ANH KHONG BI DAO LON.
      // ========================================

      if (aTime == bTime) {
        final aGroupIndex = _mediaGroupIndex(a) ?? 0;

        final bGroupIndex = _mediaGroupIndex(b) ?? 0;

        return aGroupIndex.compareTo(bGroupIndex);
      }

      return aTime.compareTo(bTime);
    });

    return photos;
  }

  List<PhotoViewerItem> _buildPhotoViewerItems(
    List<Map<String, dynamic>> sourceMessages,
  ) {
    final result = <PhotoViewerItem>[];

    for (final message in sourceMessages) {
      final photoUrl = _extractPhotoUrl(message);

      if (photoUrl == null || photoUrl.isEmpty) {
        continue;
      }

      result.add(
        PhotoViewerItem(url: photoUrl, heroTag: _photoHeroTag(message)),
      );
    }

    return result;
  }

  Future<PhotoViewerLoadResult> _loadOlderPhotoViewerItems() async {
    // ========================================
    // SO ANH TRUOC KHI LOAD THEM HISTORY
    // ========================================

    final beforePhotos = _allLoadedPhotoMessages();

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

    while (mounted && hasMoreOlder && attempts < 6) {
      attempts += 1;

      await loadOlderMessages();

      if (!mounted) {
        break;
      }

      final currentPhotos = _allLoadedPhotoMessages();

      // ========================================
      // DA TIM THAY IT NHAT MOT ANH CU HON
      // ========================================

      if (currentPhotos.length > beforeCount) {
        return PhotoViewerLoadResult(
          items: _buildPhotoViewerItems(currentPhotos),

          hasMoreOlder: hasMoreOlder,
        );
      }

      // ========================================
      // HET HISTORY
      // ========================================

      if (!hasMoreOlder) {
        break;
      }
    }

    final photos = _allLoadedPhotoMessages();

    return PhotoViewerLoadResult(
      items: _buildPhotoViewerItems(photos),

      hasMoreOlder: hasMoreOlder,
    );
  }

  Future<void> _openPhotoViewer(Map<String, dynamic> message) async {
    // ========================================
    // TAT CA PHOTO HIEN DA LOAD
    //
    // KHONG PHAN BIET ALBUM.
    // ========================================

    final sourceMessages = _allLoadedPhotoMessages();

    final viewerItems = _buildPhotoViewerItems(sourceMessages);

    if (viewerItems.isEmpty) {
      _showTopNotice('Không có ảnh để xem');

      return;
    }

    // ========================================
    // TIM DUNG ANH USER VUA BAM
    // ========================================

    final clickedHeroTag = _photoHeroTag(message);

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
            initialHasMoreOlder: hasMoreOlder,

            onLoadOlder: _loadOlderPhotoViewerItems,
          );
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  bool _isPhotoMessage(Map<String, dynamic> message) {
    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return msgType == 'chat.photo' || msgType == '32';
  }

  bool _isStickerMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'sticker' || msgType == 'chat.sticker';
  }

  bool _isVideoMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'video' ||
        msgType == 'chat.video' ||
        msgType == 'chat.video.msg' ||
        msgType == '44';
  }

  bool _isFileMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'file' ||
        msgType == 'share.file' ||
        msgType == 'chat.file' ||
        msgType == 'chat.file.msg' ||
        msgType == '46';
  }

  String? _messageMediaUrl(Map<String, dynamic> message) {
    final value = message['mediaUrl']?.toString().trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  String? _messageMediaThumbUrl(Map<String, dynamic> message) {
    final value = message['mediaThumbUrl']?.toString().trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Map<String, dynamic> _photoParams(Map<String, dynamic> message) {
    final raw = message['rawData'];

    if (raw is! Map) {
      return {};
    }

    final rawMap = Map<String, dynamic>.from(raw);

    final content = rawMap['content'];

    if (content is! Map) {
      return {};
    }

    final contentMap = Map<String, dynamic>.from(content);

    final params = contentMap['params'];

    if (params is Map) {
      return Map<String, dynamic>.from(params);
    }

    if (params is String && params.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(params);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Ignore malformed params.
      }
    }

    return {};
  }

  String? _mediaGroupId(Map<String, dynamic> message) {
    final direct = message['mediaGroupId']?.toString().trim();

    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final params = _photoParams(message);

    final grouped =
        int.tryParse(
          (params['is_group_layout'] ?? params['isGroupLayout'] ?? 0)
              .toString(),
        ) ==
        1;

    if (!grouped) {
      return null;
    }

    final id = (params['group_layout_id'] ?? params['groupLayoutId'])
        ?.toString()
        .trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  int? _mediaGroupIndex(Map<String, dynamic> message) {
    final direct = int.tryParse(message['mediaGroupIndex']?.toString() ?? '');

    if (direct != null) {
      return direct;
    }

    final params = _photoParams(message);

    return int.tryParse(
      (params['id_in_group'] ?? params['idInGroup'] ?? '').toString(),
    );
  }

  List<Map<String, dynamic>> _albumMessagesFor(Map<String, dynamic> message) {
    final groupId = _mediaGroupId(message);

    if (groupId == null) {
      return [message];
    }

    final result = messages.where((item) {
      if (item['status']?.toString() != 'normal') {
        return false;
      }

      return _isPhotoMessage(item) && _mediaGroupId(item) == groupId;
    }).toList();

    result.sort((a, b) {
      final aIndex = _mediaGroupIndex(a) ?? 999999;

      final bIndex = _mediaGroupIndex(b) ?? 999999;

      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }

      return (int.tryParse(a['timestamp']?.toString() ?? '') ?? 0).compareTo(
        int.tryParse(b['timestamp']?.toString() ?? '') ?? 0,
      );
    });

    return result;
  }

  int _albumRenderIndex(String groupId) {
    // ========================================
    // NEU DANG TARGET MOT PHOTO TRONG ALBUM
    // THI RENDER ALBUM TAI CHINH TARGET DO.
    // ========================================

    final target = targetIndex;

    if (target != null &&
        target >= 0 &&
        target < messages.length &&
        _mediaGroupId(messages[target]) == groupId) {
      return target;
    }

    int bestIndex = -1;

    int bestOrder = 999999;

    for (var index = 0; index < messages.length; index += 1) {
      final item = messages[index];

      if (item['status']?.toString() != 'normal' ||
          !_isPhotoMessage(item) ||
          _mediaGroupId(item) != groupId) {
        continue;
      }

      final order = _mediaGroupIndex(item) ?? 999998;

      if (bestIndex < 0 || order < bestOrder) {
        bestIndex = index;

        bestOrder = order;
      }
    }

    return bestIndex;
  }

  Widget _buildStickerMessage(Map<String, dynamic> message) {
    final stickerUrl = _messageMediaUrl(message);

    return StickerMessageBubble(stickerUrl: stickerUrl);
  }

  Widget _buildVideoMessage(Map<String, dynamic> message) {
    final thumbUrl = _messageMediaThumbUrl(message);

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
    // VOICE NAY CO DANG DUOC CHON KHONG
    // ========================================

    final isCurrentVoice = playingVoiceUrl == url;

    // ========================================
    // DURATION TU MESSAGE
    // ========================================

    final rawDuration = message['mediaDuration'];

    final messageDuration = rawDuration is num
        ? Duration(milliseconds: rawDuration.toInt())
        : Duration.zero;

    // ========================================
    // WAVEFORM
    // ========================================

    final samples = message['waveformSamples'] is List
        ? message['waveformSamples'] as List
        : <dynamic>[];

    // ========================================
    // DURATION THUC TE
    //
    // Neu voice dang phat va AudioPlayer da biet
    // duration -> dung duration cua player.
    // ========================================

    final totalDuration = isCurrentVoice && voiceDuration > Duration.zero
        ? voiceDuration
        : messageDuration;

    // ========================================
    // PROGRESS
    // ========================================

    final progress = isCurrentVoice && totalDuration.inMilliseconds > 0
        ? (voicePosition.inMilliseconds / totalDuration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;

    // ========================================
    // PLAYER CO THUC SU DANG PLAY KHONG
    // ========================================

    final isActuallyPlaying =
        isCurrentVoice && voicePlayer.state == PlayerState.playing;

    // ========================================
    // UI
    // ========================================

    return VoiceMessageBubble(
      samples: samples,

      duration: totalDuration,

      progress: progress,

      isPlaying: isActuallyPlaying,

      onToggle: () {
        _toggleVoice(url);
      },
    );
  }

  Widget _buildPhotoMediaRow(Map<String, dynamic> message, int index) {
    final isSelf = message['isSelf'] == true;

    final senderName = message['senderName']?.toString() ?? 'Thành viên';

    // ========================================
    // ALBUM
    // ========================================

    final mediaGroupId = _mediaGroupId(message);

    final album = mediaGroupId != null ? _albumMessagesFor(message) : [message];

    // ========================================
    // PHOTO UI
    // ========================================

    final media = PhotoMessageBubble(
      album: album,

      resolvePhotoUrl: _extractPhotoUrl,

      resolvePhotoParams: _photoParams,

      resolveHeroTag: _photoHeroTag,

      onOpenPhoto: (selectedMessage) {
        _openPhotoViewer(selectedMessage);
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

    final isTarget = index == targetIndex;

    // ========================================
    // ALBUM LAY TIME CUA ANH CUOI
    // ========================================

    final timestampMessage = album.isNotEmpty ? album.last : message;

    // ========================================
    // PHOTO MEDIA ROW
    // ========================================

    return PhotoMediaRow(
      rowKey: isTarget ? targetMessageKey : ValueKey('chat-media-$stableKey'),

      isSelf: isSelf,

      highlighted: isTarget && highlightTarget,

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

    final isTarget = index == targetIndex;

    final stableKey =
        message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        index.toString();

    return SimpleMediaRow(
      rowKey: isTarget ? targetMessageKey : ValueKey('chat-media-$stableKey'),

      isSelf: isSelf,

      highlighted: isTarget && highlightTarget,

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

  // ========================================
  // MESSAGE BUBBLE
  // ========================================

  Widget buildMessage(Map<String, dynamic> message, int index) {
    final isSelf = message['isSelf'] == true;

    final status = message['status']?.toString() ?? 'normal';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    final isPhoto = msgType == 'chat.photo' || msgType == '32';

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

    if (status == 'normal' && _isPhotoMessage(message)) {
      final mediaGroupId = _mediaGroupId(message);

      // ========================================
      // ALBUM:
      // CHI RENDER MOT LAN.
      // ========================================

      if (mediaGroupId != null) {
        final renderIndex = _albumRenderIndex(mediaGroupId);

        if (renderIndex != index) {
          return const SizedBox.shrink();
        }
      }

      return _buildPhotoMediaRow(message, index);
    }

    // ========================================
    // STICKER
    // ========================================

    if (status == 'normal' && _isStickerMessage(message)) {
      return _buildSimpleMediaRow(
        message,

        index,

        _buildStickerMessage(message),
      );
    }

    // ========================================
    // VIDEO
    // ========================================

    if (status == 'normal' && _isVideoMessage(message)) {
      return _buildSimpleMediaRow(message, index, _buildVideoMessage(message));
    }

    // ========================================
    // FILE
    // ========================================

    if (status == 'normal' && _isFileMessage(message)) {
      return _buildSimpleMediaRow(message, index, _buildFileMessage(message));
    }

    // ========================================
    // VOICE
    // ========================================

    if (status == 'normal' &&
        (message['mediaType']?.toString().trim().toLowerCase() == 'voice' ||
            msgType == 'chat.voice' ||
            msgType == 'chat.voice.msg' ||
            msgType == 'chat.audio' ||
            msgType == '31')) {
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

    final isTarget = index == targetIndex;

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

    final quote = _extractQuote(message);

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

      highlighted: isTarget && highlightTarget,

      swipeEnabled: status == 'normal',

      senderAvatar: isSelf
          ? null
          : ChatSenderAvatar(
              senderName: senderName,

              avatarUrl: message['senderAvatar']?.toString(),
            ),

      bubble: bubble,

      onReply: () {
        _startReply(message);
      },

      onLongPress: () {
        _showMessageActions(message);
      },
    );
  }

  Widget _buildMessageComposer() {
    final disabled = loading || seekingTarget;

    final reply = replyingToMessage;

    String replySender = 'Tin nhắn';

    String replyContent = '';

    // ========================================
    // REPLY DATA
    // ========================================

    if (reply != null) {
      final isSelf = reply['isSelf'] == true;

      replySender = isSelf
          ? 'Bạn'
          : (reply['senderName']?.toString() ?? 'Thành viên');

      replyContent =
          reply['content']?.toString() ??
          reply['preview']?.toString() ??
          '[Tin nhắn]';
    }

    // ========================================
    // COMPOSER UI
    // ========================================

    return ChatMessageComposer(
      controller: messageController,

      focusNode: messageFocusNode,

      disabled: disabled,

      sendingMessage: sendingMessage,

      sendingPhoto: sendingPhoto,

      canSendMessage: canSendMessage,

      hasReply: reply != null,

      replySender: replySender,

      replyContent: replyContent,

      onCancelReply: _cancelReply,

      onPickPhoto: _pickAndSendPhoto,

      onSend: _sendChatMessage,
    );
  }

  @override
  void dispose() {
    ChatStateService.instance.closeGroup();

    WidgetsBinding.instance.removeObserver(this);

    markReadTimer?.cancel();

    realtimeSubscription?.cancel();

    realtimeReloadTimer?.cancel();

    targetHighlightTimer?.cancel();

    topNoticeTimer?.cancel();

    backend.disconnect();

    messageController.removeListener(_handleComposerChanged);

    messageController.dispose();

    messageFocusNode.dispose();

    scrollController.dispose();

    voicePlayer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: ChatAppBar(
        groupName: widget.groupName,

        groupAvatar: widget.groupAvatar,
      ),

      body: Column(
        children: [
          // ========================================
          // KHU VUC NOI DUNG CHAT
          // ========================================

          Expanded(
            child: ChatBackground(
              child: ChatMessageList(
                loading: loading,

                messages: messages,

                scrollController: scrollController,

                messageBuilder: buildMessage,

                onScrollNotification: _handleScrollNotification,
              ),
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
