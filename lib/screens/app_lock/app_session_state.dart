/// Tracks whether the user is CURRENTLY inside the authenticated app
/// (MainTabScreen is mounted) — separate from whether a token merely
/// exists in storage.
///
/// This distinction is what fixes the double-PIN-entry bug: a token can
/// exist in storage from a previous session while the user is sitting on
/// WelcomeBackScreen, not yet logged in for THIS session. AppLockGate
/// checking token-existence alone would incorrectly treat that as "an
/// active session that could time out," triggering a redundant lock
/// prompt on top of the login screen already showing.
///
/// Deliberately in-memory only (not persisted) — it should always start
/// false on a fresh app process, since nothing is active yet.
class AppSessionState {
  static bool isActive = false;
}
