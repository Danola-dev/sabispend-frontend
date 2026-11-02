import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'create_account_screen.dart';

class OnboardingSlidesScreen extends StatefulWidget {
  const OnboardingSlidesScreen({super.key});

  @override
  State<OnboardingSlidesScreen> createState() => _OnboardingSlidesScreenState();
}

class _OnboardingSlidesScreenState extends State<OnboardingSlidesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final List<_SlideData> _slides = [
    _SlideData(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Control how you spend',
      description:
          'Get paid out daily, weekly, or monthly — never all at once, so your money lasts.',
    ),
    _SlideData(
      icon: Icons.bolt_outlined,
      title: 'Bills, sorted instantly',
      description:
          'Pay electricity, airtime, and data straight from your wallet, whenever you need to.',
    ),
    _SlideData(
      icon: Icons.shield_outlined,
      title: 'Never run dry',
      description:
          'Unlock a bit of your locked balance — it\'s always your call.',
    ),
  ];

  void _goToCreateAccount() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextButton(
                  onPressed: _goToCreateAccount,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _buildSlide(_slides[index]),
              ),
            ),
            _buildDotIndicators(),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (isLastPage) {
                      _goToCreateAccount();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isLastPage ? 'Get started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_SlideData slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.tealTint,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(slide.icon, size: 54, color: AppColors.teal),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 0, 0, 0),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.teal : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String description;

  _SlideData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
