import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef PhotoUrlResolver = String? Function(Map<String, dynamic> message);

typedef PhotoParamsResolver = Map<String, dynamic> Function(
  Map<String, dynamic> message,
);

typedef PhotoHeroTagResolver = String Function(Map<String, dynamic> message);

typedef PhotoTapCallback = void Function(Map<String, dynamic> message);

class PhotoMessageBubble extends StatelessWidget {
  final List<Map<String, dynamic>> album;

  final PhotoUrlResolver resolvePhotoUrl;

  final PhotoParamsResolver resolvePhotoParams;

  final PhotoHeroTagResolver resolveHeroTag;

  final PhotoTapCallback onOpenPhoto;

  const PhotoMessageBubble({
    super.key,
    required this.album,
    required this.resolvePhotoUrl,
    required this.resolvePhotoParams,
    required this.resolveHeroTag,
    required this.onOpenPhoto,
  });

  @override
  Widget build(BuildContext context) {
    if (album.isEmpty) {
      return const SizedBox.shrink();
    }

    // ========================================
    // 1 PHOTO
    // ========================================

    if (album.length == 1) {
      return _buildSinglePhoto(album.first);
    }

    return _buildAlbum();
  }

  // ========================================
  // SINGLE PHOTO
  // ========================================

  Widget _buildSinglePhoto(Map<String, dynamic> message) {
    final photoUrl = resolvePhotoUrl(message);

    if (photoUrl == null || photoUrl.isEmpty) {
      return const SizedBox(
        width: 180,

        height: 120,

        child: Center(child: Icon(Icons.broken_image_outlined, size: 32)),
      );
    }

    final params = resolvePhotoParams(message);

    final width = double.tryParse(
      (message['mediaWidth'] ?? params['width'] ?? '').toString(),
    );

    final height = double.tryParse(
      (message['mediaHeight'] ?? params['height'] ?? '').toString(),
    );

    const maxWidth = 290.0;

    const maxHeight = 430.0;

    double displayWidth = maxWidth;

    double displayHeight = 260;

    if (width != null && height != null && width > 0 && height > 0) {
      final scale = math.min(maxWidth / width, maxHeight / height);

      displayWidth = width * scale;

      displayHeight = height * scale;
    }

    final heroTag = resolveHeroTag(message);

    return GestureDetector(
      onTap: () {
        onOpenPhoto(message);
      },

      child: Hero(
        tag: heroTag,

        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),

          child: SizedBox(
            width: displayWidth,

            height: displayHeight,

            child: _RetryNetworkImage(
              url: photoUrl,

              fit: BoxFit.contain,

              fallback: const Center(
                child: Icon(Icons.broken_image_outlined, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // ALBUM TILE
  // ========================================

  Widget _buildAlbumPhotoTile(
    Map<String, dynamic> message, {
    required double width,
    required double height,
    int extraCount = 0,
  }) {
    final photoUrl = resolvePhotoUrl(message);

    if (photoUrl == null || photoUrl.isEmpty) {
      return SizedBox(
        width: width,

        height: height,

        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        onOpenPhoto(message);
      },

      child: Hero(
        tag: resolveHeroTag(message),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),

          child: SizedBox(
            width: width,

            height: height,

            child: Stack(
              fit: StackFit.expand,

              children: [
                _RetryNetworkImage(
                  url: photoUrl,

                  fit: BoxFit.cover,

                  fallback: const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),

                if (extraCount > 0)
                  Container(
                    color: const Color(0x77000000),

                    alignment: Alignment.center,

                    child: Text(
                      '+$extraCount',

                      style: const TextStyle(
                        color: Colors.white,

                        fontSize: 27,

                        fontWeight: FontWeight.w700,
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
  // ALBUM
  // ========================================

  Widget _buildAlbum() {
    const width = 300.0;

    const gap = 4.0;

    // ========================================
    // 2 PHOTOS
    // ========================================

    if (album.length == 2) {
      final itemWidth = (width - gap) / 2;

      return Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          _buildAlbumPhotoTile(album[0], width: itemWidth, height: 190),

          const SizedBox(width: gap),

          _buildAlbumPhotoTile(album[1], width: itemWidth, height: 190),
        ],
      );
    }

    // ========================================
    // 3 PHOTOS
    //
    // [      1      ][ 2 ]
    // [      1      ][ 3 ]
    // ========================================

    if (album.length == 3) {
      const bigWidth = 184.0;

      const smallWidth = width - bigWidth - gap;

      return Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          _buildAlbumPhotoTile(album[0], width: bigWidth, height: 224),

          const SizedBox(width: gap),

          Column(
            children: [
              _buildAlbumPhotoTile(album[1], width: smallWidth, height: 110),

              const SizedBox(height: gap),

              _buildAlbumPhotoTile(album[2], width: smallWidth, height: 110),
            ],
          ),
        ],
      );
    }

    // ========================================
    // 4+ PHOTOS
    //
    // [          PHOTO 1          ]
    //
    // [ PHOTO2 ][ PHOTO3 ][ PHOTO4 ]
    // ========================================

    final smallWidth = (width - gap * 2) / 3;

    final extra = album.length > 4 ? album.length - 4 : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        _buildAlbumPhotoTile(album[0], width: width, height: 225),

        const SizedBox(height: gap),

        Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            _buildAlbumPhotoTile(album[1], width: smallWidth, height: 105),

            const SizedBox(width: gap),

            _buildAlbumPhotoTile(album[2], width: smallWidth, height: 105),

            const SizedBox(width: gap),

            _buildAlbumPhotoTile(
              album[3],

              width: smallWidth,

              height: 105,

              extraCount: extra,
            ),
          ],
        ),
      ],
    );
  }
}

// ========================================
// RETRY NETWORK IMAGE
//
// Anh vua gui co the da co URL
// nhung file tren server/CDN chua san sang
// tai dung thoi diem Image.network request.
//
// Tu dong retry vai lan thay vi doi user
// mo viewer / back de trigger rebuild.
// ========================================

class _RetryNetworkImage extends StatefulWidget {
  final String url;

  final BoxFit fit;

  final Widget fallback;

  const _RetryNetworkImage({
    required this.url,
    required this.fit,
    required this.fallback,
  });

  @override
  State<_RetryNetworkImage> createState() => _RetryNetworkImageState();
}

class _RetryNetworkImageState extends State<_RetryNetworkImage> {
  static const int _maxRetries = 5;

  int _retryCount = 0;

  int _reloadToken = 0;

  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant _RetryNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();

      _retryTimer = null;

      _retryCount = 0;

      _reloadToken = 0;
    }
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryCount >= _maxRetries) {
      return;
    }

    final delay = Duration(milliseconds: 500 + (_retryCount * 400));

    _retryTimer = Timer(delay, () async {
      _retryTimer = null;

      // Xoa request loi cu khoi Flutter image cache.
      await NetworkImage(widget.url).evict();

      if (!mounted) {
        return;
      }

      setState(() {
        _retryCount += 1;

        // Ep Image.network tao request moi.
        _reloadToken += 1;
      });
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,

      key: ValueKey('${widget.url}-$_reloadToken'),

      fit: widget.fit,

      errorBuilder: (context, error, stackTrace) {
        _scheduleRetry();

        return widget.fallback;
      },
    );
  }
}
