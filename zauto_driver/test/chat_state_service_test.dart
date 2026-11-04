import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/services/chat_state_service.dart';


void main() {
  final service = ChatStateService.instance;

  setUp(service.clear);

  tearDown(service.clear);


  test(
    'latest opened chat is current and closing it restores previous chat',
    () {
      service.openGroup('group-a');

      expect(
        service.currentGroupId,
        'group-a',
      );

      service.openGroup('group-b');

      expect(
        service.currentGroupId,
        'group-b',
      );

      expect(
        service.isOpeningGroup('group-b'),
        isTrue,
      );

      expect(
        service.isOpeningGroup('group-a'),
        isFalse,
      );


      service.closeGroup('group-b');


      expect(
        service.currentGroupId,
        'group-a',
      );

      expect(
        service.isOpeningGroup('group-a'),
        isTrue,
      );
    },
  );


  test(
    'closing background chat does not clear current foreground chat',
    () {
      service.openGroup('group-a');

      service.openGroup('group-b');


      service.closeGroup('group-a');


      expect(
        service.currentGroupId,
        'group-b',
      );

      expect(
        service.isOpeningGroup('group-b'),
        isTrue,
      );
    },
  );


  test(
    'closing duplicated top route restores the route below it',
    () {
      service.openGroup('group-a');

      service.openGroup('group-b');

      service.openGroup('group-a');


      expect(
        service.currentGroupId,
        'group-a',
      );


      service.closeGroup('group-a');


      expect(
        service.currentGroupId,
        'group-b',
      );
    },
  );


  test(
    'same group can be stacked twice without losing underlying route',
    () {
      service.openGroup('group-a');

      service.openGroup('group-a');


      service.closeGroup('group-a');


      expect(
        service.currentGroupId,
        'group-a',
      );

      expect(
        service.isOpeningGroup('group-a'),
        isTrue,
      );
    },
  );
}
