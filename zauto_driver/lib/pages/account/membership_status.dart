/// Member-facing plan names come from the subscription API, not user.membership.
class MembershipStatus {
  MembershipStatus._(this._plans, this._serverNow, this._receivedAt);

  final List<_MemberPlan> _plans;
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

    final plans = <_MemberPlan>[];
    void addPlan(dynamic value) {
      if (value is! Map || value['planId'] is! String) {
        throw const FormatException('Invalid membership plan');
      }
      final id = value['planId'] as String;
      final start = DateTime.tryParse(value['startsAt']?.toString() ?? '');
      final end = DateTime.tryParse(value['endsAt']?.toString() ?? '');
      if (id.isEmpty || start == null || end == null || end.isBefore(start)) {
        throw const FormatException('Invalid membership period');
      }
      plans.add(_MemberPlan(
        names[id] ?? 'Gói đang sử dụng',
        start.toUtc(),
        end.toUtc(),
      ));
    }

    final main = subscription['main'];
    if (main != null) {
      addPlan(main);
    }
    for (final addon in subscription['addons'] as List) {
      addPlan(addon);
    }
    return MembershipStatus._(
      List.unmodifiable(plans),
      serverNow.toUtc(),
      (receivedAt ?? DateTime.now()).toUtc(),
    );
  }

  /// Advance from server time so a device timezone/clock offset does not turn
  /// a valid package into "free". Exhausted quota does not expire a package.
  String displayName({DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).toUtc().difference(_receivedAt);
    final effectiveNow = _serverNow.add(
      elapsed.isNegative ? Duration.zero : elapsed,
    );
    final names = <String>{};
    for (final plan in _plans) {
      if (!effectiveNow.isBefore(plan.startsAt) &&
          !effectiveNow.isAfter(plan.endsAt)) {
        names.add(plan.name);
      }
    }
    return names.isEmpty ? 'Miễn phí' : names.join(' + ');
  }
}

class _MemberPlan {
  const _MemberPlan(this.name, this.startsAt, this.endsAt);

  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
}
