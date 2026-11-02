import 'api_client.dart';
import 'token_storage.dart';

class ChatMessageResult {
  final int id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessageResult({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageResult.fromJson(Map<String, dynamic> json) {
    return ChatMessageResult(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AIChatStatus {
  final bool isPro;
  final int messagesUsedThisMonth;
  final int monthlyLimit;

  AIChatStatus({
    required this.isPro,
    required this.messagesUsedThisMonth,
    required this.monthlyLimit,
  });

  factory AIChatStatus.fromJson(Map<String, dynamic> json) {
    return AIChatStatus(
      isPro: json['is_pro'] as bool,
      messagesUsedThisMonth: json['messages_used_this_month'] as int,
      monthlyLimit: json['monthly_limit'] as int,
    );
  }

  bool get hasReachedLimit => messagesUsedThisMonth >= monthlyLimit;
}

class AIChatApi {
  static Future<AIChatStatus> getStatus() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/ai-chat/status/',
      accessToken: token,
    );
    return AIChatStatus.fromJson(response);
  }

  static Future<List<ChatMessageResult>> getHistory() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/ai-chat/history/',
      accessToken: token,
    );
    return response
        .map((json) => ChatMessageResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<ChatMessageResult> sendMessage(String content) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/ai-chat/send/', {
      'content': content,
    }, accessToken: token);
    return ChatMessageResult.fromJson(response);
  }
}
