import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    await _requestPermissions();

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      // Mobile permissions
      final status = await Permission.notification.request();
      if (status.isDenied) {
        print('Notification permission denied');
      }
      
      // Request microphone permission for sound
      await Permission.microphone.request();
    } else {
      // Web permissions - simplified approach
      try {
        // For web, we'll handle permissions through the browser's native API
        print('Web notification permissions will be requested when showing first notification');
      } catch (e) {
        print('Web notification setup error: $e');
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String conversationId,
    bool playSound = true,
  }) async {
    if (!_isInitialized) await initialize();

    // Play notification sound
    if (playSound) {
      await _playNotificationSound();
    }

    // Show notification
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: false, // We handle sound manually
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // We handle sound manually
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      conversationId.hashCode,
      'New message from $senderName',
      message.length > 50 ? '${message.substring(0, 50)}...' : message,
      notificationDetails,
      payload: conversationId,
    );
  }

  Future<void> _playNotificationSound() async {
    try {
      if (kIsWeb) {
        // For web, use a simple beep sound
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      } else {
        // For mobile, use the notification sound
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      }
    } catch (e) {
      print('Error playing notification sound: $e');
      // Fallback: try to use system notification sound
      try {
        await _audioPlayer.play(AssetSource('sounds/notification_fallback.wav'));
      } catch (e2) {
        print('Error playing fallback sound: $e2');
      }
    }
  }

  Future<void> cancelNotification(String conversationId) async {
    await _notifications.cancel(conversationId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
