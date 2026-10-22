import 'package:flutter/material.dart';
import 'account_profile_page.dart' as profile;

// The original profile implementation is preserved verbatim in account_profile_page.dart.
class AccountPage extends StatelessWidget {
  final Future<void> Function() onLogout;
  final Future<void> Function() onAuthChanged;
  final Future<void> Function() onAccountDeleted;
  const AccountPage({super.key, required this.onLogout, required this.onAuthChanged, required this.onAccountDeleted});
  @override
  Widget build(BuildContext context) => profile.AccountPage(
    onLogout: onLogout, onAuthChanged: onAuthChanged, onAccountDeleted: onAccountDeleted,
  );
}
