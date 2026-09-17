import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../controllers/settings_controller.dart';

import '../../services/audio_service.dart';
import '../../services/backend_service.dart';
import '../../services/chat_state_service.dart';
import '../../services/notification_service.dart';
import '../../services/speech_service.dart';


class HomeNotificationHandler {

  final SettingsController settingsController;

  final BackendService backend;

  final AudioService audioService;

  final SpeechService speechService;


  HomeNotificationHandler({
    required this.settingsController,
    required this.backend,
    required this.audioService,
    required this.speechService,
  });

  Future<void> initialize(
      BuildContext context,
      ) async {

    await setupLocalNotifications(
      context,
    );

    await setupPushNotifications();
  }

  Future<void> handleTripNotificationSpeech(
      Map<String, dynamic> data,
      ) async {

    final settings =
            settingsController
            .settings;

    final groupId =
    data['groupId']
        ?.toString();


    final isOpeningChat =
        groupId != null &&
            ChatStateService
                .instance
                .isOpeningGroup(
              groupId,
            );


    final content =
        data['content']
            ?.toString()
            ??
            '';


    final groupName =
        data['groupName']
            ?.toString()
            ??
            '';


    final senderName =
        data['senderName']
            ?.toString()
            ??
            '';



    // ========================================
    // PHAT AM THANH
    // ========================================

    if (
        settings.playTripSound &&
        !isOpeningChat
    ) {

      await audioService
          .playTripSound();

    }



    // ========================================
    // DOC NOI DUNG CUOC
    // ========================================

    if (
    settings.readTripNotification &&
        !isOpeningChat
    ) {


      final text =
          'Cuốc mới: $content. '
          'Người gửi: $senderName. '
          'Nhóm: $groupName. ';

      await speechService.speak(
        text,

        rate:
        settings.speechRate,
      );
    }
  }

  Future<void> setupPushNotifications() async {

    // ========================================
    // APP DANG MO
    // ========================================

    FirebaseMessaging
        .onMessage
        .listen(
          (
          RemoteMessage remoteMessage,
          ) async {

        final data =
            remoteMessage.data;


        if (
        data['type'] !=
            'new_trip'
        ) {
          return;
        }


        await NotificationService
            .instance
            .showTrip(
          messageId:
          data['messageId'] ??
              '',

          groupId:
          data['groupId'] ?? '',

          groupName:
          data['groupName'],

          senderName:
          data['senderName'],

          content:
          data['content'] ??
              '',
        );
      },
    );
  }

  Future<void> setupLocalNotifications(
      BuildContext context,
      ) async {

    await NotificationService
        .instance
        .initialize(

      onAction:
          (response) {

        handleNotificationAction(
          context,
          response,
        );
      },
    );
  }

  Future<void> handleNotificationAction(
      BuildContext context,
      NotificationResponse response,
      ) async {


    final payload =
        response.payload;


    if (payload == null) {
      return;
    }


    final decoded =
    jsonDecode(payload);


    final messageId =
    decoded['messageId']
        ?.toString();


    if (
    messageId == null ||
        messageId.isEmpty
    ) {
      return;
    }


    try {

      if (
      response.actionId ==
          NotificationService
              .acceptAction
      ) {

        await backend
            .acceptMessage(
          messageId,

          replyText:
              settingsController
              .settings
              .acceptReplyText,
        );


        if (!context.mounted) {
          return;
        }


        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Đã nhận cuốc',
            ),
          ),
        );

        return;
      }


      if (
      response.actionId ==
          NotificationService
              .ignoreAction
      ) {

        await backend
            .ignoreMessage(
          messageId,
        );


        if (!context.mounted) {
          return;
        }


        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Đã bỏ qua cuốc',
            ),
          ),
        );
      }

    } catch (error) {

      debugPrint(
          'Notification action error: $error'
      );
    }
  }
}