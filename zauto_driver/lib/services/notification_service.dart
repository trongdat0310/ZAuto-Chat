import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'backend_service.dart';

class NotificationService {

  NotificationService._();


  static final NotificationService instance =
  NotificationService._();


  final FlutterLocalNotificationsPlugin plugin =
  FlutterLocalNotificationsPlugin();


  static const String tripChannelId =
      'trip_alerts';


  static const String tripCategoryId =
      'TRIP_ACTIONS';


  static const String acceptAction =
      'ACCEPT_TRIP';


  static const String ignoreAction =
      'IGNORE_TRIP';


  // ========================================
  // INITIALIZE
  // ========================================

  Future<void> initialize({
    required void Function(
        NotificationResponse response,
        ) onAction,
  }) async {

    const android =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );


    final ios =
    DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          tripCategoryId,

          actions: [
            DarwinNotificationAction.plain(
              ignoreAction,
              'BỎ QUA',
            ),

            DarwinNotificationAction.plain(
              acceptAction,
              'NHẬN CUỐC',
            ),
          ],
        ),
      ],
    );


    final settings =
    InitializationSettings(
      android: android,
      iOS: ios,
    );


    // API MOI:
    // settings la named argument
    await plugin.initialize(
      settings: settings,

      onDidReceiveNotificationResponse:
      onAction,

      onDidReceiveBackgroundNotificationResponse:
      notificationTapBackground,
    );


    // ========================================
    // ANDROID CHANNEL
    // ========================================

    final androidPlugin =
    plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();


    await androidPlugin
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        tripChannelId,
        'Cuốc mới',

        description:
        'Thông báo các cuốc phù hợp',

        importance:
        Importance.max,
      ),
    );
  }


  // ========================================
  // SHOW TRIP
  // ========================================

  Future<void> showTrip({
    required String messageId,
    required String content,

    String? groupName,
    String? senderName,
  }) async {

    final payload =
    jsonEncode({
      'messageId':
      messageId,

      'groupName':
      groupName,

      'senderName':
      senderName,

      'content':
      content,
    });


    const androidDetails =
    AndroidNotificationDetails(
      tripChannelId,
      'Cuốc mới',

      channelDescription:
      'Thông báo các cuốc phù hợp',

      importance:
      Importance.max,

      priority:
      Priority.high,

      category:
      AndroidNotificationCategory.message,

      actions: [
        AndroidNotificationAction(
          ignoreAction,
          'BỎ QUA',

          cancelNotification: true,

          // Khong mo giao dien app
          showsUserInterface: false,
        ),

        AndroidNotificationAction(
          acceptAction,
          'NHẬN CUỐC',

          cancelNotification: true,

          // Khong mo giao dien app
          showsUserInterface: false,
        ),
      ],
    );


    const iosDetails =
    DarwinNotificationDetails(
      categoryIdentifier:
      tripCategoryId,

      presentAlert:
      true,

      presentBadge:
      true,

      presentSound:
      true,
    );


    // API MOI:
    // tat ca deu la named arguments
    await plugin.show(
      id:
      messageId.hashCode,

      title:
      '🚕 CUỐC MỚI',

      body:
      groupName != null
          ? '$groupName: $content'
          : content,

      notificationDetails:
      const NotificationDetails(
        android:
        androidDetails,

        iOS:
        iosDetails,
      ),

      payload:
      payload,
    );
  }
}


// ========================================
// BACKGROUND NOTIFICATION ACTION
// ========================================

// ========================================
// BACKGROUND NOTIFICATION ACTION
// ========================================

@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse response,
    ) async {
  try {
    final payload =
        response.payload;

    if (
    payload == null ||
        payload.isEmpty
    ) {
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


    debugPrint(
        '[BACKGROUND ACTION] '
            'Action: ${response.actionId}'
    );

    debugPrint(
        '[BACKGROUND ACTION] '
            'Message: $messageId'
    );


    final backend =
    BackendService(
      baseUrl:
      AppConfig.backendUrl,
    );


    // ========================================
    // NHAN CUOC
    // ========================================

    if (
    response.actionId ==
        NotificationService.acceptAction
    ) {
      await backend.acceptMessage(
        messageId,
      );


      debugPrint(
          '[BACKGROUND ACTION] '
              'ACCEPT SUCCESS'
      );

      return;
    }


    // ========================================
    // BO QUA
    // ========================================

    if (
    response.actionId ==
        NotificationService.ignoreAction
    ) {
      await backend.ignoreMessage(
        messageId,
      );


      debugPrint(
          '[BACKGROUND ACTION] '
              'IGNORE SUCCESS'
      );

      return;
    }

  } catch (error) {
    debugPrint(
        '[BACKGROUND ACTION] '
            'ERROR: $error'
    );
  }
}