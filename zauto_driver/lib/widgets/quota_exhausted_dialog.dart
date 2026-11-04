import 'package:flutter/material.dart';

/// Backend quota errors are plain Exceptions in the existing API client.
bool isQuotaExhausted(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('subscription_limit_reached') ||
      message.contains('da het luot') ||
      message.contains('đã hết lượt') ||
      message.contains('hết lượt nhận cuốc') ||
      message.contains('het luot nhan cuoc');
}

Future<void> showQuotaExhaustedDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Đã hết lượt nhận cuốc'),
      content: const Text(
        'Bạn đã sử dụng hết lượt nhận cuốc của tính năng này. '
        'Vui lòng liên hệ quản trị viên để được cấp thêm lượt hoặc đổi gói.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
