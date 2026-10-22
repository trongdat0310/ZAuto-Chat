import 'package:flutter/material.dart';
import '../../services/backend/subscription_api.dart';
import 'subscription_summary.dart';

class SubscriptionCommandDialog extends StatefulWidget {
  final SubscriptionGateway api;
  final Map<String, dynamic> user, subscription;
  final List<Map<String, dynamic>> plans;
  final String action;
  final Map<String, dynamic>? operation;
  final String? outcome;
  const SubscriptionCommandDialog({super.key, required this.api, required this.user,
    required this.subscription, required this.plans, required this.action, this.operation, this.outcome});
  @override
  State<SubscriptionCommandDialog> createState() => _SubscriptionCommandDialogState();
}
class _SubscriptionCommandDialogState extends State<SubscriptionCommandDialog> {
  final note = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String requestId;
  String? selectedPlan;
  int months = 1;
  bool busy = false;
  Map<String, dynamic>? payload;
  String? error;
  bool get addon => widget.action == 'addon';
  bool get selectedAddon => widget.plans.any((p) => p['id'] == selectedPlan && p['addon'] == true);
  bool get choosingPlan => widget.action == 'assign' || addon;
  bool get editable => !busy && payload == null;
  List<Map<String, dynamic>> get choices => widget.plans.where((plan) => addon ? plan['addon'] == true : widget.action == 'assign').toList();
  @override
  void initState() {
    super.initState();
    requestId = newSubscriptionRequestId();
    if (choosingPlan && choices.isNotEmpty) {
      final current = subscriptionMap(widget.subscription['main'])['planId'];
      selectedPlan = choices.any((plan) => plan['id'] == current) ? current.toString() : choices.first['id'].toString();
    }
  }
  @override
  void dispose() { note.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy || !(form.currentState?.validate() ?? false)) return;
    if (choosingPlan && selectedPlan == null) return;
    payload ??= {
      'requestId': requestId, 'expectedRevision': widget.subscription['revision'], 'note': note.text.trim(),
      if (choosingPlan) 'planId': selectedPlan,
      if (!selectedAddon && (choosingPlan || widget.action == 'renew')) 'months': months,
      if (widget.action == 'reconcile') ...{'targetKey': widget.operation?['targetKey'], 'outcome': widget.outcome},
    };
    setState(() { busy = true; error = null; });
    try {
      await widget.api.command(widget.user['id'].toString(), addon ? 'assign' : widget.action, payload!);
      if (!mounted) return;
      setState(() { busy = false; });
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); busy = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    final title = switch (widget.action) {
      'assign' => 'Cấp / đổi gói', 'addon' => 'Thêm lượt hôm nay',
      'renew' => 'Gia hạn gói', 'revoke' => 'Thu hồi gói', _ => 'Đối soát kết quả gửi',
    };
    return PopScope(canPop: !busy, child: AlertDialog(title: Text(title),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: form, child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.user['name']}\n${widget.user['phone']}'),
          const SizedBox(height: 12),
          if (choosingPlan) ...[
            const Text('Chọn gói sử dụng', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedPlan,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: choices.map((plan) => DropdownMenuItem<String>(
                value: plan['id'].toString(),
                child: Text(plan['name'].toString()),
              )).toList(),
              onChanged: editable ? (value) => setState(() { selectedPlan = value; }) : null,
            ),
            const SizedBox(height: 16),
          ],
          if (!selectedAddon && (choosingPlan || widget.action == 'renew')) ...[
            const Text('Số tháng sử dụng', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: months,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [1, 3, 6, 12, 24].map((n) => DropdownMenuItem(value: n, child: Text('$n tháng'))).toList(),
              onChanged: editable ? (value) => setState(() { months = value ?? 1; }) : null,
            ),
            const SizedBox(height: 16),
          ],
          if (choosingPlan && selectedPlan != null) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Thông tin gói được chọn', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text('Gói: ${subscriptionPlanName(selectedPlan, widget.plans)}'),
                  const SizedBox(height: 6),
                  Text(selectedAddon ? 'Thời hạn: Đến 24:00 hôm nay' : 'Thời hạn: $months tháng'),
                  const SizedBox(height: 6),
                  Text(selectedAddon
                    ? 'Giới hạn: Cộng thêm ${widget.plans.firstWhere((p) => p['id'] == selectedPlan)['limit']} lượt/tính năng'
                    : selectedPlan == 'unlimited' ? 'Giới hạn: Không giới hạn'
                    : 'Giới hạn: ${widget.plans.firstWhere((p) => p['id'] == selectedPlan)['limit']} lượt/tính năng'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.action == 'assign' && !selectedAddon) const Text(
            'Gói mới bắt đầu ngay, thay gói chính và có hạn mức mới. Lịch sử nhận cuốc được giữ lại.'),
          if (selectedAddon) const Text('Lượt bổ sung có thể cấp cả khi chưa có gói chính; hết hạn lúc 00:00 ngày kế tiếp theo giờ Việt Nam.'),
          if (widget.action == 'renew') Text(widget.subscription['main'] != null
            ? 'Gia hạn từ ${subscriptionDate(subscriptionMap(widget.subscription['main'])['endsAt'])}. Không reset lượt của chu kỳ hiện tại.'
            : 'Gói đã hết hạn: bắt đầu chu kỳ mới ngay khi xác nhận, không khôi phục gói bổ sung cũ.'),
          if (widget.action == 'revoke') const Text(
            'Thu hồi gói chính và lượt bổ sung. Không xóa lịch sử. Yêu cầu đang gửi không bị hủy.'),
          if (widget.action == 'reconcile') Text(widget.outcome == 'succeeded'
            ? 'Chỉ xác nhận sau khi đã kiểm tra tin được gửi trên Zalo. Lượt giữ sẽ chuyển thành đã dùng.'
            : 'Chỉ xác nhận khi chắc chắn tin chưa được gửi. Lượt giữ sẽ được trả lại.'),
          const SizedBox(height: 12),
          TextFormField(controller: note, enabled: editable, maxLength: 500, minLines: 1, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú / lý do'),
            validator: (value) => widget.action == 'reconcile' && (value?.trim().length ?? 0) < 5
              ? 'Ghi rõ kết quả kiểm tra (ít nhất 5 ký tự).' : null),
          if (busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            const Text('Thử lại sử dụng cùng mã yêu cầu để tránh cấp hai lần. Hủy để tải lại và thay đổi nội dung.'),
          ],
        ],
      )))),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: const Text('Hủy và tải lại')),
        FilledButton(onPressed: busy ? null : submit,
          child: Text(payload == null ? 'Xác nhận' : 'Thử lại cùng yêu cầu')),
      ],
    ));
  }
}
