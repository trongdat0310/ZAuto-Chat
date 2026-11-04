import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_date_separator.dart';


Map<String, dynamic> messageAt(DateTime time) {
  return <String, dynamic>{
    'timestamp': time.millisecondsSinceEpoch,
  };
}


void main() {
  test(
    'chat time formatter uses today yesterday and dated labels',
    () {
      final now =
          DateTime(2026, 10, 7, 21, 30);

      expect(
        formatChatTimeSeparator(
          messageAt(
            DateTime(2026, 10, 7, 9, 5),
          ),
          now: now,
        ),
        'Hôm nay • 09:05',
      );

      expect(
        formatChatTimeSeparator(
          messageAt(
            DateTime(2026, 10, 6, 22, 10),
          ),
          now: now,
        ),
        'Hôm qua • 22:10',
      );

      expect(
        formatChatTimeSeparator(
          messageAt(
            DateTime(2026, 10, 5, 18, 45),
          ),
          now: now,
        ),
        '05/10/2026 • 18:45',
      );
    },
  );



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
          now: DateTime(2026, 10, 7, 18, 0),
        ),
        'Hôm nay • 14:30',
      );
    },
  );


  test(
    'historical same-day time groups show full day label and clock',
    () {
      final older = messageAt(
        DateTime(2026, 10, 4, 10, 0),
      );

      final newer = messageAt(
        DateTime(2026, 10, 4, 10, 46),
      );


      expect(
        formatChatGapSeparator(
          newer,
          older,
          now: DateTime(2026, 10, 7, 12, 0),
        ),
        '04/10/2026 • 10:46',
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
    'different-day labels use today yesterday or full date',
    () {
      final now =
          DateTime(2026, 10, 7, 12, 0);


      expect(
        formatChatGapSeparator(
          messageAt(
            DateTime(2026, 10, 7, 9, 5),
          ),
          messageAt(
            DateTime(2026, 10, 6, 23, 50),
          ),
          now: now,
        ),
        'Hôm nay • 09:05',
      );


      expect(
        formatChatGapSeparator(
          messageAt(
            DateTime(2026, 10, 6, 22, 10),
          ),
          messageAt(
            DateTime(2026, 10, 5, 23, 50),
          ),
          now: now,
        ),
        'Hôm qua • 22:10',
      );


      expect(
        formatChatGapSeparator(
          messageAt(
            DateTime(2026, 10, 5, 18, 45),
          ),
          messageAt(
            DateTime(2026, 10, 4, 23, 50),
          ),
          now: now,
        ),
        '05/10/2026 • 18:45',
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
