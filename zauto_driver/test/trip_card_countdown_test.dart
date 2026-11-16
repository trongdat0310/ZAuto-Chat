import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/controllers/settings_controller.dart';
import 'package:zauto_driver/pages/home/trip_card.dart';

void main() {
  testWidgets('timer tick rebuilds only the countdown, not the trip card content',
      (tester) async {
    final settings = SettingsController();
    final countdown = ValueNotifier<int>(0);
    addTearDown(settings.dispose);
    addTearDown(countdown.dispose);

    final trip = <String, dynamic>{
      'id': 'trip-1',
      'groupName': 'Nhóm xe',
      'senderName': 'Người gửi',
      'content': 'Nội dung cuốc cần đọc',
      '_uiStatus': 'new',
      '_remainingSeconds': 8,
    };
    var outerBuilds = 0;
    var accepted = 0;
    var ignored = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (_) {
              outerBuilds++;
              return TripCard(
                trip: trip,
                countdownRefresh: countdown,
                settingsController: settings,
                onAccept: () => accepted++,
                onIgnore: () => ignored++,
                onOpenMessage: () {},
                onSwipeReply: () {},
                onCancelReply: () {},
                onSendReply: (_) async => true,
              );
            },
          ),
        ),
      ),
    ));
    expect(find.text('00:08'), findsOneWidget);
    final beforeBuilds = outerBuilds;
    final contentElement = tester.element(find.text('Nội dung cuốc cần đọc'));

    trip['_remainingSeconds'] = 3;
    countdown.value += 1;
    await tester.pump();

    expect(find.text('00:03'), findsOneWidget);
    expect(find.text('00:08'), findsNothing);
    expect(outerBuilds, beforeBuilds);
    expect(tester.element(find.text('Nội dung cuốc cần đọc')),
        same(contentElement));
    final badge = find.byKey(const ValueKey('trip-countdown-badge'));
    final warningIcon = find.descendant(
      of: badge,
      matching: find.byIcon(Icons.warning_amber_rounded),
    );
    expect(warningIcon, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('NHẬN'));
    await tester.pump();
    expect(accepted, 1);
    expect(ignored, 0);
  });

  testWidgets('card without countdown signal retains existing behavior',
      (tester) async {
    final settings = SettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TripCard(
            trip: const {
              'id': 'trip-legacy',
              'content': 'Cuốc cũ',
              '_remainingSeconds': 15,
            },
            settingsController: settings,
            onAccept: () {},
            onIgnore: () {},
            onOpenMessage: () {},
            onSwipeReply: () {},
            onCancelReply: () {},
            onSendReply: (_) async => true,
          ),
        ),
      ),
    ));
    expect(find.text('00:15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
