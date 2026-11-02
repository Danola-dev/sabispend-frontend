import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const _pausedAtKey = 'app_paused_at_millis';
  static const Duration lockTimeout = Duration(seconds: 10);

  static Future<void> recordPaused() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_pausedAtKey, now);
    debugPrint('AppLockService: recorded paused at $now');
  }

  static Future<bool> shouldLock() async {
    final prefs = await SharedPreferences.getInstance();
    final pausedAtMillis = prefs.getInt(_pausedAtKey);

    if (pausedAtMillis == null) {
      debugPrint('AppLockService: no paused timestamp found — not locking');
      return false;
    }

    final pausedAt = DateTime.fromMillisecondsSinceEpoch(pausedAtMillis);
    final elapsed = DateTime.now().difference(pausedAt);
    final result = elapsed >= lockTimeout;

    debugPrint(
      'AppLockService: elapsed ${elapsed.inSeconds}s since pause '
      '(timeout is ${lockTimeout.inSeconds}s) — shouldLock=$result',
    );

    return result;
  }

  static Future<void> clearPausedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pausedAtKey);
    debugPrint('AppLockService: cleared paused state');
  }
}
