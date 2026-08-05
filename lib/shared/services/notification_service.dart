// lib/shared/services/notification_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../main.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(
    message.notification?.title ?? 'ApartmentApp',
    message.notification?.body ?? '',
    message.data['type'] ?? 'general',
  );
}

final _local = FlutterLocalNotificationsPlugin();

const _channelMain = AndroidNotificationChannel(
  'main_channel',
  'General',
  importance: Importance.high,
);

const _channelAlert = AndroidNotificationChannel(
  'alert_channel',
  'Alerts',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
);

Future<void> _showLocalNotification(String title, String body, String type) async {
  final channel = type == 'complaint' || type == 'visitor' ? _channelAlert : _channelMain;

  // ✅ FIXED: Added named parameter tags to match the plugin's source signature exactly
  await _local.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: type,
  );
}
class NotificationService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await _fcm.requestPermission(alert: true, badge: false, sound: true);
      }
    }

    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelMain);
    await androidPlugin?.createNotificationChannel(_channelAlert);

    // ✅ FIXED (Lines 73-74): Explicitly tagged constructor input parameter as 'settings'
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print("Notification tapped cleanly with payload context: ${response.payload}");
        }
      },
    );

    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif != null) {
        // Foreground in-app notification using SnackBar
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notif.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(notif.body ?? '', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6750A4), // Using primary color
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            elevation: 6,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    _fcm.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    });
  }

  static Future<String?> getToken() => _fcm.getToken();

  static Future<void> saveToken(String uid) async {
    try {
      final token = await getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      if (kDebugMode) print("Non-fatal: Failed to fetch FCM token during login: $e");
    }
  }

  static Future<void> sendNotification({
    required String title,
    required String body,
    required String type,
    String? targetUid,
    String? buildingId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'targetUid': targetUid,
      'buildingId': buildingId,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    if (targetUid != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final String? fcmToken = data?['fcmToken'];

          if (fcmToken != null && fcmToken.isNotEmpty) {
            if (kDebugMode) {
              print("Target user token resolved safely: $fcmToken");
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("Non-breaking logging network dispatch warning: $e");
      }
    }
  }
}