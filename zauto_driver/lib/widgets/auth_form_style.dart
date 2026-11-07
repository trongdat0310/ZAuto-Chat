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

  static Widget dialogHeader(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/AvatarApp.png',
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static Widget dialogActions(
    BuildContext context, {
    required bool loading,
    required VoidCallback onCancel,
    required VoidCallback onSubmit,
    required String submitLabel,
    required String loadingLabel,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: loading ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('HỦY'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: loading ? null : onSubmit,
                style: primaryButtonStyle(context),
                child: Text(
                  loading ? loadingLabel : submitLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
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
