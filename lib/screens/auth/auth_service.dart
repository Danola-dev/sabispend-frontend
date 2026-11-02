import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');

    return token != null && token.isNotEmpty;
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);

    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
