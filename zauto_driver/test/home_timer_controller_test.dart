import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/home/home_timer_controller.dart';

void main() {
  test('stopping the trip countdown does not stop quota refresh', () {
    final timers = HomeTimerController();
    addTearDown(timers.dispose);

    timers.startQuotaRefresh(() {});
    timers.ensureCountdown(() {});
    expect(timers.quotaRefreshRunning, isTrue);
    expect(timers.countdownRunning, isTrue);

    timers.stopCountdown();
    expect(timers.countdownRunning, isFalse);
    expect(timers.quotaRefreshRunning, isTrue);
  });

  test('quota refresh may stop independently of the trip countdown', () {
    final timers = HomeTimerController();
    addTearDown(timers.dispose);

    timers.startQuotaRefresh(() {});
    timers.ensureCountdown(() {});
    timers.stopQuotaRefresh();

    expect(timers.quotaRefreshRunning, isFalse);
    expect(timers.countdownRunning, isTrue);
  });

  test('countdown can restart, and disposing cancels all pending timers', () {
    final timers = HomeTimerController();

    timers.startQuotaRefresh(() {});
    timers.ensureCountdown(() {});
    timers.stopCountdown();
    timers.ensureCountdown(() {});
    expect(timers.countdownRunning, isTrue);

    timers.dispose();
    expect(timers.quotaRefreshRunning, isFalse);
    expect(timers.countdownRunning, isFalse);

    timers.startQuotaRefresh(() {});
    timers.ensureCountdown(() {});
    expect(timers.quotaRefreshRunning, isFalse);
    expect(timers.countdownRunning, isFalse);
  });
}
