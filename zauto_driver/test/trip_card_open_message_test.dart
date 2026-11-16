import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/controllers/settings_controller.dart';
import 'package:zauto_driver/pages/home/trip_card.dart';

void main() {
  testWidgets('tapping trip content opens source without accepting or ignoring',
      (tester) async {
    final settings = SettingsController();
    addTearDown(settings.dispose);

    var opened = 0;
    var accepted = 0;
    var ignored = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripCard(
              trip: {
                'id': 'internal-1',
                'groupName': 'Nhóm xe',
                'senderName': 'Người gửi',
                'content': 'Cuốc Hà Nội đi Nội Bài giá 300k',
                '_uiStatus': 'new',
                '_remainingSeconds': 12,
              },
              settingsController: settings,
              onAccept: () => accepted++,
              onIgnore: () => ignored++,
              onOpenMessage: () => opened++,
              onSwipeReply: () {},
              onCancelReply: () {},
              onSendReply: (_) async => true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cuốc Hà Nội đi Nội Bài giá 300k'));
    await tester.pump();
    expect(opened, 1);
    expect(accepted, 0);
    expect(ignored, 0);

    await tester.tap(find.text('NHẬN'));
    await tester.pump();
    expect(accepted, 1);
    expect(opened, 1);

    await tester.tap(find.text('BỎ QUA'));
    await tester.pump();
    expect(ignored, 1);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap navigation disabled while a trip is being processed',
      (tester) async {
    final settings = SettingsController();
    addTearDown(settings.dispose);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCard(
            trip: {
              'id': 'internal-2',
              'content': 'Cuốc đang xử lý',
              '_uiStatus': 'accepting',
              '_remainingSeconds': 12,
            },
            settingsController: settings,
            onAccept: () {},
            onIgnore: () {},
            onOpenMessage: () => opened++,
            onSwipeReply: () {},
            onCancelReply: () {},
            onSendReply: (_) async => true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cuốc đang xử lý'));
    await tester.pump();
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });
}
