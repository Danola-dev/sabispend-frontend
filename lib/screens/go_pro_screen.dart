import 'dart:io';

import 'package:first_app/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/token_storage.dart';

const String kProEntitlement = 'pro';
// EDIT THESE: pages must exist and open without logging in.
const String kTermsUrl = 'https://app.sabispend.online/terms.html';
const String kPrivacyUrl = 'https://app.sabispend.online/privacy.html';

class GoProScreen extends StatefulWidget {
  const GoProScreen({super.key});

  @override
  State<GoProScreen> createState() => _GoProScreenState();
}

enum _PlanOption { monthly, yearly }

class _GoProScreenState extends State<GoProScreen> {
  _PlanOption _selectedPlan = _PlanOption.yearly;

  bool _isAlreadyPro = false;

  Package? _monthly;
  Package? _annual;
  bool _isLoadingOffers = true;
  String? _loadError;
  bool _isBuying = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  /// Asks our server to confirm the purchase with RevenueCat.
  Future<bool> _syncWithBackend() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final res = await ApiClient.post(
        '/ai-chat/subscription/sync/',
        {},
        accessToken: token,
      );
      return res['is_pro'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoadingOffers = true;
      _loadError = null;
    });

    // 1. Ask our own server first: is this user already Pro?
    String? userId;
    try {
      final token = await TokenStorage.getAccessToken();
      final status = await ApiClient.get(
        '/ai-chat/status/',
        accessToken: token,
      );
      userId = status['user_id']?.toString();
      if (status['is_pro'] == true) {
        if (!mounted) return;
        setState(() {
          _isAlreadyPro = true;
          _isLoadingOffers = false;
        });
        return;
      }
    } catch (_) {
      // Carry on: we can still show the store prices.
    }

    // 2. Otherwise load the store prices.
    try {
      if (userId != null && userId.isNotEmpty) {
        await Purchases.logIn(userId);
      }
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (!mounted) return;
      setState(() {
        _monthly = current?.monthly;
        _annual = current?.annual;
        _isLoadingOffers = false;
        if (_monthly == null && _annual == null) {
          _loadError =
              'Subscriptions aren\'t available yet. Please try again later.';
        } else if (_annual == null) {
          _selectedPlan = _PlanOption.monthly;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOffers = false;
        _loadError =
            'Subscriptions aren\'t available yet. Please try again later.';
      });
    }
  }

  Package? get _selectedPackage =>
      _selectedPlan == _PlanOption.yearly ? _annual : _monthly;

  String? get _yearlyBadge {
    final m = _monthly?.storeProduct.price;
    final a = _annual?.storeProduct.price;
    if (m == null || a == null || m <= 0) return null;
    final pct = ((1 - a / (m * 12)) * 100).round();
    return pct > 0 ? 'SAVE $pct%' : null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _hasPro() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(kProEntitlement);
  }

  void _openChat() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AIChatScreen()));
  }

  Future<void> _buy() async {
    final pkg = _selectedPackage;
    if (pkg == null || _isBuying || _isRestoring) return;
    setState(() => _isBuying = true);
    try {
      await Purchases.purchasePackage(pkg);
      final isPro = await _hasPro() && await _syncWithBackend();
      if (!mounted) return;
      if (isPro) {
        _openChat();
      } else {
        _snack('Your purchase is being processed. Pro will unlock shortly.');
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _snack('The purchase didn\'t go through. Please try again.');
      }
    } catch (_) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  Future<void> _restore() async {
    if (_isBuying || _isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      await Purchases.restorePurchases();
      final isPro = await _hasPro() && await _syncWithBackend();
      if (!mounted) return;
      if (isPro) {
        _openChat();
      } else {
        _snack('No active subscription found for this account.');
      }
    } catch (_) {
      _snack('Couldn\'t restore purchases. Please try again.');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _openLink(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _snack('Couldn\'t open the link.');
  }

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
                  if (_isAlreadyPro)
                    _buildAlreadyPro()
                  else ...[
                    _buildPricing(),
                    const SizedBox(height: 18),
                    _buildContinueButton(),
                    const SizedBox(height: 10),
                    _buildRestoreAndLegal(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyPro() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.tealTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.teal,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'You\'re a Pro member',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your subscription is active. Enjoy the AI chat and advanced insights.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openChat,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Open AI chat',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
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
              color: Colors.white.withValues(alpha: 0.15),
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
            'AI-powered insights and deeper\nunderstanding of your spending.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    // Only list features that really exist and are gated by Pro.
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

  Widget _buildPricing() {
    if (_isLoadingOffers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    if (_loadError != null) {
      return Column(
        children: [
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          TextButton(onPressed: _loadOfferings, child: const Text('Try again')),
        ],
      );
    }
    return Row(
      children: [
        if (_monthly != null)
          Expanded(
            child: _pricingCard(
              option: _PlanOption.monthly,
              label: 'Monthly',
              price: _monthly!.storeProduct.priceString,
              period: '/mo',
            ),
          ),
        if (_monthly != null && _annual != null) const SizedBox(width: 10),
        if (_annual != null)
          Expanded(
            child: _pricingCard(
              option: _PlanOption.yearly,
              label: 'Yearly',
              price: _annual!.storeProduct.priceString,
              period: '/yr',
              badge: _yearlyBadge,
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
            width: double.infinity,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
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
    final enabled = _selectedPackage != null && !_isBuying && !_isRestoring;
    final label = _selectedPlan == _PlanOption.yearly
        ? 'Continue with Yearly'
        : 'Continue with Monthly';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? _buy : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealDark : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _isBuying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }

  Widget _buildRestoreAndLegal() {
    final store = Platform.isIOS ? 'Apple ID' : 'Google Play account';
    final manage = Platform.isIOS
        ? 'your App Store account settings'
        : 'the Google Play Store subscriptions page';

    return Column(
      children: [
        TextButton(
          onPressed: (_isBuying || _isRestoring) ? null : _restore,
          child: Text(
            _isRestoring ? 'Restoring...' : 'Restore purchases',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.teal,
            ),
          ),
        ),
        Text(
          'Payment is charged to your $store at confirmation of purchase. '
          'The subscription renews automatically unless it is cancelled at '
          'least 24 hours before the end of the current period. You can manage '
          'or cancel it in $manage.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openLink(kTermsUrl),
              child: const Text(
                'Terms of Use',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const Text('·', style: TextStyle(color: AppColors.textMuted)),
            TextButton(
              onPressed: () => _openLink(kPrivacyUrl),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
