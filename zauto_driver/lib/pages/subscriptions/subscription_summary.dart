import 'package:flutter/material.dart';
import '../../services/backend/subscription_api.dart';

String subscriptionDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '—';
  final vn = date.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(vn.day)}/${two(vn.month)}/${vn.year} ${two(vn.hour)}:${two(vn.minute)} (VN)';
}
String subscriptionPlanName(dynamic id, List<Map<String, dynamic>> plans) {
  for (final plan in plans) {
    if (plan['id'] == id) return plan['name']?.toString() ?? id.toString();
  }
  return id?.toString() ?? 'Chưa có gói';
}
String subscriptionFeatureName(dynamic feature) => switch (feature) {
  'trip_screen_accept' => 'Nhận tại màn hình cuốc',
  'chat_accept' => 'Chạm tin nhắn để nhận',
  'auto_accept' => 'Nhận tự động',
  _ => feature?.toString() ?? '',
};

class SubscriptionSummary extends StatelessWidget {
  final Map<String, dynamic> subscription;
  final List<Map<String, dynamic>> plans;
  const SubscriptionSummary({super.key, required this.subscription, required this.plans});

  @override
  Widget build(BuildContext context) {
    final main = subscriptionMap(subscription['main']);
    final last = subscriptionMap(subscription['lastMain']);
    final features = subscriptionRows(subscription['features']);
    final addons = subscriptionRows(subscription['addons']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(main.isNotEmpty ? subscriptionPlanName(main['planId'], plans)
              : last.isNotEmpty ? 'Gói đã hết hạn' : 'Chưa được cấp gói',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (main.isNotEmpty) ...[
            Text('Bắt đầu: ${subscriptionDate(main['startsAt'])}'),
            Text('Hết hạn: ${subscriptionDate(main['endsAt'])}'),
          ] else if (last.isNotEmpty)
            Text('${subscriptionPlanName(last['planId'], plans)} — ${subscriptionDate(last['endsAt'])}'),
          const SizedBox(height: 8),
          const Text('Hạn mức riêng cho từng kiểu nhận. Mốc ngày theo giờ Việt Nam.'),
        ],
      ))),
      ...features.map((feature) {
        final automatic = feature['feature'] == 'auto_accept';
        final used = (feature['used'] as num?)?.toInt() ?? 0;
        final reserved = (feature['reserved'] as num?)?.toInt() ?? 0;
        final limit = (feature['limit'] as num?)?.toInt();
        final remaining = (feature['remaining'] as num?)?.toInt();
        final buckets = subscriptionRows(feature['buckets']).where((b) => b['addon'] == false).toList();
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subscriptionFeatureName(feature['feature']), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (automatic) const Text('Chưa triển khai — chỉ dự phòng hạn mức.')
            else ...[
              Text('Còn lại: ${remaining == null ? 'Không giới hạn' : '$remaining lượt'}'),
              Text('Đã dùng: $used · Đang giữ: $reserved'),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ((used + reserved) / limit).clamp(0.0, 1.0).toDouble()),
              ],
              if (buckets.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text('Mốc hạn mức: ${subscriptionDate(buckets.first['endsAt'])}')),
              if (reserved > 0) const Text('Lượt đang giữ gồm yêu cầu đang gửi hoặc cần Admin đối soát.'),
            ],
          ],
        )));
      }),
      if (addons.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lượt bổ sung', style: Theme.of(context).textTheme.titleMedium),
          ...addons.map((addon) => Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('${subscriptionPlanName(addon['planId'], plans)}\nHết hạn: ${subscriptionDate(addon['endsAt'])}'))),
        ],
      ))),
    ]);
  }
}
