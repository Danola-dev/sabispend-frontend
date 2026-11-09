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
  bool _isCheckingBiometric = false;
  int _biometricAttemptsUsed = 0;
  DateTime? _lastBiometricAt;

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
      // The system biometric prompt can cause a pause on Android; don't record it.
      if (!_isCheckingBiometric && !_isLocked) AppLockService.recordPaused();
    } else if (state == AppLifecycleState.resumed) {
      _checkIfShouldLock();
    }
  }

  Future<void> _checkIfShouldLock() async {
    if (_isLocked || _isCheckingBiometric) return;
    if (!AppSessionState.isActive) return;

    // Ignore the 'resumed' event caused by the biometric prompt closing.
    final last = _lastBiometricAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 2)) {
      return;
    }

    _isCheckingBiometric = true; // set BEFORE any await
    bool unlocked = false;
    try {
      final shouldLock = await AppLockService.shouldLock();
      if (!shouldLock || !mounted) {
        _isCheckingBiometric = false;
        return;
      }

      if (await BiometricAuthService.isEnabled()) {
        _biometricAttemptsUsed = 1;
        unlocked = await BiometricAuthService.authenticate(
          reason: 'Unlock to continue',
        );
      }
    } finally {
      _isCheckingBiometric = false;
      _lastBiometricAt = DateTime.now();
    }

    if (unlocked) {
      AppLockService.clearPausedState();
      _biometricAttemptsUsed = 0;
      return;
    }
    if (mounted) setState(() => _isLocked = true);
  }

  void _handleUnlocked() {
    AppLockService.clearPausedState();
    _biometricAttemptsUsed = 0;
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
                      WelcomeBackScreen(
                        onUnlocked: _handleUnlocked,
                        biometricAttemptsUsed: _biometricAttemptsUsed,
                      ),
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
