import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final BackendService backend = BackendService(
    baseUrl: AppConfig.backendUrl,
  );

  final TextEditingController searchController =
      TextEditingController();

  final Set<String> processing = <String>{};

  List<Map<String, dynamic>> messages =
      <Map<String, dynamic>>[];

  List<Map<String, dynamic>> groups =
      <Map<String, dynamic>>[];

  bool loading = true;

  DateTime? selectedDate;

  String? selectedGroupId;

  Timer? searchDebounce;

  int loadGeneration = 0;

  @override
  void initState() {
    super.initState();

    searchController.addListener(
      _handleSearchChanged,
    );

    unawaited(
      _initialize(),
    );
  }

  Future<void> _initialize() async {
    await Future.wait<void>([
      loadGroups(),
      loadMessages(),
    ]);
  }

  void _handleSearchChanged() {
    searchDebounce?.cancel();

    searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted) {
          return;
        }

        unawaited(
          loadMessages(),
        );
      },
    );
  }

  Future<void> loadGroups() async {
    try {
      final result =
          await backend.getGroups();

      if (!mounted) {
        return;
      }

      result.sort(
        (a, b) {
          final aName =
              a['name']
                  ?.toString()
                  .toLowerCase() ??
              '';

          final bName =
              b['name']
                  ?.toString()
                  .toLowerCase() ??
              '';

          return aName.compareTo(
            bName,
          );
        },
      );

      setState(() {
        groups = result;
      });
    } catch (_) {
      // History van dung duoc neu danh sach nhom
      // tam thoi khong tai duoc.
    }
  }

  DateTime? get _filterFrom {
    final date = selectedDate;

    if (date == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  DateTime? get _filterTo {
    final date = selectedDate;

    if (date == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );
  }

  Future<void> loadMessages() async {
    final generation =
        ++loadGeneration;

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final result =
          await backend.getMessages(
        limit: 500,
        from: _filterFrom,
        to: _filterTo,
        groupId: selectedGroupId,
        query: searchController.text,
      );

      if (
        !mounted ||
        generation != loadGeneration
      ) {
        return;
      }

      setState(() {
        messages = result;
      });
    } catch (error) {
      if (
        !mounted ||
        generation != loadGeneration
      ) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải lịch sử: $error',
          ),
        ),
      );
    } finally {
      if (
        mounted &&
        generation == loadGeneration
      ) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final initial =
        selectedDate ??
        DateTime.now();

    final picked =
        await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (
      picked == null ||
      !mounted
    ) {
      return;
    }

    setState(() {
      selectedDate = picked;
    });

    await loadMessages();
  }

  Future<void> _setGroup(
    String? groupId,
  ) async {
    setState(() {
      selectedGroupId =
          groupId;
    });

    await loadMessages();
  }

  Future<void> _clearFilters() async {
    searchDebounce?.cancel();

    searchController.clear();

    setState(() {
      selectedDate = null;
      selectedGroupId = null;
    });

    await loadMessages();
  }

  bool get hasFilters =>
      selectedDate != null ||
      selectedGroupId != null ||
      searchController.text
          .trim()
          .isNotEmpty;

  String _groupName(
    String? groupId,
  ) {
    if (
      groupId == null ||
      groupId.isEmpty
    ) {
      return 'Tất cả nhóm';
    }

    for (
      final group in groups
    ) {
      if (
        group['groupId']
                ?.toString() ==
            groupId
      ) {
        return group['name']
                ?.toString() ??
            'Nhóm Zalo';
      }
    }

    return 'Nhóm Zalo';
  }

  Future<void> accept(
    Map<String, dynamic> message,
  ) async {
    final id =
        message['id']
            ?.toString();

    if (
      id == null ||
      processing.contains(id)
    ) {
      return;
    }

    setState(() {
      processing.add(id);
    });

    try {
      await backend.acceptMessage(id);

      if (!mounted) {
        return;
      }

      await loadMessages();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã nhận cuốc',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          processing.remove(id);
        });
      }
    }
  }

  Future<void> ignore(
    Map<String, dynamic> message,
  ) async {
    final id =
        message['id']
            ?.toString();

    if (
      id == null ||
      processing.contains(id)
    ) {
      return;
    }

    setState(() {
      processing.add(id);
    });

    try {
      await backend.ignoreMessage(id);

      if (!mounted) {
        return;
      }

      await loadMessages();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã bỏ qua cuốc',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          processing.remove(id);
        });
      }
    }
  }

  String statusText(
    String status,
  ) {
    switch (status) {
      case 'accepted':
        return 'Đã nhận';

      case 'ignored':
        return 'Bỏ qua';

      default:
        return 'Mới';
    }
  }

  IconData statusIcon(
    String status,
  ) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_rounded;

      case 'ignored':
        return Icons.block_rounded;

      default:
        return Icons.fiber_new_rounded;
    }
  }

  Color statusColor(
    BuildContext context,
    String status,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    switch (status) {
      case 'accepted':
        return Colors.green;

      case 'ignored':
        return colorScheme.error;

      default:
        return colorScheme.primary;
    }
  }

  String formatDateTime(
    dynamic rawValue,
  ) {
    if (rawValue == null) {
      return '—';
    }

    final date =
        DateTime.tryParse(
      rawValue.toString(),
    );

    if (date == null) {
      return '—';
    }

    final local =
        date.toLocal();

    String twoDigits(
      int value,
    ) =>
        value
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year}  '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  String formatDateOnly(
    DateTime date,
  ) {
    String twoDigits(
      int value,
    ) =>
        value
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}';
  }

  Widget _filterBar(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        TextField(
          controller: searchController,
          textInputAction:
              TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                'Tìm theo nội dung cuốc...',
            prefixIcon:
                const Icon(
              Icons.search_rounded,
            ),
            suffixIcon:
                searchController.text
                        .isNotEmpty
                    ? IconButton(
                        tooltip:
                            'Xóa tìm kiếm',
                        onPressed: () {
                          searchController
                              .clear();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      )
                    : null,
            border:
                const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            searchDebounce?.cancel();

            unawaited(
              loadMessages(),
            );
          },
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(
                  Icons.calendar_today_outlined,
                ),
                label: Text(
                  selectedDate == null
                      ? 'Tất cả ngày'
                      : formatDateOnly(
                          selectedDate!,
                        ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: PopupMenuButton<String?>(
                tooltip: 'Lọc theo nhóm',
                onSelected: (value) {
                  unawaited(
                    _setGroup(value),
                  );
                },
                itemBuilder: (context) {
                  final items =
                      <PopupMenuEntry<String?>>[
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Tất cả nhóm',
                      ),
                    ),
                  ];

                  for (
                    final group
                    in groups
                  ) {
                    final id =
                        group['groupId']
                            ?.toString();

                    if (
                      id == null ||
                      id.isEmpty
                    ) {
                      continue;
                    }

                    items.add(
                      PopupMenuItem<String?>(
                        value: id,
                        child: Text(
                          group['name']
                                  ?.toString() ??
                              'Nhóm Zalo',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }

                  return items;
                },
                child: Container(
                  height: 48,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          colorScheme.outline,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          _groupName(
                            selectedGroupId,
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),

                      const Icon(
                        Icons.arrow_drop_down,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (hasFilters) ...[
          const SizedBox(height: 8),

          Align(
            alignment:
                Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                unawaited(
                  _clearFilters(),
                );
              },
              icon: const Icon(
                Icons.filter_alt_off_outlined,
              ),
              label: const Text(
                'Xóa bộ lọc',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty
                  ? '—'
                  : value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(
    BuildContext context,
    Map<String, dynamic> message,
  ) {
    final status =
        message['status']
                ?.toString() ??
            'new';

    final id =
        message['id']
            ?.toString();

    final busy =
        id != null &&
        processing.contains(id);

    final statusTone =
        statusColor(
      context,
      status,
    );

    final sender =
        message['senderName']
                ?.toString()
                .trim() ??
            '';

    final senderFallback =
        message['senderId']
                ?.toString()
                .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon(status),
                  color: statusTone,
                ),

                const SizedBox(width: 8),

                Text(
                  statusText(status),
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color: statusTone,
                  ),
                ),

                const Spacer(),

                Text(
                  formatDateTime(
                    message['receivedAt'],
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              message['content']
                      ?.toString() ??
                  '',
              style: const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            _infoRow(
              icon:
                  Icons.schedule_outlined,
              label: 'Nhận lúc',
              value: formatDateTime(
                message['receivedAt'],
              ),
            ),

            _infoRow(
              icon:
                  Icons.groups_outlined,
              label: 'Nhóm',
              value:
                  message['groupName']
                          ?.toString() ??
                      'Nhóm Zalo',
            ),

            _infoRow(
              icon:
                  Icons.person_outline,
              label: 'Người gửi',
              value: sender.isNotEmpty
                  ? sender
                  : senderFallback,
            ),

            _infoRow(
              icon:
                  Icons.flag_outlined,
              label: 'Trạng thái',
              value:
                  statusText(status),
            ),

            if (
              status == 'accepted' &&
              message['acceptedAt'] !=
                  null
            )
              _infoRow(
                icon:
                    Icons.check_circle_outline,
                label: 'Nhận cuốc',
                value: formatDateTime(
                  message['acceptedAt'],
                ),
              ),

            if (
              status == 'ignored' &&
              message['ignoredAt'] !=
                  null
            )
              _infoRow(
                icon:
                    Icons.block_outlined,
                label: 'Bỏ qua',
                value: formatDateTime(
                  message['ignoredAt'],
                ),
              ),

            if (status == 'new') ...[
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              unawaited(
                                ignore(
                                  message,
                                ),
                              );
                            },
                      icon: const Icon(
                        Icons.close,
                      ),
                      label:
                          const Text(
                        'BỎ QUA',
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child:
                        FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              unawaited(
                                accept(
                                  message,
                                ),
                              );
                            },
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons.local_taxi,
                            ),
                      label:
                          const Text(
                        'NHẬN',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchDebounce?.cancel();

    searchController
        .removeListener(
      _handleSearchChanged,
    );

    searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadMessages,
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          padding:
              const EdgeInsets.all(
            20,
          ),
          children: [
            const Text(
              'Lịch sử nhận',
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              loading
                  ? 'Đang tải lịch sử...'
                  : '${messages.length} kết quả',
            ),

            const SizedBox(height: 18),

            _filterBar(context),

            const SizedBox(height: 16),

            if (loading)
              const LinearProgressIndicator(),

            if (
              !loading &&
              messages.isEmpty
            )
              const Padding(
                padding:
                    EdgeInsets.only(
                  top: 90,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                      ),

                      SizedBox(height: 14),

                      Text(
                        'Không có cuốc phù hợp',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        'Thử thay đổi ngày, nhóm hoặc nội dung tìm kiếm.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...messages.map(
                (message) =>
                    _historyCard(
                  context,
                  message,
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
