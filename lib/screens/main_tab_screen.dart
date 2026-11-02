import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'app_lock/app_session_state.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';
import 'package:first_app/push_notification_service.dart';

class MainTabScreen extends StatefulWidget {
  final bool isNewSignup;

  const MainTabScreen({super.key, this.isNewSignup = false});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // This is the moment a real authenticated session actually begins —
    // AppLockGate uses this flag to know whether it should even consider
    // locking on the next background/resume cycle.
    AppSessionState.isActive = true;
    PushNotificationService.initialize();
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(
        isNewSignup: widget.isNewSignup,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
      ),
      const InsightsScreen(),
      const ScheduleScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (icon: Icons.home_filled, label: 'Home'),
      (icon: Icons.bar_chart, label: 'Insights'),
      (icon: Icons.calendar_today_outlined, label: 'Schedule'),
      (icon: Icons.person_outline, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final active = i == _currentIndex;
            final color = active ? AppColors.teal : AppColors.textMuted;
            return InkWell(
              onTap: () => setState(() => _currentIndex = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].icon, size: 26, color: color),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: TextStyle(fontSize: 13, color: color),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
