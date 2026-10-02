import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

enum MediaDownloadKind { image, video }

class MediaDownloadService {
  static Future<void> saveFromUrl({
    required String url,
    required MediaDownloadKind kind,
  }) async {
    final uri = Uri.tryParse(url.trim());

    if (uri == null || !uri.hasScheme) {
      throw Exception('Đường dẫn media không hợp lệ');
    }

    // ========================================
    // GALLERY PERMISSION
    // ========================================

    var hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
    }

    if (!hasAccess) {
      throw Exception('Bạn chưa cấp quyền lưu vào thư viện');
    }

    final client = http.Client();

    File? tempFile;

    try {
      // ========================================
      // STREAM DOWNLOAD
      //
      // Khong dung http.get() cho video lon
      // de tranh nap ca video vao RAM.
      // ========================================

      final request = http.Request('GET', uri);

      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Không thể tải media '
          '(${response.statusCode})',
        );
      }

      final extension = _resolveExtension(
        uri: uri,
        contentType: response.headers['content-type'],
        kind: kind,
      );

      final fileName =
          'zauto_'
          '${DateTime.now().microsecondsSinceEpoch}'
          '.$extension';

      tempFile = File(
        '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}'
        '$fileName',
      );

      final sink = tempFile.openWrite();

      await response.stream.pipe(sink);

      // ========================================
      // SAVE TO GALLERY
      // ========================================

      switch (kind) {
        case MediaDownloadKind.image:
          await Gal.putImage(tempFile.path);

          break;

        case MediaDownloadKind.video:
          await Gal.putVideo(tempFile.path);

          break;
      }
    } finally {
      client.close();

      final file = tempFile;

      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Temp cleanup failure
          // khong anh huong ket qua save.
        }
      }
    }
  }

  static String _resolveExtension({
    required Uri uri,
    required String? contentType,
    required MediaDownloadKind kind,
  }) {
    final mime = contentType?.split(';').first.trim().toLowerCase();

    switch (mime) {
      case 'image/jpeg':
        return 'jpg';

      case 'image/png':
        return 'png';

      case 'image/webp':
        return 'webp';

      case 'image/gif':
        return 'gif';

      case 'video/mp4':
        return 'mp4';

      case 'video/quicktime':
        return 'mov';

      case 'video/webm':
        return 'webm';
    }

    final path = uri.path.toLowerCase();

    final dot = path.lastIndexOf('.');

    if (dot >= 0 && dot < path.length - 1) {
      final extension = path.substring(dot + 1);

      const allowed = <String>{
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm',
      };

      if (allowed.contains(extension)) {
        return extension;
      }
    }

    return kind == MediaDownloadKind.image ? 'jpg' : 'mp4';
  }
}
