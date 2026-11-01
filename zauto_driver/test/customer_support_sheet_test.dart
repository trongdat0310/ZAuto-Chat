import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/account/customer_support_sheet.dart';

Future<void> pumpSupport(
  WidgetTester tester, {
  Future<bool> Function(Uri)? openContact,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(showCustomerSupportSheet(
                context,
                openContact: openContact,
              ));
            },
            child: const Text('Mở hỗ trợ'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở hỗ trợ'));
  await tester.pumpAndSettle();
}

void main() {
  test('support destinations use the requested HTTPS URLs without credentials',
      () {
    expect(supportPhoneLabel, '0945.785.631');
    expect(supportWebsiteUri.toString(), 'https://zchatauto.io.vn/');
    expect(supportZaloUri.toString(), 'https://zalo.me/0945785631');
    for (final uri in [supportWebsiteUri, supportZaloUri]) {
      expect(uri.scheme, 'https');
      expect(uri.userInfo, isEmpty);
      expect(uri.query, isEmpty);
      expect(uri.fragment, isEmpty);
    }
  });

  test('website launcher receives the exact homepage URL', () async {
    Uri? received;
    final opened = await launchSupportWebsite(openUrl: (uri) async {
      received = uri;
      return true;
    });
    expect(opened, isTrue);
    expect(received, supportWebsiteUri);
  });

  test('website launcher does not hide platform failure', () async {
    expect(
      await launchSupportWebsite(openUrl: (_) async => false),
      isFalse,
    );
    await expectLater(
      launchSupportWebsite(openUrl: (_) async => throw StateError('failure')),
      throwsStateError,
    );
  });

  test('account support tiles are wired to the website and contact sheet', () {
    final source = File('lib/pages/account_page.dart').readAsStringSync();
    for (final title in ['Trang chủ', 'Hướng dẫn sử dụng']) {
      expect(
        RegExp(
          "title: '${RegExp.escape(title)}',"
          r'\s+onTap: _openSupportWebsite,',
        ).hasMatch(source),
        isTrue,
      );
    }
    expect(
      RegExp(
        "title: 'Hỗ trợ khách hàng',"
        r'\s+onTap: _showCustomerSupport,',
      ).hasMatch(source),
      isTrue,
    );
    expect(source.contains("onTap: showMembershipInfo,"), isTrue);
    expect(source.contains("onTap: editEmail,"), isTrue);
  });

  testWidgets('sheet displays the requested phone, title and two actions',
      (tester) async {
    await pumpSupport(tester);
    expect(find.text('Hỗ trợ khách hàng'), findsOneWidget);
    expect(
      find.text('Bạn cần hỗ trợ vui lòng liên hệ: 0945.785.631'),
      findsOneWidget,
    );
    expect(find.text('Liên hệ ngay'), findsOneWidget);
    expect(find.text('Đã hiểu'), findsOneWidget);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact opens the exact Zalo profile URL', (tester) async {
    final opened = <Uri>[];
    await pumpSupport(tester, openContact: (uri) async {
      opened.add(uri);
      return true;
    });
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pumpAndSettle();
    expect(opened, [supportZaloUri]);
    expect(find.byKey(const ValueKey('support-link-error')), findsNothing);
    expect(find.byType(CustomerSupportSheet), findsOneWidget);
  });

  testWidgets('acknowledge dismisses only the support sheet', (tester) async {
    await pumpSupport(tester);
    await tester.tap(find.byKey(const ValueKey('support-dismiss-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerSupportSheet), findsNothing);
    expect(find.text('Mở hỗ trợ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('false launch result shows an error and allows retry',
      (tester) async {
    var calls = 0;
    await pumpSupport(tester, openContact: (_) async => ++calls > 1);
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-link-error')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('support-link-error')), findsNothing);
  });

  testWidgets('platform exception is handled without closing the sheet',
      (tester) async {
    await pumpSupport(
      tester,
      openContact: (_) async => throw StateError('platform unavailable'),
    );
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-link-error')), findsOneWidget);
    expect(find.text('Đã hiểu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap cannot launch multiple contacts at once',
      (tester) async {
    final result = Completer<bool>();
    var calls = 0;
    await pumpSupport(tester, openContact: (_) {
      calls++;
      return result.future;
    });
    final button = find.byKey(const ValueKey('support-contact-button'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('sheet can close while external launch is pending',
      (tester) async {
    final result = Completer<bool>();
    await pumpSupport(tester, openContact: (_) => result.future);
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('support-dismiss-button')));
    await tester.pumpAndSettle();
    result.completeError(StateError('late platform response'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerSupportSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeout releases loading and displays an error', (tester) async {
    final result = Completer<bool>();
    await pumpSupport(tester, openContact: (_) => result.future);
    await tester.tap(find.byKey(const ValueKey('support-contact-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-link-error')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const ValueKey('support-contact-button')),
      ).onPressed,
      isNotNull,
    );
    result.complete(true);
    await tester.pump();
  });

  testWidgets('small display and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSupport(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final dismiss = find.byKey(const ValueKey('support-dismiss-button'));
    await tester.ensureVisible(dismiss);
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerSupportSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme uses the current surface instead of forcing white',
      (tester) async {
    await pumpSupport(tester, brightness: Brightness.dark);
    final sheetFinder = find.byType(CustomerSupportSheet);
    final scheme = Theme.of(tester.element(sheetFinder)).colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      scheme.surface,
    );
    expect(tester.takeException(), isNull);
  });
}
