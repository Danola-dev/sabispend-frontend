import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notifications_api.dart';

/// Must be a TOP-LEVEL function (not a class method) — this runs in a
/// separate isolate when a message arrives while the app is backgrounded
/// or fully closed. No custom logic needed here for basic display: FCM
/// shows the system notification automatically in this state, since our
/// backend's send_notification always includes a title/body — this
/// handler just needs to exist so Firebase knows background messages
/// are being handled at all.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'high_importance_channel';
  static const _channelName = 'Important Notifications';

  // NEW: broadcasts "a push just arrived while the app is open" so screens
  // (like Home) can refresh their data without polling the backend.
  static final StreamController<void> _incomingController =
      StreamController<void>.broadcast();
  static Stream<void> get onForegroundMessage => _incomingController.stream;

  /// Call this once, from a point where the user is known to be
  /// authenticated (registering a device token requires a valid access
  /// token) — MainTabScreen.initState() is the natural single choke
  /// point, since every login path eventually lands there.
  static Future<void> initialize() async {
    if (_initialized) {
      return; // guards against double-init if called from more than one place
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // iOS and Android 13+ both require an explicit runtime permission
    // request — without this, tokens can still be issued but the OS
    // will silently never actually show anything.
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _setupLocalNotifications();

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);

    // Tokens can change (app reinstall, data cleared, etc.) — re-register
    // automatically whenever that happens, not just once at startup.
    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages need to be shown manually — see the note above.
    // CHANGED: still shows the banner, and now also tells listeners (the
    // home screen) that a message arrived so they can refresh.
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _incomingController.add(null);
    });
  }

  static Future<void> _registerToken(String token) async {
    try {
      await NotificationsApi.registerDevice(
        fcmToken: token,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // Silent — worst case it retries on the next token refresh or app
      // open; not worth surfacing an error for a background registration.
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings: settings);

    // Android 8+ requires notification channels to be created explicitly
    // before they can be used — this matches the channel referenced in
    // _showLocalNotification below.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
