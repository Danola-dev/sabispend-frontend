import 'dart:async';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/token_storage.dart';
import 'onbaoarding_slides_screen.dart';
import 'welcome_back_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();

    _decideNextScreen();
  }

  Future<void> _decideNextScreen() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 3000));

    // CHANGED: checks cached EMAIL now, not phone — email is the real
    // identity signal since the login switch. Same reasoning as before:
    // a logged-out-but-previously-used device (tokens cleared, email
    // still cached) should land on Welcome Back, not raw onboarding.
    final cachedEmail = await LocalUserCache.getCachedEmail();

    await minDelay;
    if (!mounted) return;

    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeBackScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingSlidesScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'SabiSpend',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spend on your own schedule',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
