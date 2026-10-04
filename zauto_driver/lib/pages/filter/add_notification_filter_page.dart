import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/backend_service.dart';

enum _FilterMode { basic, advanced }

class AddNotificationFilterPage extends StatefulWidget {
  final Map<String, dynamic>? initialFilter;

  const AddNotificationFilterPage({
    super.key,
    this.initialFilter,
  });

  @override
  State<AddNotificationFilterPage> createState() =>
      _AddNotificationFilterPageState();
}

class _AddNotificationFilterPageState extends State<AddNotificationFilterPage> {
  static const int maxNameLength = 255;

  bool get isEditing => widget.initialFilter != null;

  String get editingFilterId =>
      widget.initialFilter?['id']?.toString() ?? '';

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  final Set<String> selectedGroupIds = {};

  final Map<String, String> selectedGroupNames = {};

  bool saving = false;

  final TextEditingController nameController = TextEditingController();

  final TextEditingController pickupController = TextEditingController();

  final TextEditingController dropoffController = TextEditingController();

  final TextEditingController includeController = TextEditingController();

  final TextEditingController excludeController = TextEditingController();

  final TextEditingController minimumPriceController = TextEditingController();

  final TextEditingController timeController = TextEditingController();

  _FilterMode mode = _FilterMode.basic;

  bool acceptBothDirections = false;

  // ========================================
  // ADVANCED MODE STATE
  // ========================================

  final List<String> advancedShowKeywords = [];

  final List<String> advancedHideKeywords = [];

  @override
  void initState() {
    super.initState();

    _populateInitialFilter();

    nameController.addListener(_handleNameChanged);
  }

  void _populateInitialFilter() {
    final filter = widget.initialFilter;

    if (filter == null) {
      return;
    }

    nameController.text = filter['name']?.toString() ?? '';

    mode = filter['mode']?.toString() == 'advanced'
        ? _FilterMode.advanced
        : _FilterMode.basic;

    final groupIds = filter['groupIds'];

    if (groupIds is List) {
      selectedGroupIds.addAll(
        groupIds
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty),
      );
    }

    final basic = filter['basic'];

    if (basic is Map) {
      pickupController.text = basic['pickup']?.toString() ?? '';
      dropoffController.text = basic['dropoff']?.toString() ?? '';
      includeController.text = basic['includeKeywords']?.toString() ?? '';
      excludeController.text = basic['excludeKeywords']?.toString() ?? '';
      timeController.text = basic['timeRules']?.toString() ?? '';

      acceptBothDirections = basic['acceptBothDirections'] == true;

      final minimumPrice = basic['minimumPrice'];

      minimumPriceController.text =
          minimumPrice == null ? '' : minimumPrice.toString();
    }

    final advanced = filter['advanced'];

    if (advanced is Map) {
      final showKeywords = advanced['showKeywords'];

      if (showKeywords is List) {
        advancedShowKeywords.addAll(
          showKeywords
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty),
        );
      }

      final hideKeywords = advanced['hideKeywords'];

      if (hideKeywords is List) {
        advancedHideKeywords.addAll(
          hideKeywords
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty),
        );
      }
    }
  }

  void _handleNameChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Map<String, dynamic> _buildFilterPayload() {
    final rawPrice = minimumPriceController.text.trim();

    final minimumPrice = rawPrice.isEmpty ? null : num.tryParse(rawPrice);

    return {
      'name': nameController.text.trim(),
      'mode': mode == _FilterMode.advanced ? 'advanced' : 'basic',
      'enabled': widget.initialFilter?['enabled'] != false,
      'groupIds': selectedGroupIds.toList(),
      'basic': {
        'pickup': pickupController.text.trim(),
        'dropoff': dropoffController.text.trim(),
        'acceptBothDirections': acceptBothDirections,
        'includeKeywords': includeController.text.trim(),
        'excludeKeywords': excludeController.text.trim(),
        'minimumPrice': minimumPrice,
        'timeRules': timeController.text.trim(),
      },
      'advanced': {
        'showKeywords': List<String>.from(advancedShowKeywords),
        'hideKeywords': List<String>.from(advancedHideKeywords),
      },
    };
  }

  Future<void> _checkFilter() async {
    final messageController = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kiểm tra bộ lọc'),
          content: TextField(
            controller: messageController,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Dán một tin nhắn cuốc để kiểm tra...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  messageController.text.trim(),
                );
              },
              child: const Text('KIỂM TRA'),
            ),
          ],
        );
      },
    );

    messageController.dispose();

    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    try {
      final result = await backend.previewNotificationFilter(
        filter: _buildFilterPayload(),
        messageText: message,
        groupId: selectedGroupIds.length == 1
            ? selectedGroupIds.first
            : null,
      );

      if (!mounted) {
        return;
      }

      final matched = result['matched'] == true;

      final reason = result['reason']?.toString() ?? '';

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            icon: Icon(
              matched
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: matched
                  ? colorScheme.primary
                  : colorScheme.error,
              size: 44,
            ),
            title: Text(
              matched
                  ? 'Tin nhắn sẽ được nhận'
                  : 'Tin nhắn sẽ bị bỏ qua',
            ),
            content: reason.isEmpty
                ? null
                : Text('Kết quả: $reason'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ĐÓNG'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể kiểm tra bộ lọc: $error')),
      );
    }
  }

  Future<void> _saveFilter() async {
    if (saving) {
      return;
    }

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bộ lọc.')),
      );

      return;
    }

    final rawPrice = minimumPriceController.text.trim();

    if (rawPrice.isNotEmpty && num.tryParse(rawPrice) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giá tối thiểu phải là một số hợp lệ.'),
        ),
      );

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      late final Map<String, dynamic> saved;

      if (isEditing) {
        if (editingFilterId.isEmpty) {
          throw Exception('Bộ lọc cần chỉnh sửa không có ID hợp lệ.');
        }

        saved = await backend.updateNotificationFilter(
          editingFilterId,
          _buildFilterPayload(),
        );
      } else {
        saved = await backend.createNotificationFilter(
          _buildFilterPayload(),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu bộ lọc: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _openGroupSelector() async {
    List<Map<String, dynamic>> groups;

    try {
      groups = await backend.getGroups();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải danh sách nhóm: $error')),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    final draft = Set<String>.from(selectedGroupIds);

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Text(
                        'Chọn nhóm áp dụng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: draft.isEmpty,
                      title: const Text('Tất cả các nhóm'),
                      subtitle: const Text(
                        'Bộ lọc áp dụng cho mọi nhóm đang bật theo dõi.',
                      ),
                      onChanged: (_) {
                        setSheetState(() {
                          draft.clear();
                        });
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];

                          final groupId =
                              group['groupId']?.toString() ?? '';

                          final name =
                              group['name']?.toString() ?? groupId;

                          if (groupId.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return CheckboxListTile(
                            value: draft.contains(groupId),
                            title: Text(name),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  draft.add(groupId);
                                } else {
                                  draft.remove(groupId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(draft);
                          },
                          child: const Text('XONG'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final names = <String, String>{};

    for (final group in groups) {
      final groupId = group['groupId']?.toString() ?? '';

      if (selected.contains(groupId)) {
        names[groupId] = group['name']?.toString() ?? groupId;
      }
    }

    setState(() {
      selectedGroupIds
        ..clear()
        ..addAll(selected);

      selectedGroupNames
        ..clear()
        ..addAll(names);
    });
  }

  void _showModeInfo(_FilterMode targetMode) {
    if (targetMode == _FilterMode.basic) {
      _showBasicKeywordHelp();

      return;
    }

    _showAdvancedFilterHelp();
  }

  Future<void> _showBasicKeywordHelp() async {
    await showDialog<void>(
      context: context,

      barrierDismissible: true,

      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        final screenHeight = MediaQuery.sizeOf(dialogContext).height;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 34,
          ),

          backgroundColor: colorScheme.surface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),

          clipBehavior: Clip.antiAlias,

          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: screenHeight * 0.86,
            ),

            child: Column(
              children: [
                // ========================================
                // FIXED HEADER
                // ========================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),

                  child: Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      'Cách viết từ khoá',

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),

                // ========================================
                // ONLY THIS PART SCROLLS
                // ========================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),

                    children: [
                      Text(
                        'Mỗi ô nhận nhiều từ khoá, ngăn nhau bởi dấu phẩy. '
                        'Tin nhắn khớp MỘT từ khoá bất kỳ là đủ.',

                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 18),

                      _keywordExample(context, 'hà nội, hn'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Dấu phẩy là HOẶC — khớp một từ khoá là đủ.',
                      ),

                      const SizedBox(height: 20),

                      _keywordExample(context, 'tân'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Không có dấu sao thì khớp TRỌN TỪ: '
                        '"tân" không khớp "tặng", '
                        '"4c" không khớp "4cho".',
                      ),

                      const SizedBox(height: 20),

                      _keywordExample(context, '500'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Từ khoá chỉ có số khớp luôn cả khi đi kèm đơn vị tiền: '
                        '"500" khớp "500k", "500 nghìn". '
                        'Vẫn không khớp "1500".',
                      ),

                      const SizedBox(height: 20),

                      _keywordExample(context, '*tân*'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Hai dấu sao khớp MỘT PHẦN của từ, lỏng hơn. '
                        '"*500*" khớp "500k", "1500".',
                      ),

                      const SizedBox(height: 20),

                      _keywordExample(context, '*(nội bài|nb)*'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Gom nhiều cách viết của cùng một chỗ. '
                        'Dấu | là HOẶC.',
                      ),

                      const SizedBox(height: 20),

                      _keywordExample(context, '*(quận 1)*(nội bài)*'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Hai phần phải xuất hiện ĐÚNG THỨ TỰ này trong tin nhắn.',
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'Lưu ý',

                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _keywordNote(context, 'Không phân biệt hoa thường.'),

                      _keywordNote(
                        context,
                        'Không phân biệt có dấu hay không: '
                        'gõ "quan 1" vẫn khớp "Quận 1".',
                      ),

                      _keywordNote(
                        context,
                        'Từ khoá loại trừ THẮNG từ khoá nhận: '
                        'tin nhắn dính một từ khoá loại trừ là bị bỏ, '
                        'dù có khớp bao nhiêu từ khoá nhận đi nữa.',
                      ),
                    ],
                  ),
                ),

                // ========================================
                // FIXED BUTTON
                // ========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),

                  child: SizedBox(
                    width: double.infinity,

                    height: 58,

                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },

                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      child: const Text(
                        'Đã hiểu',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAdvancedFilterHelp() async {
    await showDialog<void>(
      context: context,

      barrierDismissible: true,

      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        final screenHeight = MediaQuery.sizeOf(dialogContext).height;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 34,
          ),

          backgroundColor: colorScheme.surface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),

          clipBehavior: Clip.antiAlias,

          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: screenHeight * 0.86,
            ),

            child: Column(
              children: [
                // ========================================
                // FIXED HEADER
                // ========================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),

                  child: Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      'Hướng dẫn Lọc thông báo',

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),

                // ========================================
                // ONLY CONTENT SCROLLS
                // ========================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),

                    children: [
                      _helpSectionTitle(
                        context,
                        'Hiện thông báo với các từ khoá',
                      ),

                      const SizedBox(height: 12),

                      _helpBullet(
                        context,
                        'Chỉ hiển thị thông báo chứa ít nhất 1 từ khoá',
                      ),

                      _helpBullet(
                        context,
                        'Nếu từ khoá trống = hiển thị tất cả thông báo',
                      ),

                      const SizedBox(height: 24),

                      // ==================================
                      // HIDE KEYWORDS
                      // ==================================
                      _helpSectionTitle(
                        context,
                        'Ẩn thông báo với các từ khoá',
                      ),

                      const SizedBox(height: 12),

                      _helpBullet(
                        context,
                        'Ẩn thông báo chứa bất kỳ từ khoá nào trong danh sách',
                      ),

                      _helpBullet(
                        context,
                        'Ưu tiên cao hơn "Hiện thông báo" - từ khoá ẩn sẽ ghi đè',
                      ),

                      const SizedBox(height: 26),

                      // ==================================
                      // WILDCARDS
                      // ==================================
                      _helpSectionTitle(context, 'Ký tự đại diện (Wildcards)'),

                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _keywordExample(context, '*'),

                          const SizedBox(width: 16),

                          Expanded(
                            child: _keywordDescription(
                              context,
                              'Đặt ở HAI ĐẦU cả cụm để khớp MỘT PHẦN — '
                              'không dùng chèn giữa từ',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _helpBullet(
                        context,
                        'Ví dụ: "*cuoc*" → khớp "cuoc", "cuoc di", "nhan cuoc"',
                      ),

                      _helpBullet(context, 'Không phân biệt hoa thường'),

                      const SizedBox(height: 28),

                      // ==================================
                      // TIPS
                      // ==================================
                      _helpSectionTitle(context, 'Mẹo sử dụng'),

                      const SizedBox(height: 12),

                      _helpBullet(
                        context,
                        'Từ khoá có cấu trúc:\n'
                        '"*(từ khoá 1 | từ khoá 2)*"',
                      ),

                      _helpBullet(context, 'Giải thích:'),

                      _helpSubBullet(
                        context,
                        '| là để phân tách giữa các từ khoá',
                      ),

                      _helpSubBullet(context, '*()* là CỤM chứa các từ khoá.'),

                      const SizedBox(height: 8),

                      _helpBullet(context, 'Từ khoá:'),

                      _helpSubBullet(context, 'sẽ được hiểu ở dạng không dấu.'),

                      _helpSubBullet(
                        context,
                        'không phân biệt viết hoa, viết thường.',
                      ),
                    ],
                  ),
                ),

                // ========================================
                // BUTTON CO DINH
                // ========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),

                  child: SizedBox(
                    width: double.infinity,

                    height: 58,

                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },

                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      child: const Text(
                        'Đã hiểu',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _keywordExample(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),

          borderRadius: BorderRadius.circular(7),
        ),

        child: Text(
          text,

          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _keywordDescription(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      text,

      style: TextStyle(
        fontSize: 14.5,
        height: 1.45,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _keywordNote(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),

            child: Text(
              '•',

              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: Text(
              text,

              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpSectionTitle(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      text,

      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _helpBullet(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 9),

            child: Text(
              '•',

              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: Text(
              text,

              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpSubBullet(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),

            child: Text(
              '•',

              style: TextStyle(
                fontSize: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: Text(
              text,

              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeInfo() {
    showDialog<void>(
      context: context,

      barrierDismissible: true,

      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        final screenHeight = MediaQuery.sizeOf(dialogContext).height;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 34,
          ),

          backgroundColor: colorScheme.surface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),

          clipBehavior: Clip.antiAlias,

          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: screenHeight * 0.86,
            ),

            child: Column(
              children: [
                // ========================================
                // FIXED HEADER
                // KHONG CUON
                // ========================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),

                  child: Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      'Cách viết Khung giờ',

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

                Divider(
                  height: 1,

                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),

                // ========================================
                // CHI NOI DUNG NAY DUOC CUON
                // ========================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),

                    children: [
                      Text(
                        'Ô này nhận nhiều khung, ngăn nhau bởi dấu phẩy. '
                        'Cuốc khớp MỘT khung bất kỳ là đủ, kể cả khi hai '
                        'khung khác loại đứng cạnh nhau '
                        '(VD "sáng, 0-30p").',

                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================
                      // GIO TRONG NGAY
                      // ==================================
                      _helpSectionTitle(context, 'Giờ trong ngày'),

                      const SizedBox(height: 16),

                      _keywordExample(context, 'sáng, chiều, tối'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Buổi trong ngày — sáng 05:00–11:00, '
                        'trưa 11:00–13:00, chiều 13:00–18:00, '
                        'tối 18:00–23:00, đêm/khuya 22:00–04:00 '
                        '(qua đêm).',
                      ),

                      const SizedBox(height: 22),

                      _keywordExample(context, '6h-8h'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Khoảng giờ tường minh. Viết được cả '
                        '"6-8", "06:00-08:00".',
                      ),

                      const SizedBox(height: 22),

                      _keywordExample(context, 'sau 22h'),

                      const SizedBox(height: 8),

                      _keywordDescription(context, 'Từ mốc đó tới hết ngày.'),

                      const SizedBox(height: 22),

                      _keywordExample(context, 'trước 6h'),

                      const SizedBox(height: 8),

                      _keywordDescription(context, 'Từ đầu ngày tới mốc đó.'),

                      const SizedBox(height: 20),

                      _helpBullet(
                        context,
                        'So khớp GIAO NHAU với giờ tin nhắn nói ra, '
                        'không cần khớp y hệt — tin "tối nay" '
                        '(18h–23h) chạm khung "sau 20h" là đủ.',
                      ),

                      _helpBullet(
                        context,
                        'Tin không ghi giờ thì KHÔNG khớp nếu ô này '
                        'có điền gì — để trống ô mới nhận cả loại tin '
                        'không ghi giờ.',
                      ),

                      const SizedBox(height: 26),

                      // ==================================
                      // SO PHUT NHAC TRONG TIN
                      // ==================================
                      _helpSectionTitle(
                        context,
                        'Số phút nhắc trong tin (cuốc gấp)',
                      ),

                      const SizedBox(height: 16),

                      _keywordExample(context, '0-30p'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Khớp khi CHÍNH TIN NHẮN có ghi một số phút '
                        'từ 0 đến 30 — VD "gấp 15p", "0-15", '
                        '"15ph", "15 phút" — dùng để bắt cuốc gấp.',
                      ),

                      const SizedBox(height: 22),

                      _keywordExample(context, '15p'),

                      const SizedBox(height: 8),

                      _keywordDescription(context, 'Viết tắt của "0-15p".'),

                      const SizedBox(height: 18),

                      _helpBullet(
                        context,
                        'Đọc THẲNG số phút mà tin nhắn tự viết ra, '
                        'không tính theo giờ tin được gửi tới nhóm.',
                      ),

                      _helpBullet(
                        context,
                        'Tin ghi nhiều số phút thì khớp một số nằm '
                        'trong khung là đủ.',
                      ),

                      const SizedBox(height: 26),

                      // ==================================
                      // TU KHOA TU DO
                      // ==================================
                      _helpSectionTitle(context, 'Từ khoá tự do'),

                      const SizedBox(height: 16),

                      _keywordExample(context, 'csct'),

                      const SizedBox(height: 8),

                      _keywordDescription(
                        context,
                        'Gõ gì mà không hiểu được thành khung giờ '
                        'hay khung phút thì coi như một TỪ KHOÁ — '
                        'tin chứa đúng chữ đó là khớp. '
                        'VD "csct" = "càng sớm càng tốt".',
                      ),
                    ],
                  ),
                ),

                // ========================================
                // FIXED BOTTOM BUTTON
                // KHONG CUON
                // ========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),

                  child: SizedBox(
                    width: double.infinity,

                    height: 58,

                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },

                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      child: const Text(
                        'Đã hiểu',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addQuickTime(String value) {
    final rule = switch (value) {
      'cả ngày 6h-22h' => '6h-22h',
      'gấp — trong 15p' => '15p',
      'trong 30p' => '0-30p',
      _ => value,
    };

    final current = timeController.text.trim();

    if (current.isEmpty) {
      timeController.text = rule;
    } else {
      final values = current
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (!values.contains(rule)) {
        values.add(rule);
      }

      timeController.text = values.join(', ');
    }

    timeController.selection = TextSelection.collapsed(
      offset: timeController.text.length,
    );

    setState(() {});
  }

  Future<void> _addAdvancedKeyword({required bool showKeyword}) async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            showKeyword ? 'Thêm từ khoá hiển thị' : 'Thêm từ khoá ẩn',
          ),

          content: TextField(
            controller: controller,

            autofocus: true,

            textInputAction: TextInputAction.done,

            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },

            decoration: const InputDecoration(
              hintText: 'Nhập từ khoá...',

              border: OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: const Text('HỦY'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },

              child: const Text('THÊM'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || value == null || value.trim().isEmpty) {
      return;
    }

    final keyword = value.trim();

    final target = showKeyword ? advancedShowKeywords : advancedHideKeywords;

    if (target.contains(keyword)) {
      return;
    }

    setState(() {
      target.add(keyword);
    });
  }

  void _removeAdvancedKeyword({
    required bool showKeyword,
    required String keyword,
  }) {
    setState(() {
      final target = showKeyword ? advancedShowKeywords : advancedHideKeywords;

      target.remove(keyword);
    });
  }

  void _showAdvancedUiNotice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildAdvancedKeywordSection(
    BuildContext context, {
    required bool showKeyword,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final keywords = showKeyword ? advancedShowKeywords : advancedHideKeywords;

    final title = showKeyword
        ? 'Hiện thông báo với các từ khoá'
        : 'Ẩn thông báo với các từ khoá';

    final chipBackground = showKeyword
        ? Colors.green.withValues(alpha: 0.10)
        : Colors.red.withValues(alpha: 0.08);

    final chipForeground = showKeyword
        ? Colors.green.shade700
        : colorScheme.error;

    final actionBackground = showKeyword
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        // ========================================
        // TITLE + ACTION BUTTONS
        // ========================================

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            Expanded(
              child: Text(
                title,

                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            _buildAdvancedRoundButton(
              context,

              icon: Icons.bookmark_add_outlined,

              backgroundColor: actionBackground,

              tooltip: 'Từ khoá đã lưu',

              onTap: () {
                _showAdvancedUiNotice(
                  'Danh sách từ khoá đã lưu sẽ được thêm sau.',
                );
              },
            ),

            const SizedBox(width: 10),

            _buildAdvancedRoundButton(
              context,

              icon: Icons.list_alt_rounded,

              backgroundColor: actionBackground,

              tooltip: 'Danh sách từ khoá',

              onTap: () {
                _showAdvancedUiNotice(
                  'Quản lý danh sách từ khoá sẽ được thêm sau.',
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ========================================
        // CHIPS + ADD BUTTON
        // ========================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,

                children: keywords.map((keyword) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 7, 8),

                    decoration: BoxDecoration(
                      color: chipBackground,

                      borderRadius: BorderRadius.circular(22),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Text(
                          keyword,

                          style: TextStyle(fontSize: 14, color: chipForeground),
                        ),

                        const SizedBox(width: 6),

                        InkWell(
                          borderRadius: BorderRadius.circular(20),

                          onTap: () {
                            _removeAdvancedKeyword(
                              showKeyword: showKeyword,

                              keyword: keyword,
                            );
                          },

                          child: Padding(
                            padding: const EdgeInsets.all(3),

                            child: Icon(
                              Icons.close_rounded,

                              size: 21,

                              color: chipForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(width: 12),

            _buildAdvancedRoundButton(
              context,

              icon: Icons.add_rounded,

              backgroundColor: actionBackground,

              tooltip: 'Thêm từ khoá',

              onTap: () {
                _addAdvancedKeyword(showKeyword: showKeyword);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedRoundButton(
    BuildContext context, {
    required IconData icon,
    required Color backgroundColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,

      child: Material(
        color: backgroundColor,

        shape: const CircleBorder(),

        clipBehavior: Clip.antiAlias,

        child: InkWell(
          onTap: onTap,

          customBorder: const CircleBorder(),

          child: SizedBox(
            width: 54,
            height: 54,

            child: Icon(icon, size: 27, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.removeListener(_handleNameChanged);

    nameController.dispose();
    pickupController.dispose();
    dropoffController.dispose();
    includeController.dispose();
    excludeController.dispose();
    minimumPriceController.dispose();
    timeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      appBar: AppBar(
        toolbarHeight: 86,

        centerTitle: true,

        leadingWidth: 64,

        leading: IconButton(
          tooltip: 'Quay lại',

          icon: const Icon(Icons.arrow_back_rounded, size: 32),

          onPressed: () {
            Navigator.of(context).pop();
          },
        ),

        title: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              isEditing ? 'Chỉnh sửa bộ lọc' : 'Thêm bộ lọc mới',

              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 2),

            const Text(
              'Lọc thông báo',

              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),

          child: Divider(
            height: 1,

            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),

      body: SafeArea(
        top: false,

        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              // ========================================
              // TEN BO LOC
              // ========================================

              _buildSectionLabel(context, 'Tên bộ lọc', required: true),

              const SizedBox(height: 8),

              TextField(
                controller: nameController,

                style: const TextStyle(fontSize: 15),

                maxLength: maxNameLength,

                textInputAction: TextInputAction.next,

                decoration: _inputDecoration(
                  context,

                  hint: 'VD: Sân bay ca sáng, Nội thành ca đêm',
                ),
              ),

              const SizedBox(height: 22),

              // ========================================
              // CHE DO
              // ========================================
              _buildSectionLabel(context, 'Chế độ'),

              const SizedBox(height: 8),

              _buildModeOption(
                context,

                mode: _FilterMode.basic,

                title: 'Cơ bản',
              ),

              _buildModeOption(
                context,

                mode: _FilterMode.advanced,

                title: 'Nâng cao',
              ),

              if (mode == _FilterMode.basic) ...[
                const SizedBox(height: 26),

                // ========================================
                // DIEM DON
                // ========================================
                _buildSectionLabel(context, 'Điểm đón'),

                const SizedBox(height: 8),

                _buildLargeField(
                  context,

                  controller: pickupController,

                  hint: 'VD: hà nội, hn, ben thanh',
                ),

                const SizedBox(height: 24),

                // ========================================
                // DIEM TRA
                // ========================================
                _buildSectionLabel(context, 'Điểm trả'),

                const SizedBox(height: 8),

                _buildLargeField(
                  context,

                  controller: dropoffController,

                  hint: 'VD: tan son nhat, sân bay',
                ),

                const SizedBox(height: 20),

                // ========================================
                // HAI CHIEU
                // ========================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Nhận cả hai chiều',

                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            'Tắt thì chỉ nhận cuốc chạy đúng chiều đón → trả, '
                            'và bỏ qua cuốc hai chiều.',

                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    Switch(
                      value: acceptBothDirections,

                      onChanged: (value) {
                        setState(() {
                          acceptBothDirections = value;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ========================================
                // INCLUDE
                // ========================================
                _buildSectionLabel(context, 'Nhận nếu chứa từ khoá'),

                const SizedBox(height: 8),

                _buildLargeField(
                  context,

                  controller: includeController,

                  hint: 'VD: 4 chỗ, xe 4c, 500',
                ),

                const SizedBox(height: 26),

                // ========================================
                // EXCLUDE
                // ========================================
                _buildSectionLabel(context, 'Bỏ qua nếu chứa từ khoá'),

                const SizedBox(height: 8),

                _buildLargeField(
                  context,

                  controller: excludeController,

                  hint: 'VD: ghép, hàng cồng kềnh',
                ),

                const SizedBox(height: 28),

                // ========================================
                // MIN PRICE
                // ========================================
                _buildSectionLabel(context, 'Giá tối thiểu (nghìn đồng)'),

                const SizedBox(height: 6),

                Text(
                  'Đọc được cả “300” lẫn “300k”, “1tr2”, “500.000”. '
                  'Tin không ghi giá sẽ KHÔNG khớp. '
                  'Để trống = không lọc theo giá.',

                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,

                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 12),

                _buildSingleField(
                  context,

                  controller: minimumPriceController,

                  hint: 'VD: 500 (= 500k)',

                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 28),

                // ========================================
                // TIME
                // ========================================
                Row(
                  children: [
                    Expanded(child: _buildSectionLabel(context, 'Khung giờ')),

                    IconButton(
                      tooltip: 'Thông tin khung giờ',

                      onPressed: _showTimeInfo,

                      icon: Icon(
                        Icons.info_rounded,

                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                _buildSingleField(
                  context,

                  controller: timeController,

                  hint: 'VD: sáng, chiều, sau 22h, 0-30p',
                ),

                const SizedBox(height: 16),

                _buildTimeChips(context),

                const SizedBox(height: 34),
              ] else ...[
                // ========================================
                // ADVANCED MODE
                // ========================================

                const SizedBox(height: 34),

                _buildAdvancedKeywordSection(context, showKeyword: true),

                const SizedBox(height: 26),

                Divider(
                  height: 1,

                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),

                const SizedBox(height: 30),

                _buildAdvancedKeywordSection(context, showKeyword: false),

                const SizedBox(height: 38),
              ],

              // ========================================
              // GROUP
              // ========================================
              _buildSectionLabel(context, 'Nhóm áp dụng'),

              const SizedBox(height: 10),

              Material(
                color: colorScheme.surface,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),

                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.55),
                  ),
                ),

                clipBehavior: Clip.antiAlias,

                child: InkWell(
                  onTap: _openGroupSelector,

                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),

                    child: Row(
                      children: [
                        Icon(
                          Icons.group_rounded,

                          size: 27,

                          color: colorScheme.primary,
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Text(
                            selectedGroupIds.isEmpty
                                ? 'Tất cả các nhóm'
                                : selectedGroupIds.length == 1
                                    ? (selectedGroupNames[
                                            selectedGroupIds.first
                                          ] ??
                                        '1 nhóm đã chọn')
                                    : '${selectedGroupIds.length} nhóm đã chọn',

                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                        Icon(
                          Icons.chevron_right_rounded,

                          size: 30,

                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Khoang trong de body
              // khong bi bottom bar che.
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // ========================================
      // FIXED BOTTOM ACTIONS
      // ========================================
      bottomNavigationBar: SafeArea(
        top: false,

        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),

          decoration: BoxDecoration(
            color: colorScheme.surface,

            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),

            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),

                blurRadius: 12,

                offset: const Offset(0, -2),
              ),
            ],
          ),

          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _checkFilter,

                  icon: Icon(Icons.tune_rounded, color: colorScheme.primary),

                  label: Text(
                    'Kiểm tra',

                    style: TextStyle(
                      fontSize: 15.5,
                      color: colorScheme.primary,
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : _saveFilter,

                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Lưu thay đổi' : 'Lưu và sử dụng',

                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // MODE
  // ========================================

  Widget _buildModeOption(
    BuildContext context, {
    required _FilterMode mode,
    required String title,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final selected = this.mode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          this.mode = mode;
        });
      },

      borderRadius: BorderRadius.circular(12),

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),

        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,

              size: 29,

              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,

                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            IconButton(
              tooltip: 'Thông tin $title',

              onPressed: () {
                _showModeInfo(mode);
              },

              icon: Icon(
                Icons.info_rounded,

                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // QUICK TIME
  // ========================================

  Widget _buildTimeChips(BuildContext context) {
    const values = [
      'sáng',
      'trưa',
      'chiều',
      'tối',
      'đêm',
      'cả ngày 6h-22h',
      'gấp — trong 15p',
      'trong 30p',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 12,

      children: values.map((value) {
        return ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),

          label: Text(value),

          onPressed: () {
            _addQuickTime(value);
          },

          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        );
      }).toList(),
    );
  }

  // ========================================
  // LABEL
  // ========================================

  Widget _buildSectionLabel(
    BuildContext context,
    String text, {
    bool required = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),

        children: [
          TextSpan(text: text),

          if (required)
            TextSpan(
              text: ' *',

              style: TextStyle(color: colorScheme.error),
            ),
        ],
      ),
    );
  }

  // ========================================
  // LARGE FIELD
  // ========================================

  Widget _buildLargeField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,

      style: const TextStyle(fontSize: 15),

      minLines: 2,
      maxLines: 3,

      decoration: _inputDecoration(context, hint: hint),
    );
  }

  // ========================================
  // SINGLE FIELD
  // ========================================

  Widget _buildSingleField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,

      style: const TextStyle(fontSize: 15),

      keyboardType: keyboardType,

      decoration: _inputDecoration(context, hint: hint),
    );
  }

  // ========================================
  // INPUT STYLE
  // ========================================

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,

      hintStyle: TextStyle(
        fontSize: 14.5,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
      ),

      filled: true,

      fillColor: colorScheme.surface,

      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(color: colorScheme.outline),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.55),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }
}
