import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_actions_controller.dart';
import 'package:zauto_driver/pages/chat/chat_reply_controller.dart';
import 'package:zauto_driver/services/backend_service.dart';


class FakeBackendService extends BackendService {
  FakeBackendService() : super(baseUrl: 'http://127.0.0.1:1');

  final List<String> textRequestIds = <String>[];

  final List<String> photoRequestIds = <String>[];

  Completer<void>? textCompleter;

  Completer<void>? photoCompleter;

  Object? textError;

  Object? photoError;


  @override
  Future<void> sendConversationMessage({
    required String groupId,
    required String text,
    required String clientRequestId,
    String? replyToMsgId,
    String? replyToCliMsgId,
  }) async {
    textRequestIds.add(clientRequestId);

    final error = textError;

    if (error != null) {
      textError = null;

      throw error;
    }

    final completer = textCompleter;

    if (completer != null) {
      await completer.future;
    }
  }


  @override
  Future<void> sendConversationPhotos({
    required String groupId,
    required List<String> filePaths,
    required String clientRequestId,
  }) async {
    photoRequestIds.add(clientRequestId);

    final error = photoError;

    if (error != null) {
      photoError = null;

      throw error;
    }

    final completer = photoCompleter;

    if (completer != null) {
      await completer.future;
    }
  }
}


void main() {
  test(
    'double text send is blocked while first request is in flight',
    () async {
      final backend = FakeBackendService();

      backend.textCompleter = Completer<void>();

      final controller = ChatActionsController(
        backend: backend,
        groupId: 'group-a',
      );

      addTearDown(controller.dispose);


      final first = controller.sendText(
        text: 'hello',
      );


      expect(
        controller.sendingMessage,
        isTrue,
      );


      final second = await controller.sendText(
        text: 'hello',
      );


      expect(
        second,
        isFalse,
      );

      expect(
        backend.textRequestIds.length,
        1,
      );


      backend.textCompleter!.complete();


      expect(
        await first,
        isTrue,
      );

      expect(
        controller.sendingMessage,
        isFalse,
      );
    },
  );


  test(
    'retry of same text payload reuses request id after failure',
    () async {
      final backend = FakeBackendService();

      backend.textError = Exception('temporary network failure');

      final controller = ChatActionsController(
        backend: backend,
        groupId: 'group-a',
      );

      addTearDown(controller.dispose);


      await expectLater(
        controller.sendText(
          text: 'retry me',
          replyToMsgId: 'msg-1',
        ),
        throwsException,
      );


      expect(
        controller.sendingMessage,
        isFalse,
      );


      final sent = await controller.sendText(
        text: 'retry me',
        replyToMsgId: 'msg-1',
      );


      expect(
        sent,
        isTrue,
      );

      expect(
        backend.textRequestIds.length,
        2,
      );

      expect(
        backend.textRequestIds[1],
        backend.textRequestIds[0],
      );
    },
  );


  test(
    'different text payload gets a new request id',
    () async {
      final backend = FakeBackendService();

      backend.textError = Exception('temporary failure');

      final controller = ChatActionsController(
        backend: backend,
        groupId: 'group-a',
      );

      addTearDown(controller.dispose);


      await expectLater(
        controller.sendText(
          text: 'first',
        ),
        throwsException,
      );


      await controller.sendText(
        text: 'second',
      );


      expect(
        backend.textRequestIds.length,
        2,
      );

      expect(
        backend.textRequestIds[1],
        isNot(backend.textRequestIds[0]),
      );
    },
  );


  test(
    'text and photo sends are mutually exclusive',
    () async {
      final backend = FakeBackendService();

      backend.photoCompleter = Completer<void>();

      final controller = ChatActionsController(
        backend: backend,
        groupId: 'group-a',
      );

      addTearDown(controller.dispose);


      final photoSend = controller.sendPhotos(
        filePaths: const <String>['a.jpg'],
      );


      expect(
        controller.sendingPhoto,
        isTrue,
      );


      final textSend = await controller.sendText(
        text: 'blocked while photo sends',
      );


      expect(
        textSend,
        isFalse,
      );


      backend.photoCompleter!.complete();


      expect(
        await photoSend,
        isTrue,
      );

      expect(
        controller.sendingPhoto,
        isFalse,
      );
    },
  );


  test(
    'photo retry reuses request id and releases sending state after failure',
    () async {
      final backend = FakeBackendService();

      backend.photoError = Exception('upload interrupted');

      final controller = ChatActionsController(
        backend: backend,
        groupId: 'group-a',
      );

      addTearDown(controller.dispose);


      await expectLater(
        controller.sendPhotos(
          filePaths: const <String>['a.jpg', 'b.jpg'],
        ),
        throwsException,
      );


      expect(
        controller.sendingPhoto,
        isFalse,
      );


      final sent = await controller.sendPhotos(
        filePaths: const <String>['a.jpg', 'b.jpg'],
      );


      expect(
        sent,
        isTrue,
      );

      expect(
        backend.photoRequestIds.length,
        2,
      );

      expect(
        backend.photoRequestIds[1],
        backend.photoRequestIds[0],
      );
    },
  );


  test(
    'reply target is cleared when realtime marks it unavailable',
    () {
      final controller = ChatReplyController();

      final original = <String, dynamic>{
        'id': 'local-1',
        'msgId': 'msg-1',
        'cliMsgId': 'cli-1',
        'status': 'normal',
        'content': 'hello',
      };


      expect(
        controller.startReply(original),
        isNull,
      );

      expect(
        controller.hasReply,
        isTrue,
      );


      final cleared = controller.clearIfTargetUnavailable(
        <String, dynamic>{
          ...original,
          'status': 'recalled',
          'content': null,
        },
      );


      expect(
        cleared,
        isTrue,
      );

      expect(
        controller.hasReply,
        isFalse,
      );
    },
  );


  test(
    'unrelated unavailable message does not cancel current reply',
    () {
      final controller = ChatReplyController();

      controller.startReply(
        <String, dynamic>{
          'msgId': 'msg-1',
          'cliMsgId': 'cli-1',
          'status': 'normal',
          'content': 'hello',
        },
      );


      final cleared = controller.clearIfTargetUnavailable(
        <String, dynamic>{
          'msgId': 'msg-2',
          'cliMsgId': 'cli-2',
          'status': 'deleted_local',
        },
      );


      expect(
        cleared,
        isFalse,
      );

      expect(
        controller.hasReply,
        isTrue,
      );
    },
  );
}
