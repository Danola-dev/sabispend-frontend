import 'package:first_app/auth_api.dart';
import 'package:first_app/kyc_api.dart';
import 'package:first_app/screens/auth/biometric_auth_service.dart';
import 'package:first_app/screens/app_lock/app_session_state.dart';
import 'package:first_app/screens/auth/two_factor_auth_screen.dart';
import 'package:first_app/screens/auth/welcome_back_screen.dart';
import 'package:first_app/screens/contact_support_screen.dart';
import 'package:first_app/screens/go_pro_screen.dart';
import 'package:first_app/screens/help_center_screen.dart';
import 'package:first_app/screens/legal_documents_screen.dart';
import 'package:first_app/screens/my_profile_screen.dart';
import 'package:first_app/token_storage.dart';
import 'package:first_app/api_client.dart';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'payment_settings_screen.dart';
import 'login_settings_screen.dart';
import 'transaction_history_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String subscriptionStatus = 'Free';
  static const String appVersion = 'Version 1.0.0';

  String _userName = '';
  String _userEmail = '';
  bool _isKycActive = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricSupported = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final name = await LocalUserCache.getCachedName();
    // CHANGED: now genuinely populated — LocalUserCache stores email now.
    final email = await LocalUserCache.getCachedEmail();

    bool kycActive = false;
    try {
      final kycStatus = await KYCApi.getStatus();
      kycActive = kycStatus.isActive;
    } catch (_) {}

    final biometricSupported = await BiometricAuthService.isDeviceSupported();
    final biometricEnabled = await BiometricAuthService.isEnabled();

    if (!mounted) return;
    setState(() {
      _userName = (name != null && name.isNotEmpty) ? name : 'User';
      _userEmail = email ?? '';
      _isKycActive = kycActive;
      _isBiometricSupported = biometricSupported;
      _isBiometricEnabled = biometricEnabled;
      _isLoading = false;
    });
  }

  Future<void> _handleBiometricToggle(bool newValue) async {
    if (newValue) {
      final success = await BiometricAuthService.authenticate(
        reason: 'Confirm it\'s you to enable biometric login',
      );
      if (!success) return;
    }
    await BiometricAuthService.setEnabled(newValue);
    if (mounted) setState(() => _isBiometricEnabled = newValue);
  }

  Future<void> _handleFullLogoutAndNavigate() async {
    await TokenStorage.clear();
    await LocalUserCache.clear();
    AppSessionState.isActive = false;

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeBackScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAccountHeader(context),
                    if (_isKycActive) ...[
                      const SizedBox(height: 14),
                      _buildVerificationBadge(),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionLabel('Account'),
                    const SizedBox(height: 4),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Go Pro subscription',
                        trailingText: subscriptionStatus,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GoProScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.description_outlined,
                        label: 'Transaction statements',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TransactionHistoryScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _buildSectionLabel('Security'),
                    const SizedBox(height: 4),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.payments_outlined,
                        label: 'Payment settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PaymentSettingsScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.login_outlined,
                        label: 'Login settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginSettingsScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.fingerprint,
                        label: 'Biometric login',
                        trailing: _isBiometricSupported
                            ? Switch(
                                value: _isBiometricEnabled,
                                activeColor: AppColors.teal,
                                onChanged: _handleBiometricToggle,
                              )
                            : const Text(
                                'Not available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                      ),
                      _SettingsItem(
                        icon: Icons.phonelink_lock_outlined,
                        label: 'Two-factor authentication',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TwoFactorAuthScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _buildSectionLabel('Preferences'),
                    const SizedBox(height: 4),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _buildSectionLabel('Support & legal'),
                    const SizedBox(height: 4),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help center',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => HelpCenterScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Contact support',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ContactSupportScreen(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy policy',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                LegalDocumentScreen.privacyPolicy(),
                          ),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.article_outlined,
                        label: 'Terms of service',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                LegalDocumentScreen.termsOfService(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildLogOutButton(context),
                    const SizedBox(height: 10),
                    _buildDeleteAccountButton(context),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        appVersion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 76, 79, 85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context) {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MyProfileScreen(
            name: _userName,
            email: _userEmail,
            isKycActive: _isKycActive,
            subscription: subscriptionStatus,
          ),
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'profile-avatar',
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.teal, AppColors.tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_isKycActive) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: AppColors.teal,
                      ),
                    ],
                  ],
                ),
                if (_userEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _userEmail,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.shield_outlined, size: 20, color: AppColors.teal),
          SizedBox(width: 6),
          Text(
            'Identity verified',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color.fromARGB(255, 0, 0, 0),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return InkWell(
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(12) : Radius.zero,
              bottom: i == items.length - 1
                  ? const Radius.circular(12)
                  : Radius.zero,
            ),
            onTap: item.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: AppColors.border, width: 0.5),
                      ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 19,
                    color: const Color.fromARGB(255, 23, 24, 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 16.5,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.trailing != null)
                    item.trailing!
                  else ...[
                    if (item.trailingText != null) ...[
                      Text(
                        item.trailingText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        try {
          final refreshToken = await TokenStorage.getRefreshToken();
          if (refreshToken != null)
            await AuthApi.logout(refreshToken: refreshToken);
        } catch (_) {}
        await _handleFullLogoutAndNavigate();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Log out',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDeleteAccountConfirmation(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: const Text(
          'Delete account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD64545),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete your account?',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'This permanently deletes your account, transaction history, and '
            'linked bank details. Any locked balance must be withdrawn first. '
            'This can\'t be undone.',
            style: TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 0, 0, 0),
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _promptPinAndDeleteAccount();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD64545),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _promptPinAndDeleteAccount() async {
    String pinInput = '';
    bool isSubmitting = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> handleComplete(String pin) async {
              setSheetState(() {
                isSubmitting = true;
                errorMessage = null;
              });
              try {
                await AuthApi.deleteAccount(pin);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                await _handleFullLogoutAndNavigate();
              } on ApiException catch (e) {
                setSheetState(() {
                  errorMessage = e.message;
                  pinInput = '';
                  isSubmitting = false;
                });
              } catch (e) {
                setSheetState(() {
                  errorMessage =
                      'Couldn\'t reach the server. Check your connection and try again.';
                  pinInput = '';
                  isSubmitting = false;
                });
              }
            }

            void onDigit(String digit) {
              if (isSubmitting || pinInput.length >= 6) return;
              final updated = pinInput + digit;
              setSheetState(() {
                pinInput = updated;
                errorMessage = null;
              });
              if (updated.length == 6) handleComplete(updated);
            }

            void onBackspace() {
              if (pinInput.isEmpty || isSubmitting) return;
              setSheetState(
                () => pinInput = pinInput.substring(0, pinInput.length - 1),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Confirm your PIN to delete',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD64545),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 220,
                    child: isSubmitting
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.teal,
                            ),
                          )
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(6, (index) {
                                  final filled = index < pinInput.length;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? const Color(0xFFD64545)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: filled
                                            ? const Color(0xFFD64545)
                                            : AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.6,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children:
                                      [
                                        '1',
                                        '2',
                                        '3',
                                        '4',
                                        '5',
                                        '6',
                                        '7',
                                        '8',
                                        '9',
                                        '',
                                        '0',
                                        'back',
                                      ].map((key) {
                                        if (key.isEmpty)
                                          return const SizedBox.shrink();
                                        if (key == 'back') {
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            onTap: onBackspace,
                                            child: const Center(
                                              child: Icon(
                                                Icons.backspace_outlined,
                                                size: 22,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          );
                                        }
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          onTap: () => onDigit(key),
                                          child: Center(
                                            child: Text(
                                              key,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  _SettingsItem({
    required this.icon,
    required this.label,
    this.trailingText,
    this.trailing,
    this.onTap,
  });
}
