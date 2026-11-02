import 'package:first_app/screens/app_lock/app_lock_gate.dart';
import 'package:first_app/screens/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Registered before runApp — must happen this early so a message
  // arriving while the app is fully closed still gets handled correctly.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const SabiSpendApp());
}

class SabiSpendApp extends StatelessWidget {
  const SabiSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SabiSpend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
      home: const SplashScreen(),
      // AppLockGate wraps every screen in the entire navigation stack,
      // automatically — this is the ONLY place it needs to be wired.
      // It checks internally whether a session exists before ever
      // showing the lock screen, so it's a no-op during onboarding/signup.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          // Keeps text at YOUR designed sizes regardless of the phone's
          // system font setting. Using .clamp() instead of .noScaling
          // still allows some accessibility scaling for users who
          // genuinely need it, just within a safe range that won't
          // break your layouts.
          textScaler: MediaQuery.of(
            context,
          ).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2),
        ),
        child: AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
