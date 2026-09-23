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

    for (final path in safePaths) {
      request.files.add(await http.MultipartFile.fromPath('photos', path));
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    await decodeMultipartResponse(response);
  }
}
