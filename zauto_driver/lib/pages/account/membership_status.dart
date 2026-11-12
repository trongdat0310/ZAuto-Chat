/// Membership is derived from the subscription API, not user.membership.
class MembershipPlan {
  const MembershipPlan({
    required this.name,
    required this.startsAt,
    required this.endsAt,
  });

  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
}

String formatMembershipDateVN(DateTime value) {
  final vn = value.toUtc().add(const Duration(hours: 7));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(vn.day)}/${two(vn.month)}/${vn.year}';
}

String _membershipDayKeyVN(DateTime value) {
  final vn = value.toUtc().add(const Duration(hours: 7));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${vn.year}-${two(vn.month)}-${two(vn.day)}';
}

class MembershipExpiryWarning {
  const MembershipExpiryWarning({
    required this.plan,
    required this.remaining,
    required this.vnDayKey,
  });

  final MembershipPlan plan;
  final Duration remaining;
  final String vnDayKey;

  String get remainingText {
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    if (days > 0) {
      return '$days ngày $hours giờ';
    }
    final wholeHours = remaining.inHours;
    if (wholeHours > 0) {
      return '$wholeHours giờ ${remaining.inMinutes.remainder(60)} phút';
    }
    final roundedMinutes = (remaining.inSeconds + 59) ~/ 60;
    return '${roundedMinutes > 0 ? roundedMinutes : 1} phút';
  }
}

class MembershipStatus {
  MembershipStatus._(this._main, this._addons, this._serverNow, this._receivedAt);

  final MembershipPlan? _main;
  final List<MembershipPlan> _addons;
  final DateTime _serverNow;
  final DateTime _receivedAt;

  factory MembershipStatus.fromOverview(
    Map<String, dynamic> overview, {
    DateTime? receivedAt,
  }) {
    final subscription = overview['subscription'];
    final catalog = overview['plans'];
    if (subscription is! Map ||
        !subscription.containsKey('main') ||
        subscription['addons'] is! List ||
        catalog is! List) {
      throw const FormatException('Invalid membership response');
    }
    final serverNow = DateTime.tryParse(
      subscription['serverNow']?.toString() ?? '',
    );
    if (serverNow == null) {
      throw const FormatException('Missing membership server time');
    }

    final names = <String, String>{};
    for (final item in catalog) {
      if (item is Map && item['id'] is String && item['name'] is String) {
        final name = (item['name'] as String).trim();
        if (name.isNotEmpty) {
          names[item['id'] as String] = name;
        }
      }
    }

    MembershipPlan parsePlan(dynamic value) {
      if (value is! Map || value['planId'] is! String) {
        throw const FormatException('Invalid membership plan');
      }
      final id = value['planId'] as String;
      final start = DateTime.tryParse(value['startsAt']?.toString() ?? '');
      final end = DateTime.tryParse(value['endsAt']?.toString() ?? '');
      if (id.isEmpty || start == null || end == null || end.isBefore(start)) {
        throw const FormatException('Invalid membership period');
      }
      return MembershipPlan(
        name: names[id] ?? 'Gói đang sử dụng',
        startsAt: start.toUtc(),
        endsAt: end.toUtc(),
      );
    }

    final main = subscription['main'];
    final addons = <MembershipPlan>[];
    for (final addon in subscription['addons'] as List) {
      addons.add(parsePlan(addon));
    }
    return MembershipStatus._(
      main == null ? null : parsePlan(main),
      List.unmodifiable(addons),
      serverNow.toUtc(),
      (receivedAt ?? DateTime.now()).toUtc(),
    );
  }

  /// Use elapsed time since the server response so device clock offsets do not
  /// make valid packages appear expired. Exhausted quota does not expire a plan.
  DateTime _effectiveNow(DateTime? now) {
    final elapsed = (now ?? DateTime.now()).toUtc().difference(_receivedAt);
    return _serverNow.add(elapsed.isNegative ? Duration.zero : elapsed);
  }

  bool _isActive(MembershipPlan plan, DateTime when) =>
      !when.isBefore(plan.startsAt) && !when.isAfter(plan.endsAt);

  MembershipPlan? activeMain({DateTime? now}) {
    final main = _main;
    if (main == null || !_isActive(main, _effectiveNow(now))) {
      return null;
    }
    return main;
  }

  /// Prefer the latest purchase time; when times are equal, the final entry
  /// wins because the backend appends add-ons in purchase order.
  MembershipPlan? latestActiveAddon({DateTime? now}) {
    final when = _effectiveNow(now);
    MembershipPlan? latest;
    for (final addon in _addons) {
      if (!_isActive(addon, when)) {
        continue;
      }
      if (latest == null || !addon.startsAt.isBefore(latest.startsAt)) {
        latest = addon;
      }
    }
    return latest;
  }

  /// Preserve the legacy name summary for existing callers.
  String displayName({DateTime? now}) {
    final when = _effectiveNow(now);
    final names = <String>{};
    final main = _main;
    if (main != null && _isActive(main, when)) {
      names.add(main.name);
    }
    for (final addon in _addons) {
      if (_isActive(addon, when)) {
        names.add(addon.name);
      }
    }
    return names.isEmpty ? 'Miễn phí' : names.join(' + ');
  }

  String displaySummary({DateTime? now}) {
    final main = activeMain(now: now);
    if (main != null) {
      return '${main.name} - ${formatMembershipDateVN(main.endsAt)}';
    }
    final addon = latestActiveAddon(now: now);
    if (addon != null) {
      return '${addon.name} - ${formatMembershipDateVN(addon.endsAt)}';
    }
    return 'Miễn phí';
  }

  /// Daily top-up packs never trigger daily "expiring" alerts.
  MembershipExpiryWarning? expiringMain({DateTime? now}) {
    final when = _effectiveNow(now);
    final main = _main;
    if (main == null || !_isActive(main, when)) {
      return null;
    }
    final remaining = main.endsAt.difference(when);
    if (remaining.compareTo(Duration.zero) <= 0 ||
        remaining.compareTo(const Duration(days: 3)) >= 0) {
      return null;
    }
    return MembershipExpiryWarning(
      plan: main,
      remaining: remaining,
      vnDayKey: _membershipDayKeyVN(when),
    );
  }
}
