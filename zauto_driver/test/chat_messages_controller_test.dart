import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_messages_controller.dart';
import 'package:zauto_driver/pages/chat/chat_target_controller.dart';
import 'package:zauto_driver/services/backend_service.dart';


Map<String, dynamic> message({
  required String id,
  required int timestamp,
  String status = 'normal',
  String content = 'message',
}) {
  return <String, dynamic>{
    'id': id,
    'msgId': 'msg-$id',
    'cliMsgId': 'cli-$id',
    'timestamp': timestamp,
    'status': status,
    'msgType': 'chat.text',
    'content': content,
  };
}


void main() {
  late ChatMessagesController controller;

  setUp(() {
    controller = ChatMessagesController(
      backend: BackendService(
        baseUrl: 'http://127.0.0.1:1',
      ),
      groupId: 'group-test',
    );
  });

  tearDown(() {
    controller.dispose();
  });


  test(
    'REST tombstone removes an already loaded message',
    () {
      controller.messages = <Map<String, dynamic>>[
        message(
          id: '1',
          timestamp: 1000,
          content: 'keep',
        ),
        message(
          id: '2',
          timestamp: 2000,
          content: 'delete me',
        ),
      ];


      controller.mergeLatest(
        <Map<String, dynamic>>[
          message(
            id: '2',
            timestamp: 2000,
            status: 'deleted_local',
            content: '',
          ),
        ],
        force: false,
      );


      expect(
        controller.messages.map((item) => item['id']).toList(),
        <String>['1'],
      );
    },
  );


  test(
    'recalled update replaces an existing loaded message while viewing history',
    () {
      controller.messages = <Map<String, dynamic>>[
        message(
          id: '1',
          timestamp: 1000,
          content: 'original',
        ),
      ];

      controller.hasMoreNewer = true;


      final result = controller.upsertRealtime(
        message(
          id: '1',
          timestamp: 1000,
          status: 'recalled',
          content: '',
        ),
      );


      expect(
        result,
        ChatMessageUpsertResult.updated,
      );

      expect(
        controller.messages.single['status'],
        'recalled',
      );
    },
  );


  test(
    'new realtime message is skipped while history has newer gap',
    () {
      controller.messages = <Map<String, dynamic>>[
        message(
          id: '1',
          timestamp: 1000,
        ),
      ];

      controller.hasMoreNewer = true;


      final result = controller.upsertRealtime(
        message(
          id: '2',
          timestamp: 2000,
        ),
      );


      expect(
        result,
        ChatMessageUpsertResult.skipped,
      );

      expect(
        controller.messages.length,
        1,
      );
    },
  );


  test(
    'extractMessages can keep delete tombstones for reconnect reconciliation',
    () {
      final raw = <Map<String, dynamic>>[
        message(
          id: '1',
          timestamp: 1000,
        ),
        message(
          id: '2',
          timestamp: 2000,
          status: 'deleted_local',
          content: '',
        ),
      ];


      final visible = controller.extractMessages(raw);

      final withTombstones = controller.extractMessages(
        raw,
        includeDeletedLocal: true,
      );


      expect(
        visible.map((item) => item['id']).toList(),
        <String>['1'],
      );

      expect(
        withTombstones.map((item) => item['id']).toList(),
        <String>['1', '2'],
      );
    },
  );


  test(
    'target index follows prepend and removal without pointing to wrong bubble',
    () {
      final target = ChatTargetController(
        targetMsgId: 'msg-target',
        targetCliMsgId: null,
      );

      addTearDown(target.dispose);


      target.setFound(2);

      target.adjustAfterPrepend(3);


      expect(
        target.targetIndex,
        5,
      );


      target.adjustAfterMessageRemoval(1);


      expect(
        target.targetIndex,
        4,
      );


      target.adjustAfterMessageRemoval(4);


      expect(
        target.targetIndex,
        isNull,
      );

      expect(
        target.highlightTarget,
        isFalse,
      );
    },
  );
}
