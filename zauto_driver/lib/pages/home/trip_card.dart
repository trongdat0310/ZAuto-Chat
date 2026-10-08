import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';

class TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;

  final SettingsController settingsController;

  final VoidCallback onAccept;

  final VoidCallback onIgnore;
  final VoidCallback onSwipeReply;
  final VoidCallback onCancelReply;
  final Future<bool> Function(String text) onSendReply;

  const TripCard({
    super.key,

    required this.trip,

    required this.settingsController,

    required this.onAccept,

    required this.onIgnore,
    required this.onSwipeReply,
    required this.onCancelReply,
    required this.onSendReply,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  bool _sending = false;

  @override
  void didUpdateWidget(covariant TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip['_replying'] == true && oldWidget.trip['_replying'] != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.trip['_replying'] == true) _replyFocus.requestFocus();
      });
    }
    if (widget.trip['_replying'] != true && oldWidget.trip['_replying'] == true) {
      _replyController.clear();
      _replyFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final value = _replyController.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    final success = await widget.onSendReply(value);
    if (!mounted) return;
    setState(() => _sending = false);
    if (success) {
      _replyController.clear();
      _replyFocus.unfocus();
    }
  }

  String formatTripCountdown(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;

    final minutes = safeSeconds ~/ 60;

    final remainingSeconds = safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = widget.trip['content']?.toString() ?? 'Cuốc mới';

    final groupName = widget.trip['groupName']?.toString() ?? 'Nhóm Zalo';

    final senderName = widget.trip['senderName']?.toString() ?? 'Không rõ người gửi';

    final status = widget.trip['_uiStatus']?.toString() ?? 'new';

    final remainingSeconds = widget.trip['_remainingSeconds'] is int
        ? widget.trip['_remainingSeconds'] as int
        : widget.settingsController.settings.tripDisplaySeconds;

    final isCountdownWarning = remainingSeconds <= 3;

    final processing = status == 'accepting' || status == 'ignoring';
    final replying = widget.trip['_replying'] == true;

    // ========================================
    // SUCCESS STATUS
    // ========================================

    if (status == 'accepted') {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,

                color: colorScheme.primary,

                size: 30,
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Text(
                  'Đã nhận cuốc',

                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'ignored') {
      return const Card(
        margin: EdgeInsets.only(bottom: 12),

        child: Padding(
          padding: EdgeInsets.all(20),

          child: Row(
            children: [
              Icon(Icons.visibility_off_outlined, size: 28),

              SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Đã bỏ qua cuốc',

                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ========================================
    // NORMAL TRIP CARD
    // ========================================

    final ignoreButton = Expanded(
      child: OutlinedButton.icon(
        onPressed: processing
            ? null
            : () {
                widget.onIgnore();
              },

        icon: status == 'ignoring'
            ? const SizedBox(
                width: 18,
                height: 18,

                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close),

        label: const Text('BỎ QUA'),
      ),
    );

    final acceptButton = Expanded(
      child: FilledButton.icon(
        onPressed: processing
            ? null
            : () {
                widget.onAccept();
              },

        icon: status == 'accepting'
            ? const SizedBox(
                width: 18,
                height: 18,

                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),

        label: const Text('NHẬN'),
      ),
    );

    return GestureDetector(
      onHorizontalDragEnd: widget.settingsController.settings.swipeToReply && !processing && !replying
          ? (details) {
              if ((details.primaryVelocity ?? 0) < -250) widget.onSwipeReply();
            }
          : null,
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.settingsController.settings.quickTapAccept && !processing && !replying ? widget.onAccept : null,
        child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ========================================
            // HEADER
            // ========================================

            Row(
              children: [
                // ========================================
                // CUOC MOI
                // ========================================

                Icon(Icons.local_taxi, color: colorScheme.primary),

                const SizedBox(width: 10),

                const Text(
                  'CUỐC MỚI',

                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const Spacer(),

                // ========================================
                // COUNTDOWN
                // ========================================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    // ========================================
                    // <= 3 GIAY -> MAU CANH BAO
                    // ========================================

                    color: isCountdownWarning
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(
                        isCountdownWarning
                            ? Icons.warning_amber_rounded
                            : Icons.timer_outlined,

                        size: 16,

                        color: isCountdownWarning
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),

                      const SizedBox(width: 5),

                      Text(
                        formatTripCountdown(remainingSeconds),

                        style: TextStyle(
                          fontSize: 14,

                          fontWeight: FontWeight.bold,

                          color: isCountdownWarning
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ========================================
            // CONTENT
            // ========================================
            ValueListenableBuilder<double>(
              valueListenable:
                  widget.settingsController.notificationFontSize,

              builder: (context, fontSize, _) {
                return Text(
                  content,

                  style: TextStyle(
                    fontSize: fontSize,

                    fontWeight: FontWeight.w600,

                    height: 1.25,
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            Text('Nhóm: $groupName'),

            const SizedBox(height: 5),

            Text('Người gửi: $senderName'),

            const SizedBox(height: 20),

            // ========================================
            // BUTTONS
            // ========================================
            if (replying)
              TapRegion(
                onTapOutside: (_) {
                  if (!_sending) widget.onCancelReply();
                },
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        focusNode: _replyFocus,
                        autofocus: true,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendReply(),
                        decoration: const InputDecoration(
                          hintText: 'Trả lời tin nhắn...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Gửi',
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                    ),
                    IconButton(
                      tooltip: 'Hủy trả lời',
                      onPressed: _sending ? null : widget.onCancelReply,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: widget.settingsController.settings.acceptButtonPosition == 'left'
                    ? [acceptButton, const SizedBox(width: 12), ignoreButton]
                    : [ignoreButton, const SizedBox(width: 12), acceptButton],
              ),
          ],
        ),
      ),
      ), // InkWell
      ), // Card
    );
  }
}
