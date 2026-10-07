import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_date_separator.dart';


Map<String, dynamic> messageAt(DateTime time) {
  return <String, dynamic>{
    'timestamp': time.millisecondsSinceEpoch,
  };
}


void main() {
  test(
    'same-day messages under 30 minutes stay in one time group',
    () {
      final older = messageAt(
        DateTime(2026, 10, 7, 14, 0),
      );

      final newer = messageAt(
        DateTime(2026, 10, 7, 14, 29),
      );


      expect(
        shouldShowChatTimeSeparator(
          newer,
          older,
        ),
        isFalse,
      );

      expect(
        formatChatGapSeparator(
          newer,
          older,
        ),
        isEmpty,
      );
    },
  );


  test(
    'same-day messages separated by 30 minutes show clock separator',
    () {
      final older = messageAt(
        DateTime(2026, 10, 7, 14, 0),
      );

      final newer = messageAt(
        DateTime(2026, 10, 7, 14, 30),
      );


      expect(
        shouldShowChatTimeSeparator(
          newer,
          older,
        ),
        isTrue,
      );

      expect(
        formatChatGapSeparator(
          newer,
          older,
        ),
        '14:30',
      );
    },
  );


  test(
    'different day always creates a separator',
    () {
      final older = messageAt(
        DateTime(2026, 10, 6, 23, 58),
      );

      final newer = messageAt(
        DateTime(2026, 10, 7, 0, 2),
      );


      expect(
        shouldShowChatTimeSeparator(
          newer,
          older,
        ),
        isTrue,
      );
    },
  );


  test(
    'date separator includes day label and clock',
    () {
      final message = messageAt(
        DateTime(2026, 10, 7, 9, 5),
      );


      expect(
        formatChatTimeSeparator(
          message,
          now: DateTime(2026, 10, 7, 12, 0),
        ),
        'Hôm nay • 09:05',
      );


      expect(
        formatChatTimeSeparator(
          messageAt(
            DateTime(2026, 10, 6, 22, 10),
          ),
          now: DateTime(2026, 10, 7, 12, 0),
        ),
        'Hôm qua • 22:10',
      );
    },
  );
}
