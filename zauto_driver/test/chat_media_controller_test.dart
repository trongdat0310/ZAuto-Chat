import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_media_controller.dart';


Map<String, dynamic> photo({
  required String id,
  required int timestamp,
  String? groupId,
  int? groupIndex,
}) {
  return <String, dynamic>{
    'id': id,
    'msgId': 'msg-$id',
    'cliMsgId': 'cli-$id',
    'timestamp': timestamp,
    'status': 'normal',
    'msgType': 'chat.photo',
    'mediaGroupId': groupId,
    'mediaGroupIndex': groupIndex,
  };
}


void main() {
  test(
    'photo album index groups and orders photos once',
    () {
      final controller = ChatMediaController();

      final messages = <Map<String, dynamic>>[
        photo(
          id: 'a-2',
          timestamp: 2000,
          groupId: 'album-a',
          groupIndex: 2,
        ),
        <String, dynamic>{
          'id': 'text-1',
          'timestamp': 2100,
          'status': 'normal',
          'msgType': 'chat.text',
          'content': 'hello',
        },
        photo(
          id: 'a-1',
          timestamp: 1000,
          groupId: 'album-a',
          groupIndex: 1,
        ),
        photo(
          id: 'b-1',
          timestamp: 3000,
          groupId: 'album-b',
          groupIndex: 1,
        ),
      ];


      final index = controller.buildPhotoAlbumIndex(messages);

      expect(
        index.albumFor('album-a', messages.first)
            .map((item) => item['id'])
            .toList(),
        <String>['a-1', 'a-2'],
      );

      expect(
        index.renderIndexFor(
          'album-a',
          targetIndex: null,
          messages: messages,
          resolveGroupId: controller.mediaGroupId,
        ),
        2,
      );

      expect(
        index.renderIndexFor(
          'album-a',
          targetIndex: 0,
          messages: messages,
          resolveGroupId: controller.mediaGroupId,
        ),
        0,
      );
    },
  );


  test(
    'ungrouped photo does not create an album entry',
    () {
      final controller = ChatMediaController();

      final message = photo(
        id: 'single',
        timestamp: 1000,
      );


      final index = controller.buildPhotoAlbumIndex(
        <Map<String, dynamic>>[message],
      );


      expect(
        index.albums,
        isEmpty,
      );

      expect(
        index.albumFor('missing', message),
        <Map<String, dynamic>>[message],
      );
    },
  );
}
