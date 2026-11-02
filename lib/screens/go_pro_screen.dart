import 'package:first_app/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';

class GoProScreen extends StatefulWidget {
  const GoProScreen({super.key});

  @override
  State<GoProScreen> createState() => _GoProScreenState();
}

enum _PlanOption { monthly, yearly }

class _GoProScreenState extends State<GoProScreen> {
  _PlanOption _selectedPlan = _PlanOption.yearly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroHeader(context),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFeatureList(),
                  const SizedBox(height: 22),
                  _buildPricingCards(),
                  const SizedBox(height: 18),
                  _buildContinueButton(),
                  const SizedBox(height: 10),
                  const Text(
                    'Cancel anytime. Renews automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 8, 8, 9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.tealDark, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 20, color: Colors.white70),
                ),
              ),
              const Text(
                'GO PRO',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unlock the full experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI-powered insights, deeper control,\nand priority access to your money.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      (
        icon: Icons.chat_bubble_outline_rounded,
        title: 'AI money chat',
        description:
            'Ask questions about your spending and get instant, personalized answers.',
      ),
      (
        icon: Icons.insights_rounded,
        title: 'Advanced insights',
        description:
            'Deeper spending trends, forecasts, and category breakdowns.',
      ),
      (
        icon: Icons.bolt_rounded,
        title: 'Priority unlocks',
        description: 'No limits on early payout unlocks, with lower fees.',
      ),
      (
        icon: Icons.receipt_long_rounded,
        title: 'Zero bill payment fees',
        description:
            'Pay airtime, data, and electricity with no service charge.',
      ),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tealTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(feature.icon, size: 19, color: AppColors.teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      feature.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 34, 36, 38),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricingCards() {
    return Row(
      children: [
        Expanded(
          child: _pricingCard(
            option: _PlanOption.monthly,
            label: 'Monthly',
            price: '₦1,500',
            period: '/mo',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pricingCard(
            option: _PlanOption.yearly,
            label: 'Yearly',
            price: '₦12,000',
            period: '/yr',
            badge: 'SAVE 33%',
          ),
        ),
      ],
    );
  }

  Widget _pricingCard({
    required _PlanOption option,
    required String label,
    required String price,
    required String period,
    String? badge,
  }) {
    final selected = _selectedPlan == option;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedPlan = option),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.tealTint : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.tealDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: period,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tealDark,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10.5,
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

  Widget _buildContinueButton() {
    final label = _selectedPlan == _PlanOption.yearly
        ? 'Continue with Yearly'
        : 'Continue with Monthly';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AIChatScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.tealDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
