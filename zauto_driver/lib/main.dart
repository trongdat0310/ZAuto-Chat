import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'dart:async';

import 'services/notification_service.dart';

import 'controllers/settings_controller.dart';

import 'app/app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {

  await Firebase.initializeApp(
    options:
    DefaultFirebaseOptions.currentPlatform,
  );


  final data =
      message.data;


  if (
  data['type'] != 'new_trip'
  ) {
    return;
  }


  await NotificationService.instance
      .showTrip(
    messageId:
    data['messageId'] ?? '',

    groupId:
    data['groupId'] ?? '',

    groupName:
    data['groupName'],

    senderName:
    data['senderName'],

    content:
    data['content'] ?? '',
  );
}

Future<void> main() async {

  WidgetsFlutterBinding
      .ensureInitialized();


  await Firebase.initializeApp(
    options:
    DefaultFirebaseOptions
        .currentPlatform,
  );


  FirebaseMessaging
      .onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );


  // ========================================
  // LOAD APP SETTINGS
  // ========================================

  final settingsController =
  SettingsController();

  await settingsController.load();

  runApp(
    ZautoDriverApp(
      settingsController:
      settingsController,
    ),
  );
}


