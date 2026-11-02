import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'change_payment_pin.dart';
import 'auth/forgot_transaction_pin_screen.dart';

class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Payment settings',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.tealDark,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.teal,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Change PIN'),
              Tab(text: 'Forgot PIN'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SettingsActionTab(
              icon: Icons.lock_reset_outlined,
              title: 'Change your payment PIN',
              description:
                  'Update the PIN you use to authorize transfers. You\'ll need to enter your current PIN first, then confirm with a code sent to your phone.',
              buttonLabel: 'Change PIN',
              destination: ChangePaymentPinScreen(),
            ),
            _SettingsActionTab(
              icon: Icons.help_outline_rounded,
              title: 'Forgot your payment PIN?',
              description:
                  'We\'ll send a code to your registered email to verify it\'s you, then let you set a new PIN.',
              buttonLabel: 'Reset PIN',
              destination: ForgotTransactionPinScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Widget destination;

  const _SettingsActionTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.tealTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => destination)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
