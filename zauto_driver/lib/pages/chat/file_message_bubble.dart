import 'package:flutter/material.dart';

class FileMessageBubble extends StatelessWidget {
  final String? fileName;

  final String? fileExtension;

  final dynamic fileSize;

  final VoidCallback onTap;

  const FileMessageBubble({
    super.key,
    required this.fileName,
    required this.fileExtension,
    required this.fileSize,
    required this.onTap,
  });

  String _formatFileSize(dynamic value) {
    final bytes = int.tryParse(value?.toString() ?? '');

    if (bytes == null || bytes <= 0) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;

    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    final gb = mb / 1024;

    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final safeFileName = fileName != null && fileName!.trim().isNotEmpty
        ? fileName!.trim()
        : 'Tệp đính kèm';

    final extension = fileExtension?.trim().toUpperCase();

    final formattedFileSize = _formatFileSize(fileSize);

    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        onTap: onTap,

        child: Container(
          constraints: const BoxConstraints(maxWidth: 285),

          padding: const EdgeInsets.all(11),

          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,

            borderRadius: BorderRadius.circular(12),

            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.10,
                ),

                blurRadius: 3,

                offset: const Offset(0, 1),
              ),
            ],
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              // ========================================
              // FILE ICON / EXTENSION
              // ========================================

              Container(
                width: 48,

                height: 48,

                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,

                  borderRadius: BorderRadius.circular(10),
                ),

                alignment: Alignment.center,

                child: extension != null && extension.isNotEmpty
                    ? Text(
                        extension,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontSize: 11,

                          fontWeight: FontWeight.w700,

                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.insert_drive_file_outlined,

                        color: colorScheme.primary,
                      ),
              ),

              const SizedBox(width: 10),

              // ========================================
              // FILE NAME + SIZE
              // ========================================
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      safeFileName,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 14,

                        fontWeight: FontWeight.w600,

                        color: colorScheme.onSurface,
                      ),
                    ),

                    if (formattedFileSize.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(
                        formattedFileSize,

                        style: TextStyle(
                          fontSize: 11,

                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // ========================================
              // OPEN
              // ========================================
              Icon(
                Icons.open_in_new_rounded,

                size: 21,

                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
