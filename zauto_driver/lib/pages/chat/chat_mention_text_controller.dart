import 'package:flutter/material.dart';

/// Styles only the outgoing mention prefix in the chat composer.
/// Mention text is still submitted unchanged to the backend.
class ChatMentionTextController extends TextEditingController {
  String? mentionPrefix;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final prefix = mentionPrefix;
    if (prefix == null || !text.startsWith(prefix)) {
      return TextSpan(style: style, text: text);
    }

    return TextSpan(style: style, children: [
      TextSpan(
        text: prefix,
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ) ??
            TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
      TextSpan(text: text.substring(prefix.length)),
    ]);
  }
}
