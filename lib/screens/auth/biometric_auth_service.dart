import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric login is purely local — it never talks to your backend.
/// It just decides whether the app-unlock screen can skip asking for
/// the PIN, since your real session (access/refresh tokens) is already
/// securely stored via flutter_secure_storage regardless.
class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const _prefKey = 'biometric_login_enabled';

  /// Whether this device even supports biometrics AND has some
  /// enrolled (Face ID set up, a fingerprint registered, etc).
  static Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the actual system Face ID/fingerprint prompt. Returns
  /// true only on genuine success — false for cancellation, failure,
  /// or any error (never throws out to the caller).
  static Future<bool> authenticate({
    String reason = 'Confirm it\'s you',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly:
            true, // don't fall back to device PIN/pattern here — this app has its own PIN screen for that
        persistAcrossBackgrounding:
            true, // survives the app briefly backgrounding mid-prompt (e.g. a notification) — this is the 3.x name for what used to be "stickyAuth"
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
