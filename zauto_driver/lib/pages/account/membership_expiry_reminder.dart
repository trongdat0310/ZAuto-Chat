import 'package:shared_preferences/shared_preferences.dart';

import 'membership_status.dart';

/// Store one expiry notification per account and Vietnam calendar day.
/// Mark before opening the popup so reopening the app does not show it twice.
class MembershipExpiryReminder {
  static Future<MembershipExpiryWarning?> claim({
    required MembershipStatus status,
    required String userId,
    required SharedPreferences preferences,
    DateTime? now,
  }) async {
    if (userId.trim().isEmpty) {
      return null;
    }
    final warning = status.expiringMain(now: now);
    if (warning == null) {
      return null;
    }
    final key = 'membership_expiry_notice:${Uri.encodeComponent(userId)}';
    if (preferences.getString(key) == warning.vnDayKey) {
      return null;
    }
    final saved = await preferences.setString(key, warning.vnDayKey);
    return saved ? warning : null;
  }
}
