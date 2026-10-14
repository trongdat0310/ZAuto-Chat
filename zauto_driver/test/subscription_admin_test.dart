import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/services/backend/subscription_api.dart';
import 'package:zauto_driver/pages/subscriptions/subscription_page.dart';
import 'package:zauto_driver/pages/subscriptions/subscription_admin_page.dart';
import 'package:zauto_driver/pages/subscriptions/subscription_command_dialog.dart';
import 'package:zauto_driver/pages/subscriptions/subscription_summary.dart';

const plans = <Map<String, dynamic>>[
  {'id': 'daily15', 'name': '15 luot/ngay', 'addon': false},
  {'id': 'unlimited', 'name': 'Unlimited', 'addon': false},
  {'id': 'extra10', 'name': 'Them 10', 'addon': true},
];
Map<String, dynamic> snapshot() => {
  'revision': List.filled(64, 'a').join(),
  'main': {'id': 'plan', 'planId': 'daily15', 'startsAt': '2026-10-14T04:00:00Z', 'endsAt': '2026-11-14T04:00:00Z'},
  'features': [
    {'feature': 'trip_screen_accept', 'used': 2, 'reserved': 1, 'limit': 15, 'remaining': 12},
    {'feature': 'chat_accept', 'used': 0, 'reserved': 0, 'limit': null, 'remaining': null},
    {'feature': 'auto_accept', 'used': 0, 'reserved': 0, 'limit': 15, 'remaining': 15},
  ],
  'addons': [],
};
class FakeApi implements SubscriptionGateway {
  bool admin = false, offline = false;
  int failCommands = 0;
  final List<Map<String, dynamic>> commands = [];
  Future<Map<String, dynamic>> Function(String, int)? search;
  @override
  Future<Map<String, dynamic>> overview() async {
    if (offline) throw Exception('offline');
    return {'isAdmin': admin, 'subscription': snapshot(), 'plans': plans};
  }
  @override
  Future<Map<String, dynamic>> users({String query = '', int offset = 0}) async =>
      search == null ? {'users': [], 'total': 0, 'hasMore': false} : await search!(query, offset);
  @override
  Future<Map<String, dynamic>> user(String id) async => {
    'user': {'id': id, 'name': 'Test', 'phone': '0900000000'}, 'subscription': snapshot(), 'pending': [], 'logs': [],
  };
  @override
  Future<List<Map<String, dynamic>>> logs({String? userId}) async => [];
  @override
  Future<Map<String, dynamic>> command(String userId, String action, Map<String, dynamic> body) async {
    commands.add({'userId': userId, 'action': action, 'body': Map<String, dynamic>.from(body)});
    if (failCommands > 0) { failCommands--; throw Exception('response lost'); }
    return {'success': true};
  }
}
Future<void> openCommand(WidgetTester tester, FakeApi api, {String action = 'assign'}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => SubscriptionCommandDialog(
      api: api, user: const {'id': 'target', 'name': 'Test', 'phone': '0900000000'},
      subscription: snapshot(), plans: plans, action: action,
      operation: const {'targetKey': 'target-key'}, outcome: 'failed',
    )), child: const Text('open'),
  )))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
void main() {
  test('date presentation uses Vietnam time, not the device timezone', () {
    expect(subscriptionDate('2026-10-14T17:00:00Z'), '15/10/2026 00:00 (VN)');
    expect(subscriptionDate('bad'), '—');
  });
  testWidgets('personal quota renders held slots, unlimited and unavailable auto mode', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: SubscriptionSummary(subscription: snapshot(), plans: plans)))));
    expect(find.text('Còn lại: 12 lượt'), findsOneWidget);
    expect(find.text('Đã dùng: 2 · Đang giữ: 1'), findsOneWidget);
    expect(find.text('Còn lại: Không giới hạn'), findsOneWidget);
    expect(find.text('Chưa triển khai — chỉ dự phòng hạn mức.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('normal user never sees the administration entry', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SubscriptionPage(api: FakeApi())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.admin_panel_settings), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('server grants admin UI; refresh failure removes its cached authority', (tester) async {
    final api = FakeApi()..admin = true;
    await tester.pumpWidget(MaterialApp(home: SubscriptionPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    api.offline = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.admin_panel_settings), findsNothing);
    expect(find.textContaining('offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('retry after lost command response preserves request ID and all payload fields', (tester) async {
    final api = FakeApi()..failCommands = 1;
    await openCommand(tester, api);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
    expect((tester.widget<TextFormField>(find.byType(TextFormField))).enabled, isFalse);
    await tester.tap(find.text('Thử lại cùng yêu cầu'));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands[0], api.commands[1]);
    expect((api.commands[0]['body'] as Map)['expectedRevision'], snapshot()['revision']);
    expect((api.commands[0]['body'] as Map).containsKey('actorId'), isFalse);
    expect(find.byType(SubscriptionCommandDialog), findsNothing);
  });
  testWidgets('reconciliation cannot submit without a review note', (tester) async {
    final api = FakeApi();
    await openCommand(tester, api, action: 'reconcile');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    expect(find.textContaining('5 ký tự'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('late search response cannot overwrite the latest account search', (tester) async {
    final old = Completer<Map<String, dynamic>>();
    final fresh = Completer<Map<String, dynamic>>();
    final api = FakeApi()..search = (query, _) => query.isEmpty ? old.future : fresh.future;
    await tester.pumpWidget(MaterialApp(home: SubscriptionAdminPage(api: api, plans: plans)));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 400));
    fresh.complete({'users': [{'id': 'new', 'name': 'New account', 'phone': '0900000001'}], 'total': 1, 'hasMore': false});
    await tester.pumpAndSettle();
    old.complete({'users': [{'id': 'old', 'name': 'Old account', 'phone': '0900000002'}], 'total': 1, 'hasMore': false});
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);
    expect(find.text('Old account'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
