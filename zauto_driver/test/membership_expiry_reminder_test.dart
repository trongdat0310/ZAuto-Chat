import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zauto_driver/pages/account/membership_expiry_reminder.dart';
import 'package:zauto_driver/pages/account/membership_status.dart';

final _start = DateTime.utc(2026, 11, 1, 12);

MembershipStatus _status({String? endsAt, bool main = true}) {
  return MembershipStatus.fromOverview({
    'subscription': {
      'serverNow': '2026-11-01T12:00:00Z',
      'main': main
          ? {
              'planId': 'monthly30',
              'startsAt': '2026-11-01T00:00:00Z',
              'endsAt': endsAt ?? '2026-11-03T16:59:59.999Z',
            }
          : null,
      'addons': [
        {
          'planId': 'extra10',
          'startsAt': '2026-11-01T00:00:00Z',
          'endsAt': '2026-11-01T16:59:59.999Z',
        },
      ],
    },
    'plans': [
      {'id': 'monthly30', 'name': '30 lượt/tháng'},
      {'id': 'extra10', 'name': 'Thêm 10 lượt/ngày'},
    ],
  }, receivedAt: _start);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('one notice per VN day and account, across app restarts', () async {
    final preferences = await SharedPreferences.getInstance();
    final status = _status();
    final first = await MembershipExpiryReminder.claim(
      status: status, userId: 'user1', preferences: preferences, now: _start,
    );
    expect(first, isNotNull);
    expect(first!.vnDayKey, '2026-11-01');
    expect(await MembershipExpiryReminder.claim(
      status: status, userId: 'user1', preferences: preferences, now: _start,
    ), isNull);
    expect(await MembershipExpiryReminder.claim(
      status: status, userId: 'user2', preferences: preferences, now: _start,
    ), isNotNull);
    final nextDay = _start.add(const Duration(days: 1));
    final secondDay = await MembershipExpiryReminder.claim(
      status: status, userId: 'user1', preferences: preferences, now: nextDay,
    );
    expect(secondDay?.vnDayKey, '2026-11-02');
    expect(await MembershipExpiryReminder.claim(
      status: status, userId: 'user1', preferences: preferences, now: nextDay,
    ), isNull);
  });

  test('expired main, add-on-only, and missing user do not mark notice', () async {
    final preferences = await SharedPreferences.getInstance();
    expect(await MembershipExpiryReminder.claim(
      status: _status(endsAt: '2026-11-01T11:00:00Z'),
      userId: 'user1', preferences: preferences, now: _start,
    ), isNull);
    expect(await MembershipExpiryReminder.claim(
      status: _status(main: false),
      userId: 'user1', preferences: preferences, now: _start,
    ), isNull);
    expect(await MembershipExpiryReminder.claim(
      status: _status(),
      userId: '  ', preferences: preferences, now: _start,
    ), isNull);
    expect(preferences.getKeys(), isEmpty);
  });
}
