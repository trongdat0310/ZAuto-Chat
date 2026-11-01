import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const supportPhoneLabel = '0945.785.631';
final supportWebsiteUri = Uri.parse('https://zchatauto.io.vn/');
final supportZaloUri = Uri.parse('https://zalo.me/0945785631');

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

// The two website tiles share the same destination. No account or auth data is
// appended to either support URL.
Future<bool> launchSupportWebsite({
  Future<bool> Function(Uri)? openUrl,
}) => (openUrl ?? _launchExternal)(supportWebsiteUri);

Future<void> showCustomerSupportSheet(
  BuildContext context, {
  Future<bool> Function(Uri)? openContact,
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
    builder: (_) => CustomerSupportSheet(openContact: openContact),
  );
}

class CustomerSupportSheet extends StatefulWidget {
  const CustomerSupportSheet({super.key, this.openContact});

  final Future<bool> Function(Uri)? openContact;

  @override
  State<CustomerSupportSheet> createState() => _CustomerSupportSheetState();
}

class _CustomerSupportSheetState extends State<CustomerSupportSheet> {
  bool _opening = false;
  String? _linkError;

  Future<void> _contact() async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _linkError = null;
    });
    try {
      final opened = await (widget.openContact ?? _launchExternal)(
        supportZaloUri,
      ).timeout(const Duration(seconds: 15));
      if (!opened) {
        throw StateError('Unable to open support link');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _linkError = 'Không mở được Zalo. Vui lòng thử lại hoặc tìm '
              'số 0945785631 trong Zalo.';
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
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

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
            Semantics(
              header: true,
              child: const Text(
                'Hỗ trợ khách hàng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bạn cần hỗ trợ vui lòng liên hệ: $supportPhoneLabel',
              key: const ValueKey('support-phone'),
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('support-contact-button'),
              onPressed: _opening ? null : _contact,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: buttonShape,
              ),
              child: _opening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Đang mở Zalo',
                      ),
                    )
                  : const Text('Liên hệ ngay', style: TextStyle(fontSize: 16)),
            ),
            if (_linkError != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _linkError!,
                  key: const ValueKey('support-link-error'),
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('support-dismiss-button'),
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.outlineVariant),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: buttonShape,
              ),
              child: const Text('Đã hiểu', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
