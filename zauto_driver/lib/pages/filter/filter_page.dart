import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/backend_service.dart';

class FilterPage
    extends StatefulWidget {

  final int initialTab;


  const FilterPage({
    super.key,

    this.initialTab = 0,
  });


  @override
  State<FilterPage>
  createState() =>
      _FilterPageState();
}

class _FilterPageState
    extends State<FilterPage> {

  late int selectedTab;

  final BackendService backend = BackendService(
    baseUrl: AppConfig.backendUrl,
  );

  final includeController = TextEditingController();
  final excludeController = TextEditingController();

  bool filterEnabled = true;
  bool loading = true;
  bool saving = false;


  @override
  void initState() {
    super.initState();

    selectedTab =
        widget.initialTab;

    loadFilters();
  }


  // ========================================
  // LOAD FILTER FROM BACKEND
  // ========================================

  Future<void> loadFilters() async {
    setState(() {
      loading = true;
    });

    try {
      final filters =
      await backend.getFilters();

      final include =
      filters['includeKeywords'];

      final exclude =
      filters['excludeKeywords'];

      includeController.text =
      include is List
          ? include.join(', ')
          : '';

      excludeController.text =
      exclude is List
          ? exclude.join(', ')
          : '';

      if (!mounted) return;

      setState(() {
        filterEnabled =
            filters['enabled'] != false;
      });

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải bộ lọc: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }


  // ========================================
  // TEXT -> KEYWORD LIST
  // ========================================

  List<String> parseKeywords(
      String text,
      ) {
    return text
        .split(
      RegExp(r'[,;\n]'),
    )
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toSet()
        .toList();
  }


  // ========================================
  // SAVE TO BACKEND
  // ========================================

  Future<void> saveFilters() async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      final includeKeywords =
      parseKeywords(
        includeController.text,
      );

      final excludeKeywords =
      parseKeywords(
        excludeController.text,
      );

      await backend.updateFilters(
        includeKeywords:
        includeKeywords,

        excludeKeywords:
        excludeKeywords,

        enabled:
        filterEnabled,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu bộ lọc trên server',
          ),
        ),
      );

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi lưu bộ lọc: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }


  @override
  void dispose() {
    includeController.dispose();
    excludeController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: loading

          ? const Center(
        child:
        CircularProgressIndicator(),
      )

          : RefreshIndicator(
        onRefresh: loadFilters,

        child: ListView(
          padding:
          const EdgeInsets.all(
            20,
          ),

          children: [
            const Text(
              'Bộ lọc',
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Backend sẽ chỉ báo những cuốc phù hợp với điều kiện này.',
            ),

            const SizedBox(
              height: 24,
            ),


            // ========================================
            // ENABLE FILTER
            // ========================================

            Card(
              child: SwitchListTile(
                title: const Text(
                  'Bật bộ lọc',
                ),

                subtitle:
                const Text(
                  'Tắt để nhận tất cả tin nhắn từ những nhóm đang theo dõi.',
                ),

                value:
                filterEnabled,

                onChanged:
                    (value) {
                  setState(() {
                    filterEnabled =
                        value;
                  });
                },
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            // ========================================
            // INCLUDE
            // ========================================

            TextField(
              controller:
              includeController,

              enabled:
              filterEnabled,

              minLines: 3,

              maxLines: 6,

              decoration:
              const InputDecoration(
                labelText:
                'Từ khóa cần có',

                hintText:
                'Nội Bài, NB, Cầu Giấy, sân bay',

                helperText:
                'Chỉ cần trùng một từ khóa.',

                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            // ========================================
            // EXCLUDE
            // ========================================

            TextField(
              controller:
              excludeController,

              enabled:
              filterEnabled,

              minLines: 3,

              maxLines: 6,

              decoration:
              const InputDecoration(
                labelText:
                'Từ khóa loại trừ',

                hintText:
                'ship, hàng, ghép',

                helperText:
                'Nếu có từ khóa loại trừ, tin sẽ bị bỏ qua.',

                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 24,
            ),


            // ========================================
            // SAVE
            // ========================================

            SizedBox(
              height: 56,

              child:
              FilledButton.icon(
                onPressed:
                saving
                    ? null
                    : saveFilters,

                icon:
                saving
                    ? const SizedBox(
                  width:
                  20,
                  height:
                  20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
                    : const Icon(
                  Icons.save,
                ),

                label: Text(
                  saving
                      ? 'ĐANG LƯU...'
                      : 'LƯU BỘ LỌC',
                ),
              ),
            ),


            const SizedBox(
              height: 20,
            ),

            const Card(
              child: Padding(
                padding:
                EdgeInsets.all(
                  16,
                ),

                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    Icon(
                      Icons
                          .cloud_done_outlined,
                    ),

                    SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Text(
                        'Bộ lọc được lưu trên backend. Khi app đóng, backend vẫn tiếp tục sử dụng cấu hình này.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}