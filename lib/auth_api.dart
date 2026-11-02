import 'api_client.dart';
import 'token_storage.dart';

class LoginResult {
  final bool requires2FA;
  final String? access;
  final String? refresh;
  final String? fullName;
  final String? phoneNumber; // now populated on success too, not just 2FA
  final String? email; // populated only when requires2FA is true

  LoginResult.success({
    required String access,
    required String refresh,
    required String fullName,
    required String phoneNumber,
  }) : requires2FA = false,
       access = access,
       refresh = refresh,
       fullName = fullName,
       phoneNumber = phoneNumber,
       email = null;

  LoginResult.requires2FA({required String email})
    : requires2FA = true,
      access = null,
      refresh = null,
      fullName = null,
      phoneNumber = null,
      email = email;
}

class AuthApi {
  static Future<String> signup({
    required String fullName,
    required String email,
    required String phoneNumber,
  }) async {
    final response = await ApiClient.post('/auth/signup/', {
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
    });
    return response['email'] as String;
  }

  static Future<void> requestOtp({
    required String email,
    required String purpose,
  }) async {
    await ApiClient.post('/auth/otp/request/', {
      'email': email,
      'purpose': purpose,
    });
  }

  static Future<String?> verifyOtp({
    required String email,
    required String purpose,
    required String code,
  }) async {
    final response = await ApiClient.post('/auth/otp/verify/', {
      'email': email,
      'purpose': purpose,
      'code': code,
    });
    return (response['pin_setup_token'] ?? response['pin_reset_token'])
        as String?;
  }

  static Future<(String, String)> setPin({
    required String pinSetupToken,
    required String pin,
  }) async {
    final response = await ApiClient.post('/auth/pin/set/', {
      'pin': pin,
    }, accessToken: pinSetupToken);
    return (response['access'] as String, response['refresh'] as String);
  }

  static Future<(String, String)> resetPin({
    required String pinResetToken,
    required String pin,
  }) async {
    final response = await ApiClient.post('/auth/pin/reset/', {
      'pin': pin,
    }, accessToken: pinResetToken);
    return (response['access'] as String, response['refresh'] as String);
  }

  static Future<String> verifyCurrentPin(
    String pin, {
    required String accessToken,
  }) async {
    final response = await ApiClient.post('/auth/pin/verify-current/', {
      'pin': pin,
    }, accessToken: accessToken);
    return response['email'] as String;
  }

  static Future<LoginResult> login({
    required String email,
    required String pin,
    required bool isAppUnlock,
  }) async {
    final response = await ApiClient.post('/auth/login/', {
      'email': email,
      'pin': pin,
      'is_app_unlock': isAppUnlock,
    });

    if (response['requires_2fa'] == true) {
      return LoginResult.requires2FA(email: response['email'] as String);
    }

    final user = response['user'] as Map<String, dynamic>;
    return LoginResult.success(
      access: response['access'] as String,
      refresh: response['refresh'] as String,
      fullName: user['full_name'] as String,
      phoneNumber: user['phone_number'] as String,
    );
  }

  /// CHANGED: now returns (access, refresh, fullName, phoneNumber) —
  /// phone is needed to fully populate LocalUserCache after a 2FA login.
  static Future<(String, String, String, String)> verify2FALogin({
    required String email,
    required String code,
    required bool isAppUnlock,
  }) async {
    final response = await ApiClient.post('/auth/2fa/verify-login/', {
      'email': email,
      'code': code,
      'is_app_unlock': isAppUnlock,
    });
    final user = response['user'] as Map<String, dynamic>;
    return (
      response['access'] as String,
      response['refresh'] as String,
      user['full_name'] as String,
      user['phone_number'] as String,
    );
  }

  static Future<bool> get2FAStatus({required String accessToken}) async {
    final response = await ApiClient.get(
      '/auth/2fa/status/',
      accessToken: accessToken,
    );
    return response['is_2fa_enabled'] as bool;
  }

  static Future<void> enable2FAConfirm({
    required String code,
    required String accessToken,
  }) async {
    await ApiClient.post('/auth/2fa/enable/confirm/', {
      'code': code,
    }, accessToken: accessToken);
  }

  static Future<void> disable2FA({
    required String pin,
    required String accessToken,
  }) async {
    await ApiClient.post('/auth/2fa/disable/', {
      'pin': pin,
    }, accessToken: accessToken);
  }

  static Future<void> deleteAccount(String pin) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/auth/delete-account/', {
      'pin': pin,
    }, accessToken: token);
  }

  static Future<void> logout({required String refreshToken}) async {
    await ApiClient.post('/auth/logout/', {'refresh': refreshToken});
  }
}
