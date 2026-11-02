import 'api_client.dart';
import 'token_storage.dart';

class SupportApi {
  static Future<void> contactSupport({
    required String subject,
    required String message,
  }) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/support/contact/', {
      'subject': subject,
      'message': message,
    }, accessToken: token);
  }
}
