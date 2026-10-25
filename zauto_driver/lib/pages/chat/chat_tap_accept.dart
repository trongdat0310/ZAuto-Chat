import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/backend/acceptance_api.dart';
import '../../services/settings_service.dart';
import '../../widgets/quota_exhausted_dialog.dart';

typedef SubmitChatAccept = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> message,
  String replyText,
);

/// Only text-message bubbles opt into this scope. Scrolling, long-press, quoted
/// message navigation and media controls retain their existing gestures.
class ChatAcceptScope extends InheritedWidget {
  final VoidCallback? onAccept;
  final bool busy;
  final bool accepted;

  const ChatAcceptScope({
    super.key,
    required super.child,
    required this.onAccept,
    required this.busy,
    required this.accepted,
  });

  static ChatAcceptScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatAcceptScope>();

  @override
  bool updateShouldNotify(ChatAcceptScope oldWidget) =>
      busy != oldWidget.busy ||
      accepted != oldWidget.accepted ||
      onAccept != oldWidget.onAccept;
}

class ChatTapAccept extends StatefulWidget {
  final Map<String, dynamic> message;
  final Widget child;
  // Optional dependencies for widget tests; production uses the authenticated API.
  final SubmitChatAccept? submit;
  final Future<String> Function()? loadReplyText;

  const ChatTapAccept({
    super.key,
    required this.message,
    required this.child,
    this.submit,
    this.loadReplyText,
  });

  @override
  State<ChatTapAccept> createState() => _ChatTapAcceptState();
}

class _ChatTapAcceptState extends State<ChatTapAccept> {
  bool busy = false;
  bool accepted = false;

  bool get available =>
      widget.message['isSelf'] != true &&
      widget.message['status'] == 'normal' &&
      (widget.message['groupId']?.toString().isNotEmpty ?? false) &&
      ((widget.message['msgId']?.toString().isNotEmpty ?? false) ||
          (widget.message['cliMsgId']?.toString().isNotEmpty ?? false));

  Future<void> accept() async {
    if (!available || busy || accepted) return;
    setState(() => busy = true);
    try {
      final replyText = widget.loadReplyText != null
          ? await widget.loadReplyText!()
          : (await SettingsService().load()).acceptReplyText;
      if (!mounted) return;
      final Map<String, dynamic> result;
      if (widget.submit != null) {
        result = await widget.submit!(widget.message, replyText);
      } else {
        final api = AcceptanceApi(
          baseUrl: AppConfig.backendUrl,
          auth: AuthService(),
        );
        result = await api.acceptChatMessage(
          groupId: widget.message['groupId'].toString(),
          msgId: widget.message['msgId']?.toString(),
          cliMsgId: widget.message['cliMsgId']?.toString(),
          replyText: replyText,
        );
      }
      if (!mounted) return;
      setState(() => accepted = true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(result['alreadyAccepted'] == true
            ? 'Cuốc này đã nhận trước đó, không trừ thêm lượt.'
            : 'Đã gửi nội dung nhận cuốc.'),
      ));
    } catch (error) {
      if (!mounted) return;
      if (isQuotaExhausted(error)) {
        await showQuotaExhaustedDialog(context);
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst(RegExp(r'^Exception: '), '')),
        ));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ChatAcceptScope(
        onAccept: available && !busy && !accepted ? () { accept(); } : null,
        busy: busy,
        accepted: accepted,
        child: widget.child,
      );
}
