import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/backend/subscription_api.dart';
import 'subscription_admin_page.dart';
import 'subscription_summary.dart';

class SubscriptionPage extends StatefulWidget {
  final SubscriptionGateway? api;
  final Stream<Map<String, dynamic>>? events;
  const SubscriptionPage({super.key, this.api, this.events});
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with WidgetsBindingObserver {
  late final SubscriptionGateway api;
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;
  Timer? refreshTimer;
  StreamSubscription<Map<String, dynamic>>? events;

  @override
  void initState() {
    super.initState();
    api = widget.api ?? createSubscriptionApi();
    WidgetsBinding.instance.addObserver(this);
    events = widget.events?.listen((event) {
      if (['subscription_changed', 'trip_accepted', 'authenticated'].contains(event['type'])) load();
    }, onError: (Object _) { /* Manual refresh remains available. */ });
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) load();
    });
    load();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }
  Future<void> load() async {
    if (loading || !mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await api.overview();
      if (mounted) setState(() { data = result; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); data = null; });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    events?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final plans = subscriptionRows(data?['plans']);
    return Scaffold(appBar: AppBar(title: const Text('Gói sử dụng'), actions: [
      IconButton(tooltip: 'Làm mới', onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
    ]), body: RefreshIndicator(onRefresh: load, child: ListView(
      key: const ValueKey('subscription-overview-list'),
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        if (data != null) ...[
          SubscriptionSummary(subscription: subscriptionMap(data!['subscription']), plans: plans),
          if (data!['isAdmin'] == true) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton.icon(key: const ValueKey('subscription-admin-entry'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Quản lý tài khoản và gói'), onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SubscriptionAdminPage(api: api, plans: plans)));
                if (mounted) await load();
              })),
          const Padding(key: ValueKey('subscription-overview-footer'),
            padding: EdgeInsets.all(12), child: Text(
            'Admin cấp và gia hạn gói. Phiên bản này chưa có thanh toán.')),
        ],
      ],
    )));
  }
}

class SubscriptionAccountShell extends StatelessWidget {
  final Widget child;
  final Stream<Map<String, dynamic>>? events;
  const SubscriptionAccountShell({super.key, required this.child, this.events});
  @override
  Widget build(BuildContext context) => Column(children: [
    SafeArea(bottom: false, child: ListTile(
      leading: const Icon(Icons.workspace_premium_outlined), title: const Text('Gói sử dụng'),
      subtitle: const Text('Xem lượt còn lại và quản lý gói'),
      trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SubscriptionPage(events: events))),
    )),
    Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
  ]);
}
