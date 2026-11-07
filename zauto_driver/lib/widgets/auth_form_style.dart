import 'package:flutter/material.dart';

/// Shared field styling for sign-in, registration and account-security forms.
class AuthFormStyle {
  AuthFormStyle._();

  static InputDecoration field(
    BuildContext context, {
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final radius = BorderRadius.circular(18);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: muted, fontSize: 16),
      errorText: errorText,
      prefixIcon: Icon(icon, size: 24, color: muted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 19,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colors.outline.withValues(alpha: 0.65),
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colors.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: colors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
