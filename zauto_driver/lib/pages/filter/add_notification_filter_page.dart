import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/backend_service.dart';

enum _FilterMode { basic, advanced }

class AddNotificationFilterPage extends StatefulWidget {
  final Map<String, dynamic>? initialFilter;

  final Map<String, dynamic>? initialTemplate;

  const AddNotificationFilterPage({
    super.key,
    this.initialFilter,
    this.initialTemplate,
  });

  @override
  State<AddNotificationFilterPage> createState() =>
      _AddNotificationFilterPageState();
}

class _AddNotificationFilterPageState extends State<AddNotificationFilterPage> {
  static const int maxNameLength = 255;

  bool get isEditing => widget.initialFilter != null;

  bool get isDuplicating =>
      !isEditing &&
      widget.initialTemplate != null;

  String get editingFilterId =>
      widget.initialFilter?['id']?.toString() ?? '';

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  final Set<String> selectedGroupIds = {};

  final Map<String, String> selectedGroupNames = {};

  List<Map<String, dynamic>>? groupOptionsCache;

  Future<List<Map<String, dynamic>>>? groupOptionsRequest;

  bool saving = false;

  bool allowPop = false;

  bool discardDialogOpen = false;

  late String initialDraftSignature;

  String? nameError;
  String? pickupError;
  String? dropoffError;
  String? includeError;
  String? excludeError;
  String? minimumPriceError;
  String? timeError;
  String? advancedShowError;
  String? advancedHideError;

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

    initialDraftSignature =
        _draftSignature();

    nameController.addListener(_handleNameChanged);
    pickupController.addListener(_handleBasicFieldChanged);
    dropoffController.addListener(_handleBasicFieldChanged);
    includeController.addListener(_handleBasicFieldChanged);
    excludeController.addListener(_handleBasicFieldChanged);
    minimumPriceController.addListener(_handleBasicFieldChanged);
    timeController.addListener(_handleBasicFieldChanged);

    if (selectedGroupIds.isNotEmpty) {
      _hydrateSelectedGroupNames();
    }
  }

  Future<List<Map<String, dynamic>>> _loadGroupOptions() async {
    final cached = groupOptionsCache;

    if (cached != null) {
      return cached;
    }

    final inFlight = groupOptionsRequest;

    if (inFlight != null) {
      return inFlight;
    }

    final request = backend.getGroups();

    groupOptionsRequest = request;

    try {
      final groups = await request;

      groupOptionsCache = groups;

      return groups;
    } finally {
      groupOptionsRequest = null;
    }
  }

  Future<void> _hydrateSelectedGroupNames() async {
    List<Map<String, dynamic>> groups;

    try {
      groups = await _loadGroupOptions();
    } catch (_) {
      // Ten group chi la du lieu hien thi.
      // Khong duoc chan Edit Filter neu request nay loi.
      return;
    }

    if (!mounted) {
      return;
    }

    final names = <String, String>{};

    for (final group in groups) {
      final groupId = group['groupId']?.toString() ?? '';

      if (selectedGroupIds.contains(groupId)) {
        names[groupId] = group['name']?.toString() ?? groupId;
      }
    }

    if (names.isEmpty) {
      return;
    }

    setState(() {
      selectedGroupNames
        ..clear()
        ..addAll(names);
    });
  }

  void _populateInitialFilter() {
    final filter =
        widget.initialFilter ??
        widget.initialTemplate;

    if (filter == null) {
      return;
    }

    final rawName =
        filter['name']?.toString().trim() ?? '';

    if (isDuplicating) {
      const suffix = ' Bản sao';

      final maxBaseLength =
          maxNameLength - suffix.length;

      final baseName =
          rawName.length > maxBaseLength
              ? rawName.substring(0, maxBaseLength).trimRight()
              : rawName;

      nameController.text =
          baseName.isEmpty
              ? 'Bộ lọc$suffix'
              : '$baseName$suffix';
    } else {
      nameController.text = rawName;
    }

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

  String _draftSignature() {
    final groups =
        selectedGroupIds.toList()
          ..sort();

    final showKeywords =
        advancedShowKeywords
            .map(
              (item) => item.trim(),
            )
            .toList();

    final hideKeywords =
        advancedHideKeywords
            .map(
              (item) => item.trim(),
            )
            .toList();

    final rawPrice =
        minimumPriceController.text.trim();

    final normalizedPrice =
        rawPrice.isEmpty
            ? ''
            : (
                num.tryParse(rawPrice)
                    ?.toString() ??
                rawPrice
              );

    return [
      nameController.text.trim(),
      mode.name,
      groups.join('\u001f'),
      pickupController.text.trim(),
      dropoffController.text.trim(),
      acceptBothDirections ? '1' : '0',
      includeController.text.trim(),
      excludeController.text.trim(),
      normalizedPrice,
      timeController.text.trim(),
      showKeywords.join('\u001f'),
      hideKeywords.join('\u001f'),
    ].join('\u001e');
  }

  bool get hasUnsavedChanges =>
      _draftSignature() !=
      initialDraftSignature;

  Future<bool> _confirmDiscardChanges() async {
    if (
      allowPop ||
      !hasUnsavedChanges
    ) {
      return true;
    }

    if (discardDialogOpen) {
      return false;
    }

    discardDialogOpen = true;

    try {
      final discard =
          await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
            ),
            title: const Text(
              'Hủy thay đổi?',
            ),
            content: Text(
              isEditing
                  ? 'Các thay đổi chưa lưu của bộ lọc này sẽ bị mất.'
                  : 'Bộ lọc đang tạo chưa được lưu. Nội dung đã nhập sẽ bị mất.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext)
                      .pop(false);
                },
                child: const Text(
                  'TIẾP TỤC CHỈNH',
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext)
                      .pop(true);
                },
                child: const Text(
                  'HỦY THAY ĐỔI',
                ),
              ),
            ],
          );
        },
      );

      return discard == true;
    } finally {
      discardDialogOpen = false;
    }
  }

  Future<void> _handleBack() async {
    if (saving) {
      return;
    }

    final discard =
        await _confirmDiscardChanges();

    if (
      !mounted ||
      !discard
    ) {
      return;
    }

    setState(() {
      allowPop = true;
    });

    Navigator.of(context).pop();
  }

  void _handleNameChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      nameError = null;
    });
  }

  void _handleBasicFieldChanged() {
    if (!mounted) {
      return;
    }

    if (
      pickupError == null &&
      dropoffError == null &&
      includeError == null &&
      excludeError == null &&
      minimumPriceError == null &&
      timeError == null
    ) {
      return;
    }

    setState(() {
      pickupError = null;
      dropoffError = null;
      includeError = null;
      excludeError = null;
      minimumPriceError = null;
      timeError = null;
    });
  }

  String? _validateKeywordPattern(String raw) {
    final value = raw.trim();

    if (value.isEmpty) {
      return null;
    }

    if (!value.contains('*')) {
      return null;
    }

    if (
      !value.startsWith('*') ||
      !value.endsWith('*')
    ) {
      return 'Dấu * phải nằm ở cả hai đầu, VD: *nội bài*.';
    }

    if (value.length <= 2) {
      return 'Từ khoá wildcard không được để trống.';
    }

    return null;
  }

  String? _validateCommaSeparatedKeywords(String raw) {
    for (final item in raw.split(',')) {
      final error = _validateKeywordPattern(item);

      if (error != null) {
        return error;
      }
    }

    return null;
  }

  String? _validateAdvancedKeywords(List<String> values) {
    for (final value in values) {
      final error = _validateKeywordPattern(value);

      if (error != null) {
        return '“$value”: $error';
      }
    }

    return null;
  }

  bool _validateForm() {
    final rawPrice = minimumPriceController.text.trim();

    final parsedPrice =
        rawPrice.isEmpty ? null : num.tryParse(rawPrice);

    final nextNameError =
        nameController.text.trim().isEmpty
            ? 'Vui lòng nhập tên bộ lọc.'
            : null;

    String? nextPriceError;

    if (rawPrice.isNotEmpty && parsedPrice == null) {
      nextPriceError = 'Giá tối thiểu phải là một số hợp lệ.';
    } else if (parsedPrice != null && parsedPrice < 0) {
      nextPriceError = 'Giá tối thiểu không được nhỏ hơn 0.';
    }

    final nextPickupError =
        _validateCommaSeparatedKeywords(
          pickupController.text,
        );

    final nextDropoffError =
        _validateCommaSeparatedKeywords(
          dropoffController.text,
        );

    final nextIncludeError =
        _validateCommaSeparatedKeywords(
          includeController.text,
        );

    final nextExcludeError =
        _validateCommaSeparatedKeywords(
          excludeController.text,
        );

    final nextTimeError =
        _validateCommaSeparatedKeywords(
          timeController.text,
        );

    final nextAdvancedShowError =
        _validateAdvancedKeywords(
          advancedShowKeywords,
        );

    final nextAdvancedHideError =
        _validateAdvancedKeywords(
          advancedHideKeywords,
        );

    setState(() {
      nameError = nextNameError;

      if (mode == _FilterMode.basic) {
        pickupError = nextPickupError;
        dropoffError = nextDropoffError;
        includeError = nextIncludeError;
        excludeError = nextExcludeError;
        minimumPriceError = nextPriceError;
        timeError = nextTimeError;
        advancedShowError = null;
        advancedHideError = null;
      } else {
        pickupError = null;
        dropoffError = null;
        includeError = null;
        excludeError = null;
        minimumPriceError = null;
        timeError = null;
        advancedShowError = nextAdvancedShowError;
        advancedHideError = nextAdvancedHideError;
      }
    });

    if (nextNameError != null) {
      return false;
    }

    if (mode == _FilterMode.basic) {
      return nextPickupError == null &&
          nextDropoffError == null &&
          nextIncludeError == null &&
          nextExcludeError == null &&
          nextPriceError == null &&
          nextTimeError == null;
    }

    return nextAdvancedShowError == null &&
        nextAdvancedHideError == null;
  }

  Future<bool> _confirmAdvancedCatchAll() async {
    if (
      mode != _FilterMode.advanced ||
      advancedShowKeywords.isNotEmpty
    ) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Bộ lọc sẽ nhận gần như tất cả tin'),
          content: const Text(
            'Danh sách “Hiện thông báo” đang trống. '
            'Ở chế độ Nâng cao, điều này có nghĩa là mọi tin không '
            'khớp từ khoá Ẩn đều sẽ được nhận. Bạn vẫn muốn tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('QUAY LẠI'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('TIẾP TỤC'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Map<String, dynamic> _buildFilterPayload() {
    final rawPrice = minimumPriceController.text.trim();

    final minimumPrice = rawPrice.isEmpty ? null : num.tryParse(rawPrice);

    return {
      'name': nameController.text.trim(),
      'mode': mode == _FilterMode.advanced ? 'advanced' : 'basic',
      'enabled': isEditing
          ? widget.initialFilter!['enabled'] != false
          : true,
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

  String _formatPriceThousands(dynamic value) {
    final number =
        value is num
            ? value
            : num.tryParse(
                value?.toString() ?? '',
              );

    if (number == null) {
      return '';
    }

    final rounded =
        number.round();

    if (rounded >= 1000) {
      final millions =
          rounded / 1000;

      final text =
          millions % 1 == 0
              ? millions.toInt().toString()
              : millions.toStringAsFixed(1);

      return '${text} triệu';
    }

    return '${rounded}k';
  }

  String _previewReasonText(
    Map<String, dynamic> result,
  ) {
    final reason =
        result['reason']?.toString() ?? '';

    final keyword =
        result['keyword']?.toString().trim() ?? '';

    final rawDetails =
        result['details'];

    final details =
        rawDetails is Map
            ? Map<String, dynamic>.from(rawDetails)
            : <String, dynamic>{};

    String expectedList() {
      final raw = details['expected'];

      if (raw is! List) {
        return '';
      }

      return raw
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }

    switch (reason) {
      case 'advanced_hidden_keyword':
        return keyword.isEmpty
            ? 'Tin nhắn chứa từ khoá đang bị ẩn.'
            : 'Bị chặn bởi từ khoá ẩn “$keyword”.';

      case 'advanced_show_keyword':
        return keyword.isEmpty
            ? 'Tin nhắn khớp từ khoá hiển thị.'
            : 'Khớp từ khoá hiển thị “$keyword”.';

      case 'advanced_no_show_keywords':
        return 'Danh sách Hiện đang trống nên mọi tin không bị Ẩn đều được nhận.';

      case 'advanced_no_show_match':
        return 'Không khớp bất kỳ từ khoá nào trong danh sách Hiện.';

      case 'basic_excluded_keyword':
        return keyword.isEmpty
            ? 'Tin nhắn chứa từ khoá bị loại.'
            : 'Bị chặn bởi từ khoá “$keyword”.';

      case 'basic_pickup_no_match':
        final expected = expectedList();

        return expected.isEmpty
            ? 'Không tìm thấy điểm đón phù hợp.'
            : 'Không tìm thấy điểm đón. Đang chờ một trong: $expected.';

      case 'basic_dropoff_no_match':
        final expected = expectedList();

        return expected.isEmpty
            ? 'Không tìm thấy điểm trả phù hợp.'
            : 'Không tìm thấy điểm trả. Đang chờ một trong: $expected.';

      case 'basic_wrong_direction':
        final pickup =
            details['pickup']?.toString() ?? '';

        final dropoff =
            details['dropoff']?.toString() ?? '';

        if (pickup.isNotEmpty && dropoff.isNotEmpty) {
          return 'Có cả điểm đón “$pickup” và điểm trả “$dropoff” nhưng thứ tự đang ngược chiều.';
        }

        return 'Điểm đón và điểm trả xuất hiện sai thứ tự.';

      case 'basic_round_trip_detected':
        return 'Tin nhắn có cả chiều đón → trả và chiều ngược, trong khi “Nhận cả hai chiều” đang tắt.';

      case 'basic_include_no_match':
        final expected = expectedList();

        return expected.isEmpty
            ? 'Không khớp từ khoá bắt buộc.'
            : 'Không khớp từ khoá bắt buộc. Đang chờ một trong: $expected.';

      case 'basic_price_missing':
        final minimum =
            _formatPriceThousands(
          details['minimumPrice'],
        );

        return minimum.isEmpty
            ? 'Tin nhắn không ghi giá.'
            : 'Tin nhắn không ghi giá nên không thể kiểm tra mức tối thiểu $minimum.';

      case 'basic_price_below_minimum':
        final messagePrice =
            _formatPriceThousands(
          details['messagePrice'],
        );

        final minimum =
            _formatPriceThousands(
          details['minimumPrice'],
        );

        if (messagePrice.isNotEmpty && minimum.isNotEmpty) {
          return 'Giá tin nhắn $messagePrice thấp hơn mức tối thiểu $minimum.';
        }

        return 'Giá tin nhắn thấp hơn mức tối thiểu.';

      case 'basic_time_no_match':
        final rules =
            details['timeRules']?.toString().trim() ?? '';

        return rules.isEmpty
            ? 'Khung giờ trong tin nhắn không phù hợp.'
            : 'Khung giờ trong tin nhắn không khớp quy tắc “$rules”.';

      case 'basic_conditions_match':
        return 'Tin nhắn đáp ứng đầy đủ các điều kiện của bộ lọc Cơ bản.';

      case 'no_applicable_filters':
        return 'Không có bộ lọc áp dụng cho nhóm này.';

      case 'no_filter_match':
        return 'Không có điều kiện nào của bộ lọc khớp tin nhắn.';

      default:
        return reason.isEmpty
            ? 'Không có thêm chi tiết.'
            : reason;
    }
  }

  String _previewCheckLabel(String key) {
    switch (key) {
      case 'exclude':
        return 'Từ khoá loại trừ';
      case 'pickup':
        return 'Điểm đón';
      case 'dropoff':
        return 'Điểm trả';
      case 'direction':
        return 'Chiều di chuyển';
      case 'include':
        return 'Từ khoá bắt buộc';
      case 'price':
        return 'Giá tối thiểu';
      case 'time':
        return 'Khung giờ';
      case 'advanced_hide':
        return 'Từ khoá Ẩn';
      case 'advanced_show':
        return 'Từ khoá Hiện';
      default:
        return key;
    }
  }

  String _previewCheckDetail(
    Map<String, dynamic> check,
  ) {
    final key =
        check['key']?.toString() ?? '';

    final status =
        check['status']?.toString() ?? '';

    final rawDetails =
        check['details'];

    final details =
        rawDetails is Map
            ? Map<String, dynamic>.from(rawDetails)
            : <String, dynamic>{};

    String joined(dynamic value) {
      if (value is! List) {
        return '';
      }

      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }

    if (
      status == 'skipped' &&
      key != 'advanced_hide' &&
      key != 'advanced_show'
    ) {
      return 'Không đặt điều kiện này.';
    }

    switch (key) {
      case 'exclude':
        final keyword =
            details['keyword']?.toString() ?? '';

        if (status == 'fail' && keyword.isNotEmpty) {
          return 'Tìm thấy từ khoá bị loại “$keyword”.';
        }

        return 'Không có từ khoá bị loại.';

      case 'pickup':
      case 'dropoff':
        final matched =
            details['matched']?.toString() ?? '';

        if (status == 'pass' && matched.isNotEmpty) {
          return 'Khớp “$matched”.';
        }

        final expected =
            joined(details['expected']);

        return expected.isEmpty
            ? 'Không tìm thấy giá trị phù hợp.'
            : 'Đang chờ một trong: $expected.';

      case 'direction':
        if (details['blockedByMissingRoute'] == true) {
          return 'Chưa thể kiểm tra vì thiếu điểm đón hoặc điểm trả.';
        }

        if (details['roundTripDetected'] == true) {
          return 'Phát hiện cả chiều thuận và chiều ngược. Bộ lọc đang chỉ nhận một chiều.';
        }

        final pickup =
            details['pickup']?.toString() ?? '';

        final dropoff =
            details['dropoff']?.toString() ?? '';

        if (pickup.isNotEmpty && dropoff.isNotEmpty) {
          return status == 'pass'
              ? 'Đúng chiều $pickup → $dropoff.'
              : 'Sai thứ tự $pickup → $dropoff.';
        }

        return status == 'pass'
            ? 'Đúng chiều.'
            : 'Sai chiều.';

      case 'include':
        final matched =
            details['matched']?.toString() ?? '';

        if (status == 'pass' && matched.isNotEmpty) {
          return 'Khớp “$matched”.';
        }

        final expected =
            joined(details['expected']);

        return expected.isEmpty
            ? 'Không khớp từ khoá bắt buộc.'
            : 'Đang chờ một trong: $expected.';

      case 'price':
        final price =
            _formatPriceThousands(
          details['messagePrice'],
        );

        final minimum =
            _formatPriceThousands(
          details['minimumPrice'],
        );

        if (price.isEmpty) {
          return minimum.isEmpty
              ? 'Tin nhắn không ghi giá.'
              : 'Không thấy giá trong tin. Tối thiểu: $minimum.';
        }

        return minimum.isEmpty
            ? 'Đọc được giá $price.'
            : 'Giá đọc được: $price · Tối thiểu: $minimum.';

      case 'time':
        final rules =
            details['timeRules']?.toString() ?? '';

        return rules.isEmpty
            ? 'Không có quy tắc giờ.'
            : status == 'pass'
                ? 'Khớp quy tắc “$rules”.'
                : 'Không khớp quy tắc “$rules”.';

      case 'advanced_hide':
        final matched =
            details['matched']?.toString() ?? '';

        if (status == 'skipped') {
          return 'Không có từ khoá Ẩn.';
        }

        if (status == 'fail' && matched.isNotEmpty) {
          return 'Khớp từ khoá Ẩn “$matched” nên tin bị chặn.';
        }

        return 'Không khớp từ khoá Ẩn nào.';

      case 'advanced_show':
        final matched =
            details['matched']?.toString() ?? '';

        final overridden =
            details['overriddenByHide'] == true;

        if (status == 'skipped') {
          return overridden
              ? 'Danh sách Hiện trống nên mặc định cho qua, nhưng từ khoá Ẩn vẫn có ưu tiên.'
              : 'Danh sách Hiện trống nên mặc định cho qua mọi tin không bị Ẩn.';
        }

        if (status == 'pass' && matched.isNotEmpty) {
          return overridden
              ? 'Khớp từ khoá Hiện “$matched”, nhưng vẫn bị từ khoá Ẩn chặn.'
              : 'Khớp từ khoá Hiện “$matched”.';
        }

        final expected =
            joined(details['expected']);

        return expected.isEmpty
            ? 'Không khớp từ khoá Hiện.'
            : 'Không khớp từ khoá Hiện. Đang chờ một trong: $expected.';

      default:
        return '';
    }
  }

  Widget _buildPreviewCheckRow(
    BuildContext context,
    Map<String, dynamic> check,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final status =
        check['status']?.toString() ?? '';

    final passed =
        status == 'pass';

    final skipped =
        status == 'skipped';

    final icon =
        passed
            ? Icons.check_circle_rounded
            : skipped
                ? Icons.remove_circle_outline_rounded
                : Icons.cancel_rounded;

    final iconColor =
        passed
            ? colorScheme.primary
            : skipped
                ? colorScheme.onSurfaceVariant
                : colorScheme.error;

    final key =
        check['key']?.toString() ?? '';

    final detail =
        _previewCheckDetail(check);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _previewCheckLabel(key),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color:
                          colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkFilter() async {
    if (!_validateForm()) {
      return;
    }

    if (!await _confirmAdvancedCatchAll()) {
      return;
    }

    if (!mounted) {
      return;
    }

    String draftMessage = '';

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kiểm tra bộ lọc'),
          content: TextField(
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              draftMessage = value;
            },
            onSubmitted: (value) {
              final trimmed =
                  value.trim();

              if (trimmed.isEmpty) {
                return;
              }

              Navigator.of(dialogContext).pop(
                trimmed,
              );
            },
            decoration: const InputDecoration(
              hintText: 'Dán một tin nhắn cuốc để kiểm tra...',
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
                final trimmed =
                    draftMessage.trim();

                if (trimmed.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(
                  trimmed,
                );
              },
              child: const Text('KIỂM TRA'),
            ),
          ],
        );
      },
    );

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

      final explanation =
          _previewReasonText(result);

      await showDialog<void>(
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
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (result['checks'] is List) ...[
                      const SizedBox(height: 18),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chi tiết từng điều kiện',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (result['mode']?.toString() == 'advanced') ...[
                        const SizedBox(height: 5),
                        Text(
                          'Ưu tiên: Từ khoá Ẩn > Từ khoá Hiện.',
                          style: TextStyle(
                            fontSize: 12.8,
                            height: 1.3,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      ...(result['checks'] as List)
                          .whereType<Map>()
                          .map(
                            (item) =>
                                _buildPreviewCheckRow(
                              dialogContext,
                              Map<String, dynamic>.from(item),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
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

    if (!_validateForm()) {
      return;
    }

    if (!await _confirmAdvancedCatchAll()) {
      return;
    }

    if (!mounted) {
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

      setState(() {
        allowPop = true;
        initialDraftSignature =
            _draftSignature();
      });

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
      groups = await _loadGroupOptions();
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
    String draftKeyword = '';

    final value = await showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            showKeyword ? 'Thêm từ khoá hiển thị' : 'Thêm từ khoá ẩn',
          ),

          content: TextFormField(
            autofocus: true,

            textInputAction: TextInputAction.done,

            onChanged: (value) {
              draftKeyword = value;
            },

            onFieldSubmitted: (value) {
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
                Navigator.of(dialogContext).pop(
                  draftKeyword.trim(),
                );
              },

              child: const Text('THÊM'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null || value.trim().isEmpty) {
      return;
    }

    final keyword = value.trim();

    final validationError =
        _validateKeywordPattern(keyword);

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );

      return;
    }

    final target = showKeyword ? advancedShowKeywords : advancedHideKeywords;

    if (target.contains(keyword)) {
      return;
    }

    setState(() {
      target.add(keyword);

      if (showKeyword) {
        advancedShowError = null;
      } else {
        advancedHideError = null;
      }
    });
  }

  void _removeAdvancedKeyword({
    required bool showKeyword,
    required String keyword,
  }) {
    setState(() {
      final target = showKeyword ? advancedShowKeywords : advancedHideKeywords;

      target.remove(keyword);

      if (showKeyword) {
        advancedShowError = null;
      } else {
        advancedHideError = null;
      }
    });
  }

  Future<void> _openSavedKeywordLibrary({
    required bool showKeyword,
  }) async {
    List<String> savedKeywords;

    try {
      savedKeywords =
          await backend.getSavedNotificationFilterKeywords();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải từ khoá đã lưu: $error'),
        ),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    final target =
        showKeyword ? advancedShowKeywords : advancedHideKeywords;

    final draftSaved =
        List<String>.from(savedKeywords);

    final selected =
        <String>{
          ...target.where(
            (keyword) => draftSaved.any(
              (saved) =>
                  saved.toLowerCase() == keyword.toLowerCase(),
            ),
          ),
        };

    String draftLibraryKeyword = '';

    int libraryInputRevision = 0;

    String? libraryError;

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void addKeyword() {
              final value =
                  draftLibraryKeyword.trim();

              if (value.isEmpty) {
                return;
              }

              final validationError =
                  _validateKeywordPattern(value);

              if (validationError != null) {
                setSheetState(() {
                  libraryError = validationError;
                });

                return;
              }

              final exists =
                  draftSaved.any(
                (item) =>
                    item.toLowerCase() ==
                    value.toLowerCase(),
              );

              if (!exists) {
                setSheetState(() {
                  draftSaved.add(value);
                  selected.add(value);
                  libraryError = null;
                });
              }

              setSheetState(() {
                draftLibraryKeyword = '';
                libraryInputRevision += 1;
              });
            }

            return SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              showKeyword
                                  ? 'Từ khoá đã lưu - Hiện'
                                  : 'Từ khoá đã lưu - Ẩn',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${draftSaved.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                'library-keyword-$libraryInputRevision',
                              ),
                              initialValue:
                                  draftLibraryKeyword,
                              textInputAction:
                                  TextInputAction.done,
                              onChanged: (value) {
                                draftLibraryKeyword = value;
                              },
                              onFieldSubmitted: (_) => addKeyword(),
                              decoration: const InputDecoration(
                                hintText: 'Thêm từ khoá vào thư viện...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            tooltip: 'Lưu từ khoá',
                            onPressed: addKeyword,
                            icon: const Icon(
                              Icons.add_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (libraryError != null) ...[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Text(
                          libraryError!,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    Expanded(
                      child: draftSaved.isEmpty
                          ? Center(
                              child: Text(
                                'Chưa có từ khoá nào được lưu.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: draftSaved.length,
                              itemBuilder: (context, index) {
                                final keyword =
                                    draftSaved[index];

                                final checked =
                                    selected.any(
                                  (item) =>
                                      item.toLowerCase() ==
                                      keyword.toLowerCase(),
                                );

                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(keyword),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  secondary: IconButton(
                                    tooltip:
                                        'Xoá khỏi thư viện',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        draftSaved.removeAt(index);
                                        selected.removeWhere(
                                          (item) =>
                                              item.toLowerCase() ==
                                              keyword.toLowerCase(),
                                        );
                                      });
                                    },
                                  ),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selected.removeWhere(
                                        (item) =>
                                            item.toLowerCase() ==
                                            keyword.toLowerCase(),
                                      );

                                      if (value == true) {
                                        selected.add(keyword);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop({
                              'saved':
                                  List<String>.from(draftSaved),
                              'selected':
                                  List<String>.from(selected),
                            });
                          },
                          child: const Text('LƯU VÀ DÙNG'),
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

    if (!mounted || result == null) {
      return;
    }

    final rawSaved =
        result['saved'];

    final rawSelected =
        result['selected'];

    final nextSaved =
        rawSaved is List
            ? rawSaved
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[];

    final nextSelected =
        rawSelected is List
            ? rawSelected
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[];

    try {
      await backend.saveSavedNotificationFilterKeywords(
        nextSaved,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu thư viện từ khoá: $error'),
        ),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    final libraryKeys =
        {
          ...savedKeywords,
          ...nextSaved,
        }
            .map((item) => item.toLowerCase())
            .toSet();

    setState(() {
      target.removeWhere(
        (item) => libraryKeys.contains(item.toLowerCase()),
      );

      for (final keyword in nextSelected) {
        final exists =
            target.any(
          (item) =>
              item.toLowerCase() ==
              keyword.toLowerCase(),
        );

        if (!exists) {
          target.add(keyword);
        }
      }
    });
  }

  Future<void> _openAdvancedKeywordList({
    required bool showKeyword,
  }) async {
    final target =
        showKeyword ? advancedShowKeywords : advancedHideKeywords;

    String draftText =
        target.join('\n');

    String? listError;

    final result =
        await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme =
            Theme.of(sheetContext).colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom:
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: SizedBox(
                  height:
                      MediaQuery.sizeOf(sheetContext).height * 0.72,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        showKeyword
                            ? 'Danh sách từ khoá hiển thị'
                            : 'Danh sách từ khoá ẩn',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mỗi dòng là một từ khoá hoặc một biểu thức. '
                        'Dòng trống và từ khoá trùng sẽ tự được bỏ qua.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color:
                              colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue:
                              draftText,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical:
                              TextAlignVertical.top,
                          onChanged: (value) {
                            draftText = value;
                          },
                          decoration: const InputDecoration(
                            hintText:
                                'VD:\nnội bài\n*(quận 1)*(nội bài)*\n500',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (listError != null) ...[
                        Text(
                          listError!,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      FilledButton(
                        onPressed: () {
                          final values =
                              <String>[];

                          final seen =
                              <String>{};

                          for (final raw
                              in draftText.split('\n')) {
                            final value =
                                raw.trim();

                            if (value.isEmpty) {
                              continue;
                            }

                            final validationError =
                                _validateKeywordPattern(value);

                            if (validationError != null) {
                              setSheetState(() {
                                listError =
                                    '“$value”: $validationError';
                              });

                              return;
                            }

                            final key =
                                value.toLowerCase();

                            if (seen.add(key)) {
                              values.add(value);
                            }

                            if (values.length >= 100) {
                              break;
                            }
                          }

                          Navigator.of(sheetContext)
                              .pop(values);
                        },
                        child: const Text('ÁP DỤNG'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      target
        ..clear()
        ..addAll(result);

      if (showKeyword) {
        advancedShowError = null;
      } else {
        advancedHideError = null;
      }
    });
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
                _openSavedKeywordLibrary(
                  showKeyword: showKeyword,
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
                _openAdvancedKeywordList(
                  showKeyword: showKeyword,
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ========================================
        // CHIPS + ADD BUTTON
        // ========================================
        if (
          showKeyword
              ? advancedShowError != null
              : advancedHideError != null
        ) ...[
          const SizedBox(height: 10),
          Text(
            showKeyword
                ? advancedShowError!
                : advancedHideError!,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: colorScheme.error,
            ),
          ),
        ],

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
    pickupController.removeListener(_handleBasicFieldChanged);
    dropoffController.removeListener(_handleBasicFieldChanged);
    includeController.removeListener(_handleBasicFieldChanged);
    excludeController.removeListener(_handleBasicFieldChanged);
    minimumPriceController.removeListener(_handleBasicFieldChanged);
    timeController.removeListener(_handleBasicFieldChanged);

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

    return PopScope(
      canPop:
          !saving &&
          (
            allowPop ||
            !hasUnsavedChanges
          ),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,

      appBar: AppBar(
        toolbarHeight: 86,

        centerTitle: true,

        leadingWidth: 64,

        leading: IconButton(
          tooltip: 'Quay lại',

          icon: const Icon(Icons.arrow_back_rounded, size: 32),

          onPressed: saving
              ? null
              : _handleBack,
        ),

        title: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              isEditing
                  ? 'Chỉnh sửa bộ lọc'
                  : isDuplicating
                      ? 'Sao chép bộ lọc'
                      : 'Thêm bộ lọc mới',

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

                  errorText: nameError,
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

                  errorText: pickupError,
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

                  errorText: dropoffError,
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

                  errorText: includeError,
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

                  errorText: excludeError,
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

                  errorText: minimumPriceError,
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

                  errorText: timeError,
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

          advancedShowError = null;
          advancedHideError = null;
          pickupError = null;
          dropoffError = null;
          includeError = null;
          excludeError = null;
          minimumPriceError = null;
          timeError = null;
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
    String? errorText,
  }) {
    return TextField(
      controller: controller,

      style: const TextStyle(fontSize: 15),

      minLines: 2,
      maxLines: 3,

      decoration: _inputDecoration(
        context,
        hint: hint,
        errorText: errorText,
      ),
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
    String? errorText,
  }) {
    return TextField(
      controller: controller,

      style: const TextStyle(fontSize: 15),

      keyboardType: keyboardType,

      decoration: _inputDecoration(
        context,
        hint: hint,
        errorText: errorText,
      ),
    );
  }

  // ========================================
  // INPUT STYLE
  // ========================================

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    String? errorText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,

      errorText: errorText,

      errorMaxLines: 3,

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
