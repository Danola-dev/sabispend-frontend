import 'package:first_app/screens/auth/biometric_auth_service.dart';
import 'package:first_app/screens/auth/welcome_back_screen.dart';
import 'package:flutter/material.dart';
import 'app_lock_service.dart';
import 'app_session_state.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppLockService.recordPaused();
    } else if (state == AppLifecycleState.resumed) {
      _checkIfShouldLock();
    }
  }

  Future<void> _checkIfShouldLock() async {
    if (!AppSessionState.isActive) return;

    final shouldLock = await AppLockService.shouldLock();
    if (!shouldLock || !mounted) return;

    // Try biometric FIRST, silently — before ever showing the PIN
    // screen. If it succeeds, unlock immediately and skip the lock
    // screen entirely.
    final biometricEnabled = await BiometricAuthService.isEnabled();
    if (biometricEnabled) {
      final success = await BiometricAuthService.authenticate(
        reason: 'Unlock to continue',
      );
      if (success) {
        AppLockService.clearPausedState();
        return; // never shows the lock screen at all
      }
      // Cancelled or failed — fall through to the normal PIN screen below.
    }

    if (mounted) setState(() => _isLocked = true);
  }

  void _handleUnlocked() {
    AppLockService.clearPausedState();
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (settings) => PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      WelcomeBackScreen(onUnlocked: _handleUnlocked),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
