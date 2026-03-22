import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _firebaseApiKeyFromDefine =
    String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
const String _firebaseProjectIdFromDefine =
    String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
const String _firebaseMessagingSenderIdFromDefine =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
const String _firebaseAndroidAppIdFromDefine =
    String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
const String _firebaseIosAppIdFromDefine =
    String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
const String _firebaseIosBundleIdFromDefine =
    String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');
const String _firebaseStorageBucketFromDefine =
    String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');

String _configValue(String fromDefine, String key) {
  if (fromDefine.isNotEmpty) return fromDefine.trim();
  if (dotenv.isInitialized) {
    final fromEnv = dotenv.env[key]?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
  }
  return '';
}

String get _firebaseApiKey =>
    _configValue(_firebaseApiKeyFromDefine, 'FIREBASE_API_KEY');
String get _firebaseProjectId =>
    _configValue(_firebaseProjectIdFromDefine, 'FIREBASE_PROJECT_ID');
String get _firebaseMessagingSenderId =>
    _configValue(
        _firebaseMessagingSenderIdFromDefine, 'FIREBASE_MESSAGING_SENDER_ID');
String get _firebaseAndroidAppId =>
    _configValue(_firebaseAndroidAppIdFromDefine, 'FIREBASE_ANDROID_APP_ID');
String get _firebaseIosAppId =>
    _configValue(_firebaseIosAppIdFromDefine, 'FIREBASE_IOS_APP_ID');
String get _firebaseIosBundleId =>
    _configValue(_firebaseIosBundleIdFromDefine, 'FIREBASE_IOS_BUNDLE_ID');
String get _firebaseStorageBucket =>
    _configValue(_firebaseStorageBucketFromDefine, 'FIREBASE_STORAGE_BUCKET');
const String _firebaseAndroidChannelId = 'chat_messages';
const String _firebaseAdminChannelId = 'admin_broadcasts';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

Future<void> _ensureFirebaseInitialized() async {
  if (kIsWeb || Firebase.apps.isNotEmpty) return;
  final options = _firebaseOptionsForCurrentPlatform();
  if (options == null) return;
  await Firebase.initializeApp(options: options);
}

FirebaseOptions? _firebaseOptionsForCurrentPlatform() {
  if (kIsWeb) return null;
  if (_firebaseApiKey.isEmpty ||
      _firebaseProjectId.isEmpty ||
      _firebaseMessagingSenderId.isEmpty) {
    return null;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      if (_firebaseAndroidAppId.isEmpty) return null;
      return FirebaseOptions(
        apiKey: _firebaseApiKey,
        appId: _firebaseAndroidAppId,
        messagingSenderId: _firebaseMessagingSenderId,
        projectId: _firebaseProjectId,
        storageBucket:
            _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
      );
    case TargetPlatform.iOS:
      if (_firebaseIosAppId.isEmpty || _firebaseIosBundleId.isEmpty)
        return null;
      return FirebaseOptions(
        apiKey: _firebaseApiKey,
        appId: _firebaseIosAppId,
        messagingSenderId: _firebaseMessagingSenderId,
        projectId: _firebaseProjectId,
        iosBundleId: _firebaseIosBundleId,
        storageBucket:
            _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
      );
    default:
      return null;
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _remotePushEnabled = false;
  String? _currentToken;
  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeLocalNotifications();

    if (!kIsWeb) {
      _remotePushEnabled = await _initializeFirebaseMessaging();
    }

    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _firebaseAndroidChannelId,
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _firebaseAdminChannelId,
        'Admin Broadcasts',
        description: 'Notifications sent by the marketplace admin',
        importance: Importance.high,
      ),
    );
  }

  Future<bool> _initializeFirebaseMessaging() async {
    try {
      debugPrint(
        '[Push] Firebase config status: '
        'apiKey=${_firebaseApiKey.isNotEmpty}, '
        'projectId=${_firebaseProjectId.isNotEmpty}, '
        'senderId=${_firebaseMessagingSenderId.isNotEmpty}, '
        'androidAppId=${_firebaseAndroidAppId.isNotEmpty}, '
        'iosAppId=${_firebaseIosAppId.isNotEmpty}, '
        'iosBundleId=${_firebaseIosBundleId.isNotEmpty}',
      );
      await _ensureFirebaseInitialized();
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '[Push] Firebase configuration missing. Push registration skipped.');
        return false;
      }

      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('[Push] Notification permission not granted.');
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _foregroundMessageSub ??=
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _messageOpenedSub ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _tokenRefreshSub ??=
          messaging.onTokenRefresh.listen(_registerTokenForCurrentUser);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        debugPrint('[Push] FCM token fetched: $token');
        await _registerTokenForCurrentUser(token);
      } else {
        debugPrint('[Push] Firebase Messaging returned an empty token.');
      }

      return true;
    } catch (e) {
      debugPrint('[Push] Failed to initialize Firebase Messaging: $e');
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;

    var granted = true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[Push] Firebase permission request failed: $e');
      granted = false;
    }

    final platformPermission = await Permission.notification.request();
    if (platformPermission.isDenied || platformPermission.isPermanentlyDenied) {
      granted = false;
    }

    return granted;
  }

  Future<void> syncPushToken() async {
    if (!_remotePushEnabled || kIsWeb) return;

    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    _currentToken = token;
    await _registerTokenForCurrentUser(token);
  }

  Future<void> handleAuthStateChange(
      AuthChangeEvent event, Session? session) async {
    if (!_remotePushEnabled) return;

    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.userUpdated ||
        event == AuthChangeEvent.tokenRefreshed) {
      await syncPushToken();
    }
  }

  Future<void> _registerTokenForCurrentUser(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('[Push] No signed in user. Token registration deferred.');
      return;
    }

    if (_lastRegisteredToken == token && _lastRegisteredUserId == user.id) {
      debugPrint('[Push] Token already registered for current user; skipping.');
      return;
    }

    try {
      await Supabase.instance.client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': defaultTargetPlatform.name,
        'p_device_name': defaultTargetPlatform.name,
      });
      _lastRegisteredToken = token;
      _lastRegisteredUserId = user.id;
      debugPrint('[Push] Registered push token for user ${user.id}');
      debugPrint('[Push] Registered FCM token: $token');
    } catch (e) {
      debugPrint('[Push] Failed to register token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;
    final title = notification?.title ?? data['title'] ?? 'Mechanic Part';
    final body =
        notification?.body ?? data['body'] ?? 'You have a new notification.';
    final conversationId = data['conversation_id']?.toString();
    final kind = data['type']?.toString() ?? 'general';

    if (kind == 'chat_message' &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      await showMessageNotification(
        senderName: title.replaceFirst('New message from ', '').trim(),
        message: body,
        conversationId: conversationId,
        playSound: false,
      );
      return;
    }

    await showSystemNotification(
      title: title,
      body: body,
      payload: data.isEmpty ? null : data.toString(),
      channelId: kind == 'admin_broadcast'
          ? _firebaseAdminChannelId
          : _firebaseAndroidChannelId,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[Push] Notification opened: ${message.data}');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[Push] Local notification tapped: ${response.payload}');
  }

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
      _firebaseAndroidChannelId,
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
    String channelId = _firebaseAdminChannelId,
  }) async {
    if (!_isInitialized) await initialize();
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _firebaseAdminChannelId
          ? 'Admin Broadcasts'
          : 'General Notifications',
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

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
