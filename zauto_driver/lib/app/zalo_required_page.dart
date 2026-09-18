import 'package:flutter/material.dart';

class ZaloRequiredPage extends StatelessWidget {
  final Future<void> Function() onLinkZalo;

  final String title;

  final String description;

  const ZaloRequiredPage({
    super.key,

    required this.onLinkZalo,

    this.title = 'Vui lòng liên kết Zalo với ZAUTO',

    this.description =
        'Cho phép ZAUTO đọc và tổng hợp tin nhắn từ các nhóm Zalo bạn đã chọn.',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ========================================
          // WARNING
          // ========================================

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),

            child: Text(
              '*Hãy luôn mở ứng dụng để không bỏ lỡ tin nhắn',

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.amber.shade700, fontSize: 13),
            ),
          ),

          // ========================================
          // CENTER CARD
          // ========================================
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: Card(
                  elevation: 1,

                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),

                    child: Padding(
                      padding: const EdgeInsets.all(28),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          CircleAvatar(
                            radius: 32,

                            backgroundColor: colorScheme.primaryContainer,

                            child: Icon(
                              Icons.chat_bubble_outline,

                              size: 32,

                              color: colorScheme.primary,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            title,

                            textAlign: TextAlign.center,

                            style: const TextStyle(
                              fontSize: 20,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            description,

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 15,

                              color: colorScheme.onSurfaceVariant,

                              height: 1.45,
                            ),
                          ),

                          const SizedBox(height: 26),

                          SizedBox(
                            width: double.infinity,

                            height: 54,

                            child: FilledButton.icon(
                              onPressed: () async {
                                await onLinkZalo();
                              },

                              icon: const Icon(Icons.link),

                              label: const Text(
                                'LIÊN KẾT NGAY',

                                style: TextStyle(
                                  fontSize: 16,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
