import 'dart:io';

import 'package:http/http.dart' as http;

import 'backend_api_base.dart';

class MediaApi extends BackendApiBase {
  MediaApi({required super.baseUrl, required super.auth});

  Future<void> sendConversationPhoto({
    required String groupId,
    required String filePath,
  }) async {
    final safeFilePath = filePath.trim();

    if (safeFilePath.isEmpty) {
      throw Exception('Không có ảnh để gửi');
    }

    final headers = await authHeaders();

    final encodedGroupId = Uri.encodeComponent(groupId);

    // ========================================
    // MULTIPART REQUEST
    //
    // KHONG TU SET Content-Type.
    // MultipartRequest se tu tao boundary.
    // ========================================

    final request = http.MultipartRequest(
      'POST',

      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/messages/photo',
      ),
    );

    request.headers.addAll(headers);

    request.files.add(await http.MultipartFile.fromPath('photo', safeFilePath));

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    await decodeMultipartResponse(response);
  }

  Future<void> sendConversationPhotos({
    required String groupId,
    required List<String> filePaths,
    required String clientRequestId,
  }) async {
    final safePaths = filePaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();

    if (safePaths.isEmpty) {
      throw Exception('Chưa chọn ảnh');
    }

    if (safePaths.length > 10) {
      throw Exception('Mỗi lần chỉ gửi tối đa 10 ảnh');
    }

    for (var index = 0; index < safePaths.length; index += 1) {
      final file = File(safePaths[index]);

      if (!await file.exists()) {
        throw Exception('Ảnh ${index + 1} không còn tồn tại trên thiết bị');
      }

      final size = await file.length();

      if (size <= 0) {
        throw Exception('Ảnh ${index + 1} bị trống hoặc không đọc được');
      }

      if (size > 15 * 1024 * 1024) {
        throw Exception('Ảnh ${index + 1} vượt quá giới hạn 15 MB');
      }
    }

    final headers = await authHeaders();

    final encodedGroupId = Uri.encodeComponent(groupId);

    final request = http.MultipartRequest(
      'POST',

      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/messages/photos',
      ),
    );

    request.headers.addAll(headers);

    request.fields['clientRequestId'] = clientRequestId;

    for (final path in safePaths) {
      request.files.add(await http.MultipartFile.fromPath('photos', path));
    }

    final response = await sendMultipartRequest(request);

    await decodeMultipartResponse(response);
  }
}
