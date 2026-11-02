import 'api_client.dart';
import 'token_storage.dart';

class SecurityApi {
  static Future<void> setTransactionPin(String pin) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/transaction_pin/transaction-pin/set/', {
      'pin': pin,
    }, accessToken: token);
  }

  static Future<void> verifyCurrentPin(String pin) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/transaction_pin/transaction-pin/verify-current/', {
      'pin': pin,
    }, accessToken: token);
  }

  /// CHANGED: returns the EMAIL the code was sent to now, not a phone
  /// number — backend forgot_pin_request_otp uses request.user.email.
  static Future<String> requestForgotPinOtp() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post(
      '/transaction_pin/transaction-pin/forgot/request-otp/',
      {},
      accessToken: token,
    );
    return response['email'] as String;
  }

  static Future<void> verifyAndResetPin({
    required String code,
    required String newPin,
  }) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post(
      '/transaction_pin/transaction-pin/forgot/verify-and-reset/',
      {'code': code, 'new_pin': newPin},
      accessToken: token,
    );
  }
}
