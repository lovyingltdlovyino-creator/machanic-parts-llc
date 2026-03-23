import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _chatChannelId = 'chat_messages';
const String _adminChannelId = 'admin_broadcasts';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[Notification] Tapped: ${response.payload}');
      },
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _adminChannelId,
        'Admin Broadcasts',
        description: 'Notifications sent by the marketplace admin',
        importance: Importance.high,
      ),
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  // No-op: retained so callers don't break when Firebase is re-added later
  Future<void> syncPushToken() async {}

  Future<void> handleAuthStateChange(
      AuthChangeEvent event, Session? session) async {}

  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String conversationId,
    bool playSound = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (kIsWeb) return;

    final trimmedMessage =
        message.length > 80 ? '${message.substring(0, 80)}...' : message;

    const androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      interruptionLevel: InterruptionLevel.active,
    );

    await _notifications.show(
      conversationId.hashCode,
      'New message from $senderName',
      trimmedMessage,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: conversationId,
    );
  }

  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _adminChannelId,
  }) async {
    if (!_isInitialized) await initialize();
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _adminChannelId ? 'Admin Broadcasts' : 'General Notifications',
      channelDescription: 'Mechanic Part notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> cancelNotification(String conversationId) async {
    if (kIsWeb) return;
    await _notifications.cancel(conversationId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  void dispose() {}
}
