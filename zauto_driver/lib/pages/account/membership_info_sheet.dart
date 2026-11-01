import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'membership_status.dart';

final membershipUpgradeUri = Uri.parse('https://zchatauto.io.vn/');

Future<bool> _openWebsite(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> showMembershipInfoSheet(
  BuildContext context, {
  required Future<Map<String, dynamic>> Function() loadOverview,
  MembershipStatus? initialStatus,
  ValueChanged<MembershipStatus>? onStatusLoaded,
  Future<bool> Function(Uri)? openWebsite,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => MembershipInfoSheet(
      loadOverview: loadOverview,
      initialStatus: initialStatus,
      onStatusLoaded: onStatusLoaded,
      openWebsite: openWebsite,
    ),
  );
}

class MembershipInfoSheet extends StatefulWidget {
  const MembershipInfoSheet({
    super.key,
    required this.loadOverview,
    this.initialStatus,
    this.onStatusLoaded,
    this.openWebsite,
  });

  final Future<Map<String, dynamic>> Function() loadOverview;
  final MembershipStatus? initialStatus;
  final ValueChanged<MembershipStatus>? onStatusLoaded;
  final Future<bool> Function(Uri)? openWebsite;

  @override
  State<MembershipInfoSheet> createState() => _MembershipInfoSheetState();
}

class _MembershipInfoSheetState extends State<MembershipInfoSheet>
    with WidgetsBindingObserver {
  MembershipStatus? _status;
  bool _loading = false;
  bool _opening = false;
  String? _loadError;
  String? _linkError;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _status != null) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading || !mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final overview = await widget.loadOverview().timeout(
        const Duration(seconds: 15),
      );
      final status = MembershipStatus.fromOverview(overview);
      if (!mounted) {
        return;
      }
      setState(() => _status = status);
      widget.onStatusLoaded?.call(status);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Không tải được thông tin gói. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _upgrade() async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _linkError = null;
    });
    try {
      final opened = await (widget.openWebsite ?? _openWebsite)(
        membershipUpgradeUri,
      );
      if (!opened) {
        throw StateError('Website could not be opened');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _linkError = 'Không mở được website. Vui lòng thử lại hoặc truy cập '
              'https://zchatauto.io.vn/ bằng trình duyệt.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = _loadError != null
        ? 'Chưa tải được'
        : _status?.displayName() ?? 'Đang tải...';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thông tin thành viên',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 22),
            Container(
              key: const ValueKey('membership-current-plan'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(18),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final value = Text(
                    label,
                    key: const ValueKey('membership-plan-name'),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 16, color: colors.primary),
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Gói hiện tại', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        value,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Text('Gói hiện tại', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 16),
                      Expanded(child: value),
                    ],
                  );
                },
              ),
            ),
            if (_loading && _status == null) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              Text(_loadError!, style: TextStyle(color: colors.error)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Thử lại'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('membership-upgrade-button'),
              onPressed: _opening ? null : _upgrade,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _opening
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Nâng hạng gói'),
            ),
            if (_linkError != null) ...[
              const SizedBox(height: 12),
              Text(_linkError!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
