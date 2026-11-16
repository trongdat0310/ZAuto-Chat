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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stopCountdown();
    stopQuotaRefresh();
  }
}
