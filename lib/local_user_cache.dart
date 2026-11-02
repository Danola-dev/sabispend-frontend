import 'package:shared_preferences/shared_preferences.dart';

/// Simple local cache for the logged-in user's basic profile info —
/// avoids a network round-trip every time a screen wants to show the
/// user's name/email/phone. Populate this once at login/signup success
/// (see the note in chat for where to call .save()), and clear it on
/// logout (already wired into ProfileScreen's log-out button).
class LocalUserCache {
  static const _keyName = 'cached_user_name';
  static const _keyEmail = 'cached_user_email';
  static const _keyPhone = 'cached_user_phone';

  static Future<void> save({String? name, String? email, String? phone}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString(_keyName, name);
    if (email != null) await prefs.setString(_keyEmail, email);
    if (phone != null) await prefs.setString(_keyPhone, phone);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
  }
}
