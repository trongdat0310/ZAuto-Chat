import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/backend/subscription_api.dart';
import 'subscription_command_dialog.dart';
import 'subscription_summary.dart';

class SubscriptionAdminPage extends StatefulWidget {
  final SubscriptionGateway api;
  final List<Map<String, dynamic>> plans;
  const SubscriptionAdminPage({super.key, required this.api, required this.plans});
  @override
  State<SubscriptionAdminPage> createState() => _SubscriptionAdminPageState();
}
class _SubscriptionAdminPageState extends State<SubscriptionAdminPage> {
  final query = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> users = [];
  bool loading = false, hasMore = false;
  int generation = 0, total = 0;
  String? error;
  @override
  void initState() { super.initState(); load(reset: true); }
  Future<void> load({required bool reset}) async {
    if (!mounted || (!reset && loading)) return;
    final token = ++generation;
    final offset = reset ? 0 : users.length;
    setState(() { loading = true; error = null; if (reset) { users = []; hasMore = false; } });
    try {
      final data = await widget.api.users(query: query.text.trim(), offset: offset);
      if (!mounted || token != generation) return;
      setState(() {
        users = [...users, ...subscriptionRows(data['users'])];
        total = (data['total'] as num?)?.toInt() ?? users.length;
        hasMore = data['hasMore'] == true;
      });
    } catch (e) {
      if (mounted && token == generation) setState(() { error = e.toString(); });
    } finally {
      if (mounted && token == generation) setState(() { loading = false; });
    }
  }
  @override
  void dispose() { debounce?.cancel(); query.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý gói'), actions: [
      IconButton(tooltip: 'Nhật ký quản trị', icon: const Icon(Icons.receipt_long),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SubscriptionAuditPage(api: widget.api)))),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(
        controller: query, decoration: const InputDecoration(
          labelText: 'Số điện thoại hoặc tên tài khoản', prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder()),
        onChanged: (_) {
          // Invalidate the old response immediately, not only after the debounce.
          generation++;
          setState(() { users = []; total = 0; hasMore = false; error = null; });
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 350), () => load(reset: true));
        },
        onSubmitted: (_) { debounce?.cancel(); load(reset: true); },
      )),
      if (loading) const LinearProgressIndicator(),
      Expanded(child: RefreshIndicator(onRefresh: () => load(reset: true), child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          Text('$total tài khoản'),
          ...users.map((user) => Card(child: ListTile(
            title: Text(user['name']?.toString() ?? ''), subtitle: Text(user['phone']?.toString() ?? ''),
            trailing: const Icon(Icons.chevron_right), onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SubscriptionAdminUserPage(
                api: widget.api, user: user, plans: widget.plans)));
              if (mounted) await load(reset: true);
            },
          ))),
          if (!loading && users.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(24), child: Text('Không tìm thấy tài khoản.')),
          if (hasMore) OutlinedButton(onPressed: loading ? null : () => load(reset: false), child: const Text('Tải thêm')),
        ],
      ))),
    ]),
  );
}

class SubscriptionAdminUserPage extends StatefulWidget {
  final SubscriptionGateway api;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> plans;
  const SubscriptionAdminUserPage({super.key, required this.api, required this.user, required this.plans});
  @override
  State<SubscriptionAdminUserPage> createState() => _SubscriptionAdminUserPageState();
}
class _SubscriptionAdminUserPageState extends State<SubscriptionAdminUserPage> {
  Map<String, dynamic>? data;
  bool loading = false;
  String? error;
  String get userId => widget.user['id'].toString();
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    if (!mounted || loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.api.user(userId);
      if (mounted) setState(() { data = result; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); data = null; });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }
  Future<void> act(String action, {Map<String, dynamic>? operation, String? outcome}) async {
    if (loading || data == null) return;
    final succeeded = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => SubscriptionCommandDialog(api: widget.api, user: widget.user, action: action,
        plans: widget.plans, subscription: subscriptionMap(data!['subscription']), operation: operation, outcome: outcome));
    if (!mounted) return;
    await load(); // Also refresh after cancellation of an ambiguous network response.
    if (!mounted) return;
    if (succeeded == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật.')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final sub = subscriptionMap(data?['subscription']);
    final pending = subscriptionRows(data?['pending']);
    return Scaffold(appBar: AppBar(title: Text(widget.user['phone']?.toString() ?? 'Tài khoản'), actions: [
      IconButton(tooltip: 'Làm mới', onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
    ]), body: RefreshIndicator(onRefresh: load, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        Text(widget.user['name']?.toString() ?? '', style: Theme.of(context).textTheme.titleLarge),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        if (data != null) ...[
          SubscriptionSummary(subscription: sub, plans: widget.plans),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: loading ? null : () => act('assign'), child: const Text('Cấp / đổi gói')),
            OutlinedButton(onPressed: loading || sub['lastMain'] == null ? null : () => act('renew'), child: const Text('Gia hạn')),
            OutlinedButton(onPressed: loading ? null : () => act('addon'), child: const Text('Thêm lượt hôm nay')),
            OutlinedButton(onPressed: loading || sub['lastMain'] == null ? null : () => act('revoke'), child: const Text('Thu hồi gói')),
          ]),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Yêu cầu đang giữ lượt', style: Theme.of(context).textTheme.titleMedium),
            ...pending.map((op) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subscriptionFeatureName(op['feature'])),
                Text('${op['status']} · ${subscriptionDate(op['createdAt'])}'),
                SelectableText('ID: ${op['targetKey']}', style: Theme.of(context).textTheme.bodySmall),
                if (op['status'] == 'uncertain') Wrap(spacing: 8, children: [
                  TextButton(onPressed: loading ? null : () => act('reconcile', operation: op, outcome: 'succeeded'),
                    child: const Text('Xác nhận đã gửi')),
                  TextButton(onPressed: loading ? null : () => act('reconcile', operation: op, outcome: 'failed'),
                    child: const Text('Xác nhận chưa gửi')),
                ]) else const Text('Không giải phóng khi yêu cầu đang xử lý.'),
              ],
            )))),
          ],
          const SizedBox(height: 20),
          Text('Nhật ký gần đây', style: Theme.of(context).textTheme.titleMedium),
          ...subscriptionRows(data!['logs']).take(20).map((log) => SubscriptionAuditTile(log: log)),
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => SubscriptionAuditPage(api: widget.api, userId: userId))), child: const Text('Xem nhật ký')),
        ],
      ],
    )));
  }
}

class SubscriptionAuditTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const SubscriptionAuditTile({super.key, required this.log});
  @override
  Widget build(BuildContext context) {
    final action = switch (log['action']) {
      'assign' => 'Cấp / đổi gói', 'renew' => 'Gia hạn',
      'revoke' => 'Thu hồi', 'reconcile' => 'Đối soát', _ => '${log['action']}',
    };
    return Card(child: ListTile(title: Text('$action · ${subscriptionDate(log['at'])}'),
      subtitle: Text('Tài khoản: ${log['userId']}\nAdmin: ${log['actorId']}'
        '${subscriptionMap(log['item'])['planId'] != null ? '\nGói: ${subscriptionMap(log['item'])['planId']}' : ''}'
        '${log['outcome'] != null ? '\nKết quả: ${log['outcome']}' : ''}'
        '${log['note'] != null && log['note'].toString().isNotEmpty ? '\n${log['note']}' : ''}')));
  }
}

class SubscriptionAuditPage extends StatefulWidget {
  final SubscriptionGateway api;
  final String? userId;
  const SubscriptionAuditPage({super.key, required this.api, this.userId});
  @override
  State<SubscriptionAuditPage> createState() => _SubscriptionAuditPageState();
}
class _SubscriptionAuditPageState extends State<SubscriptionAuditPage> {
  List<Map<String, dynamic>> logs = [];
  bool loading = false;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    if (!mounted || loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.api.logs(userId: widget.userId);
      if (mounted) setState(() { logs = result; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); logs = []; });
    } finally { if (mounted) setState(() { loading = false; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Nhật ký quản trị')),
    body: RefreshIndicator(onRefresh: load, child: ListView(physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16), children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        const Text('Tối đa 200 thao tác gần nhất.'),
        ...logs.map((log) => SubscriptionAuditTile(log: log)),
      ],
    )));
}
