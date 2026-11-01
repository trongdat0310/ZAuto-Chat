import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/account/membership_info_sheet.dart';
import 'package:zauto_driver/pages/account/membership_status.dart';

final _receivedAt = DateTime.utc(2026, 11, 1, 12);
const _names = <String, String>{
  'monthly30': '30 lượt/tháng',
  'daily15': '15 lượt/ngày',
  'daily30': '30 lượt/ngày',
  'daily55': '55 lượt/ngày',
  'unlimited': 'Unlimited',
  'extra10': 'Thêm 10 lượt/ngày',
  'extra30': 'Thêm 30 lượt/ngày',
};

Map<String, dynamic> _plan(String id, {
  String startsAt = '2026-11-01T00:00:00Z',
  String endsAt = '2026-11-30T16:59:59.999Z',
}) => {'planId': id, 'startsAt': startsAt, 'endsAt': endsAt};

Map<String, dynamic> _overview({
  Map<String, dynamic>? main,
  List<Map<String, dynamic>> addons = const [],
}) => {
  'subscription': {
    'serverNow': '2026-11-01T12:00:00Z',
    'main': main,
    'addons': addons,
    'features': [
      {'feature': 'chat_accept', 'remaining': 0},
    ],
  },
  'plans': [
    for (final entry in _names.entries) {'id': entry.key, 'name': entry.value},
  ],
};

String _label(Map<String, dynamic> data) =>
    MembershipStatus.fromOverview(data, receivedAt: _receivedAt)
        .displayName(now: _receivedAt);

Future<void> _open(
  WidgetTester tester, {
  required Future<Map<String, dynamic>> Function() load,
  Future<bool> Function(Uri)? launch,
  ValueChanged<MembershipStatus>? onLoaded,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff2175cc), brightness: brightness,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showMembershipInfoSheet(
          context,
          loadOverview: load,
          openWebsite: launch,
          onStatusLoaded: onLoaded,
        ),
        child: const Text('open'),
      ),
    )),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  test('no current entitlement is free, regardless of legacy profile value', () {
    final data = _overview()..['membership'] = 'VIP';
    expect(_label(data), 'Miễn phí');
  });

  for (final entry in _names.entries) {
    test('displays catalog name for ${entry.key}', () {
      final data = entry.key.startsWith('extra')
          ? _overview(addons: [_plan(entry.key)])
          : _overview(main: _plan(entry.key));
      expect(_label(data), entry.value);
    });
  }

  test('expired plan and lastMain history are not current membership', () {
    final data = _overview(
      main: _plan('daily15', endsAt: '2026-11-01T11:59:59Z'),
    );
    (data['subscription'] as Map)['lastMain'] = _plan('monthly30');
    expect(_label(data), 'Miễn phí');
  });

  test('future plan is not displayed before its start', () {
    expect(_label(_overview(main: _plan(
      'daily15', startsAt: '2026-11-02T00:00:00Z',
    ))), 'Miễn phí');
  });

  test('running out of credits does not turn an active plan into free', () {
    expect(_label(_overview(main: _plan('monthly30'))), '30 lượt/tháng');
  });

  test('main and standalone daily add-ons are shown by name', () {
    expect(_label(_overview(
      main: _plan('daily15'),
      addons: [_plan('extra10'), _plan('extra30')],
    )), '15 lượt/ngày + Thêm 10 lượt/ngày + Thêm 30 lượt/ngày');
  });

  test('repeated add-ons do not repeat identical names', () {
    expect(_label(_overview(
      addons: [_plan('extra10'), _plan('extra10')],
    )), 'Thêm 10 lượt/ngày');
  });

  test('uses server clock offset and expires at end-of-day boundary', () {
    final deviceTime = DateTime.utc(2030, 1, 1);
    final status = MembershipStatus.fromOverview(_overview(
      addons: [_plan('extra10', endsAt: '2026-11-01T16:59:59.999Z')],
    ), receivedAt: deviceTime);
    expect(status.displayName(now: deviceTime), 'Thêm 10 lượt/ngày');
    expect(status.displayName(now: deviceTime.add(
      const Duration(hours: 4, minutes: 59, seconds: 59, milliseconds: 999),
    )), 'Thêm 10 lượt/ngày');
    expect(status.displayName(
      now: deviceTime.add(const Duration(hours: 5)),
    ), 'Miễn phí');
  });

  test('unknown but active plan is not mislabeled free', () {
    expect(_label(_overview(main: _plan('future-plan'))), 'Gói đang sử dụng');
  });

  test('malformed API data is not treated as a free account', () {
    expect(() => _label({}), throwsFormatException);
    expect(() => _label(_overview(main: {'planId': 'daily15'})),
        throwsFormatException);
  });

  testWidgets('opens compact bottom sheet matching member information layout',
      (tester) async {
    await _open(tester, load: () async => _overview());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Thông tin thành viên'), findsOneWidget);
    expect(find.text('Gói hiện tại'), findsOneWidget);
    expect(find.text('Miễn phí'), findsOneWidget);
    expect(find.text('Nâng hạng gói'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    final sheetHeight = tester.getSize(find.byType(BottomSheet)).height;
    expect(sheetHeight, lessThan(350));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('loading never flashes free and loaded name updates parent',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    MembershipStatus? parentStatus;
    await _open(tester,
      load: () => pending.future,
      onLoaded: (value) => parentStatus = value,
    );
    expect(find.text('Đang tải...'), findsOneWidget);
    expect(find.text('Miễn phí'), findsNothing);
    pending.complete(_overview(main: _plan('monthly30')));
    await tester.pumpAndSettle();
    expect(find.text('30 lượt/tháng'), findsOneWidget);
    expect(parentStatus?.displayName(), '30 lượt/tháng');
    await _dispose(tester);
  });

  testWidgets('API error offers retry instead of displaying free', (tester) async {
    var calls = 0;
    await _open(tester, load: () async {
      if (++calls == 1) {
        throw StateError('offline');
      }
      return _overview(main: _plan('daily15'));
    });
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được'), findsOneWidget);
    expect(find.text('Miễn phí'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('15 lượt/ngày'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('upgrade uses exact website without account or token parameters',
      (tester) async {
    Uri? opened;
    await _open(tester, load: () async => _overview(), launch: (uri) async {
      opened = uri;
      return true;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('membership-upgrade-button')));
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://zchatauto.io.vn/');
    expect(opened!.query, isEmpty);
    expect(opened!.fragment, isEmpty);
    await _dispose(tester);
  });

  testWidgets('failed browser launch reports error and allows retry',
      (tester) async {
    await _open(tester, load: () async => _overview(), launch: (_) async => false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('membership-upgrade-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không mở được website.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('membership-upgrade-button')),
    );
    expect(button.onPressed, isNotNull);
    await _dispose(tester);
  });

  testWidgets('repeated taps while opening browser do not launch twice',
      (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await _open(tester, load: () async => _overview(), launch: (_) {
      calls++;
      return pending.future;
    });
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('membership-upgrade-button'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(calls, 1);
    pending.complete(true);
    await tester.pumpAndSettle();
    await _dispose(tester);
  });

  testWidgets('returning from browser refreshes membership', (tester) async {
    var upgraded = false;
    await _open(tester, load: () async =>
        _overview(main: upgraded ? _plan('daily30') : null));
    await tester.pumpAndSettle();
    expect(find.text('Miễn phí'), findsOneWidget);
    upgraded = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('30 lượt/ngày'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('late request after closing sheet does not update disposed state',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await _open(tester, load: () => pending.future);
    await _dispose(tester);
    pending.complete(_overview());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long package names fit narrow dark layout with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester,
      brightness: Brightness.dark,
      textScale: 2,
      load: () async => _overview(
        main: _plan('daily55'),
        addons: [_plan('extra10'), _plan('extra30')],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
