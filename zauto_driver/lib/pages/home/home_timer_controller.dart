import 'dart:async';

/// Owns two independent periodic jobs used by the Home screen.
///
/// The trip countdown can stop when there are no active trips without
/// accidentally stopping the quota refresh. dispose() stops both.
class HomeTimerController {
  HomeTimerController();

  Timer? _quotaRefresh;
  Timer? _tripCountdown;
  bool _disposed = false;

  bool get quotaRefreshRunning => _quotaRefresh?.isActive == true;
  bool get countdownRunning => _tripCountdown?.isActive == true;

  void startQuotaRefresh(
    void Function() onTick, {
    Duration interval = const Duration(seconds: 30),
  }) {
    if (_disposed || quotaRefreshRunning) return;
    _quotaRefresh = Timer.periodic(interval, (_) => onTick());
  }

  void stopQuotaRefresh() {
    _quotaRefresh?.cancel();
    _quotaRefresh = null;
  }

  void ensureCountdown(
    void Function() onTick, {
    Duration interval = const Duration(seconds: 1),
  }) {
    if (_disposed || countdownRunning) return;
    _tripCountdown = Timer.periodic(interval, (_) => onTick());
  }

  void stopCountdown() {
    _tripCountdown?.cancel();
    _tripCountdown = null;
  }

  /// Toggle periodic UI work without affecting realtime subscriptions.
  /// Inactive tabs retain their trip state; the caller recomputes remaining
  /// seconds from absolute deadlines when the tab is activated again.
  void setVisibleWork({
    required bool visible,
    required bool hasCountdownTrips,
    required void Function() onQuotaRefresh,
    required void Function() onCountdownTick,
  }) {
    if (!visible) {
      stopCountdown();
      stopQuotaRefresh();
      return;
    }

    startQuotaRefresh(onQuotaRefresh);
    if (hasCountdownTrips) {
      ensureCountdown(onCountdownTick);
    } else {
      stopCountdown();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stopCountdown();
    stopQuotaRefresh();
  }
}
