import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/backend_service.dart';

class PrivateChatPage extends StatefulWidget {
  final String userId;
  final String userName;
  const PrivateChatPage({super.key, required this.userId, required this.userName});

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final backend = BackendService(baseUrl: AppConfig.backendUrl);
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <({String text, bool isSelf, DateTime time})>[];
  bool sending = false;

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await backend.sendPrivateMessage(userId: widget.userId, text: text);
      if (!mounted) return;
      setState(() {
        messages.add((text: text, isSelf: true, time: DateTime.now()));
        input.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được: $error')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.userName)),
      body: Column(children: [
        Expanded(
          child: messages.isEmpty
            ? Center(child: Text('Bắt đầu trò chuyện riêng với ${widget.userName}',
                style: TextStyle(color: colors.onSurfaceVariant)))
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.isSelf ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: message.isSelf ? colors.primaryContainer : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(message.text),
                    ),
                  );
                },
              ),
        ),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            Expanded(child: TextField(
              controller: input, minLines: 1, maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Tin nhắn riêng',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            )),
            IconButton(
              onPressed: sending ? null : send,
              icon: sending ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            ),
          ]),
        )),
      ]),
    );
  }
}
