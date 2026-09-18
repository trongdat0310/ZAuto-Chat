import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback? onTap;

  final bool enabled;

  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        child: Row(
          children: [
            // ========================================
            // ICON
            // ========================================

            Container(
              width: 50,

              height: 50,

              decoration: BoxDecoration(
                color: enabled
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,

                borderRadius: BorderRadius.circular(14),
              ),

              child: Icon(
                icon,

                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),

            const SizedBox(width: 16),

            // ========================================
            // TEXT
            // ========================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w600,

                      color: enabled
                          ? null
                          : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,

                    style: TextStyle(
                      fontSize: 13,

                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: enabled ? 1 : 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right,

                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
          ],
        ),
      ),
    );
  }
}
