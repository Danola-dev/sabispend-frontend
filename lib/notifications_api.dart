import 'api_client.dart';
import 'token_storage.dart';

class NotificationResult {
  final int id;
  final String notificationType;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  NotificationResult({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.isRead,
    required this.metadata,
    required this.createdAt,
  });

  factory NotificationResult.fromJson(Map<String, dynamic> json) {
    return NotificationResult(
      id: json['id'] as int,
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationsApi {
  static Future<List<NotificationResult>> getList() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/notifications/',
      accessToken: token,
    );
    return response
        .map(
          (json) => NotificationResult.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> deleteNotification(int notificationId) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.delete(
      '/notifications/$notificationId/delete/',
      accessToken: token,
    );
  }

  static Future<int> getUnreadCount() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/notifications/unread-count/',
      accessToken: token,
    );
    return response['unread_count'] as int;
  }

  static Future<void> markRead(int notificationId) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post(
      '/notifications/$notificationId/mark-read/',
      {},
      accessToken: token,
    );
  }

  static Future<void> markAllRead() async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post(
      '/notifications/mark-all-read/',
      {},
      accessToken: token,
    );
  }

  /// Ready for Phase 2 (real push) — not called from anywhere yet since
  /// there's no FCM token to register until Firebase is set up.
  static Future<void> registerDevice({
    required String fcmToken,
    required String deviceType,
  }) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/notifications/register-device/', {
      'fcm_token': fcmToken,
      'device_type': deviceType,
    }, accessToken: token);
  }
}
