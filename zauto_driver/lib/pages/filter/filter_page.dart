import 'package:flutter/material.dart';

import 'add_notification_filter_page.dart';

class FilterPage extends StatefulWidget {
  // Giu lai de khong anh huong MainScreen hien tai.
  // Logic tab/filter moi se xu ly o buoc sau.
  final int initialTab;

  const FilterPage({super.key, this.initialTab = 0});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  static const int maxFilters = 50;

  // ========================================
  // UI ONLY
  //
  // Logic filter moi se them sau.
  // Hien tai mac dinh chua co filter.
  // ========================================

  int filterCount = 0;

  Future<void> _addFilter() async {
    if (filterCount >= maxFilters) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return const AddNotificationFilterPage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ========================================
          // HEADER
          // ========================================

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Center(
              child: Text(
                'Bộ lọc thông báo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),

          // ========================================
          // CONTENT
          // ========================================
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: filterCount == 0
                      ? _buildEmptyState(context)
                      : _buildFilterListPlaceholder(context),
                ),

                // =================================
                // FLOATING ADD FILTER
                //
                // Nam phia tren bottom navigation.
                // =================================
                Positioned(
                  right: 18,
                  bottom: 18,

                  child: _buildFloatingAddButton(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // EMPTY STATE
  // ========================================

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(24, 105, 24, 130),

      children: [
        // ========================================
        // ICON
        // ========================================

        Center(
          child: Icon(
            Icons.touch_app_rounded,
            size: 82,
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 28),

        // ========================================
        // TITLE
        // ========================================
        Text(
          'Chưa có bộ lọc thông báo nào',
          textAlign: TextAlign.center,

          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 10),

        // ========================================
        // DESCRIPTION
        // ========================================
        Text(
          'Chưa có bộ lọc thì mọi tin đều hiện.',
          textAlign: TextAlign.center,

          style: TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 30),

        // ========================================
        // MAIN ADD BUTTON
        // ========================================
        SizedBox(
          height: 62,

          child: FilledButton.icon(
            onPressed: filterCount >= maxFilters ? null : _addFilter,

            icon: const Icon(Icons.add_rounded, size: 30),

            label: const Text(
              'Thêm bộ lọc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),

            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // FILTER LIST
  //
  // UI cua tung filter se lam sau khi
  // ban gui logic moi.
  // ========================================

  Widget _buildFilterListPlaceholder(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),

      children: const [],
    );
  }

  // ========================================
  // FLOATING ADD BUTTON
  // ========================================

  Widget _buildFloatingAddButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final disabled = filterCount >= maxFilters;

    return Material(
      elevation: 5,

      color: disabled
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer,

      shadowColor: colorScheme.shadow.withValues(alpha: 0.24),

      borderRadius: BorderRadius.circular(22),

      child: InkWell(
        onTap: disabled ? null : _addFilter,

        borderRadius: BorderRadius.circular(22),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              Icon(
                Icons.add_rounded,
                size: 29,

                color: disabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimaryContainer,
              ),

              const SizedBox(width: 12),

              Text(
                'Thêm bộ lọc',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,

                  color: disabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 10),

              Text(
                '$filterCount/$maxFilters',

                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,

                  color: disabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
