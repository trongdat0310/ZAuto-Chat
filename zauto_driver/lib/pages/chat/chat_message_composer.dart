import 'package:flutter/material.dart';

class ChatMessageComposer extends StatelessWidget {
  final TextEditingController controller;

  final FocusNode focusNode;

  final bool disabled;

  final bool sendingMessage;

  final bool sendingPhoto;

  final bool canSendMessage;

  // ========================================
  // REPLY
  // ========================================

  final bool hasReply;

  final String replySender;

  final String replyContent;

  // ========================================
  // CALLBACKS
  // ========================================

  final VoidCallback onCancelReply;

  final VoidCallback onPickPhoto;

  final VoidCallback onSend;

  const ChatMessageComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.disabled,
    required this.sendingMessage,
    required this.sendingPhoto,
    required this.canSendMessage,
    required this.hasReply,
    required this.replySender,
    required this.replyContent,
    required this.onCancelReply,
    required this.onPickPhoto,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,

      child: Material(
        color: colorScheme.surface,

        elevation: 6,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // ========================================
              // REPLY PREVIEW
              // ========================================

              if (hasReply) ...[
                Container(
                  width: double.infinity,

                  margin: const EdgeInsets.only(bottom: 6),

                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),

                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 3,

                        height: 38,

                        decoration: BoxDecoration(
                          color: colorScheme.primary,

                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              replySender,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.w700,

                                color: colorScheme.primary,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              replyContent,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                fontSize: 13,

                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Hủy trả lời',

                        visualDensity: VisualDensity.compact,

                        onPressed: onCancelReply,

                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ],

              // ========================================
              // TEXT FIELD + ACTIONS
              // ========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  // ========================================
                  // PHOTO
                  // ========================================

                  SizedBox(
                    width: 42,

                    height: 46,

                    child: IconButton(
                      tooltip: 'Gửi ảnh',

                      onPressed: disabled || sendingMessage || sendingPhoto
                          ? null
                          : onPickPhoto,

                      icon: sendingPhoto
                          ? const SizedBox(
                              width: 20,

                              height: 20,

                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_outlined),
                    ),
                  ),

                  const SizedBox(width: 2),

                  // ========================================
                  // MESSAGE INPUT
                  // ========================================
                  Expanded(
                    child: TextField(
                      controller: controller,

                      focusNode: focusNode,

                      enabled: !disabled,

                      minLines: 1,

                      maxLines: 5,

                      keyboardType: TextInputType.multiline,

                      textCapitalization: TextCapitalization.sentences,

                      decoration: InputDecoration(
                        hintText: disabled
                            ? 'Đang tải hội thoại...'
                            : (hasReply ? 'Trả lời tin nhắn' : 'Tin nhắn'),

                        filled: true,

                        fillColor: colorScheme.surfaceContainerHighest,

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,

                          vertical: 11,
                        ),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),

                          borderSide: BorderSide.none,
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),

                          borderSide: BorderSide(
                            color: colorScheme.primary,

                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ========================================
                  // SEND
                  // ========================================
                  SizedBox(
                    width: 46,

                    height: 46,

                    child: IconButton.filled(
                      onPressed:
                          disabled ||
                              sendingMessage ||
                              sendingPhoto ||
                              !canSendMessage
                          ? null
                          : onSend,

                      icon: sendingMessage
                          ? const SizedBox(
                              width: 20,

                              height: 20,

                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
