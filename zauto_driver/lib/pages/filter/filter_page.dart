import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/backend_service.dart';

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

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  List<Map<String, dynamic>> filters = [];

  final Set<String> mutatingFilterIds = {};

  bool loading = true;

  int get filterCount => filters.length;

  @override
  void initState() {
    super.initState();

    _loadFilters();
  }

  Future<void> _loadFilters() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final result = await backend.getNotificationFilters();

      if (!mounted) {
        return;
      }

      setState(() {
        filters = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải bộ lọc: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _addFilter() async {
    if (filterCount >= maxFilters) {
      return;
    }

    final saved = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) {
          return const AddNotificationFilterPage();
        },
      ),
    );

    if (!mounted || saved == null) {
      return;
    }

    final savedId = saved['id']?.toString() ?? '';

    if (
      savedId.isEmpty ||
      filters.any(
        (item) => item['id']?.toString() == savedId,
      )
    ) {
      await _loadFilters();
      return;
    }

    setState(() {
      filters = [
        ...filters,
        saved,
      ];
    });
  }

  Future<void> _editFilter(Map<String, dynamic> filter) async {
    final saved = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) {
          return AddNotificationFilterPage(
            initialFilter: Map<String, dynamic>.from(filter),
          );
        },
      ),
    );

    if (!mounted || saved == null) {
      return;
    }

    final filterId = saved['id']?.toString() ?? '';

    if (filterId.isEmpty) {
      await _loadFilters();
      return;
    }

    final index = filters.indexWhere(
      (item) => item['id']?.toString() == filterId,
    );

    if (index < 0) {
      await _loadFilters();
      return;
    }

    setState(() {
      filters[index] = saved;
    });
  }

  Future<void> _deleteFilter(Map<String, dynamic> filter) async {
    final filterId = filter['id']?.toString() ?? '';

    if (filterId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa bộ lọc?'),
          content: Text(
            'Bộ lọc "${filter['name'] ?? 'Bộ lọc'}" sẽ bị xóa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('XÓA'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (mutatingFilterIds.contains(filterId)) {
      return;
    }

    setState(() {
      mutatingFilterIds.add(filterId);
    });

    try {
      await backend.deleteNotificationFilter(filterId);

      if (!mounted) {
        return;
      }

      setState(() {
        filters.removeWhere(
          (item) => item['id']?.toString() == filterId,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa bộ lọc: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          mutatingFilterIds.remove(filterId);
        });
      }
    }
  }

  Future<void> _toggleFilter(
    Map<String, dynamic> filter,
    bool enabled,
  ) async {
    final filterId = filter['id']?.toString() ?? '';

    if (filterId.isEmpty) {
      return;
    }

    if (mutatingFilterIds.contains(filterId)) {
      return;
    }

    final previous = filter['enabled'] != false;

    setState(() {
      mutatingFilterIds.add(filterId);
      filter['enabled'] = enabled;
    });

    try {
      final saved = await backend.updateNotificationFilter(
        filterId,
        {
          ...filter,
          'enabled': enabled,
        },
      );

      if (!mounted) {
        return;
      }

      final index = filters.indexWhere(
        (item) => item['id']?.toString() == filterId,
      );

      if (index >= 0) {
        setState(() {
          filters[index] = saved;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        filter['enabled'] = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật bộ lọc: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          mutatingFilterIds.remove(filterId);
        });
      }
    }
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
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : filterCount == 0
                          ? _buildEmptyState(context)
                          : _buildFilterList(context),
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
  // ========================================

  Widget _buildFilterList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _loadFilters,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final filter = filters[index];

          final enabled = filter['enabled'] != false;

          final filterId = filter['id']?.toString() ?? '';

          final updating =
              filterId.isNotEmpty &&
              mutatingFilterIds.contains(filterId);

          final mode = filter['mode']?.toString() == 'advanced'
              ? 'Nâng cao'
              : 'Cơ bản';

          final groupIds = filter['groupIds'];

          final groupCount = groupIds is List ? groupIds.length : 0;

          final groupText = groupCount == 0
              ? 'Tất cả các nhóm'
              : '$groupCount nhóm';

          return Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    enabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                    color: enabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filter['name']?.toString() ?? 'Bộ lọc',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$mode • $groupText',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: updating
                        ? null
                        : (value) {
                            _toggleFilter(filter, value);
                          },
                  ),
                  PopupMenuButton<String>(
                    enabled: !updating,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editFilter(filter);
                        return;
                      }

                      if (value == 'delete') {
                        _deleteFilter(filter);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Sửa'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 10),
                            Text('Xóa'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
