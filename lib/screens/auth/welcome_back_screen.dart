import 'package:first_app/screens/auth/biometric_auth_service.dart';
import 'package:first_app/screens/auth/create_account_screen.dart';
import 'package:first_app/screens/main_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/token_storage.dart';
import 'forgot_pin_screen.dart';

class WelcomeBackScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  final int biometricAttemptsUsed;

  const WelcomeBackScreen({
    super.key,
    this.onUnlocked,
    this.biometricAttemptsUsed = 0,
  });

  @override
  State<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends State<WelcomeBackScreen> {
  String _cachedEmail = '';
  String? _cachedFullName;

  static const int _maxBiometricAttempts = 2;
  late int _biometricAttempts = widget.biometricAttemptsUsed;

  bool get _canTryBiometric =>
      _biometricAvailableHere && _biometricAttempts < _maxBiometricAttempts;

  bool _showEmailInput = false;
  bool _hasCachedUser = false;
  final TextEditingController _emailInputController = TextEditingController();

  String _pinInput = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _biometricAvailableHere = false;
  bool _isAttemptingBiometric = false;

  bool _requires2FA = false;
  String _twoFAEmail = '';
  bool _isResendingCode = false;

  bool _lastIsAppUnlock = false;

  @override
  void initState() {
    super.initState();
    _loadCachedUser();
  }

  @override
  void dispose() {
    _emailInputController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedUser() async {
    final email = await LocalUserCache.getCachedEmail();
    final name = await LocalUserCache.getCachedName();
    final hasCached = email != null && email.isNotEmpty;

    final biometricEnabled = await BiometricAuthService.isEnabled();
    final biometricUsableHere = hasCached && biometricEnabled;

    if (biometricUsableHere && _biometricAttempts == 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryBiometricUnlock(),
      );
    }

    if (!mounted) return;
    setState(() {
      _cachedEmail = email ?? '';
      _cachedFullName = name;
      _hasCachedUser = hasCached;
      _showEmailInput = !hasCached;
      _biometricAvailableHere = biometricUsableHere;
      _isLoading = false;
    });

    if (biometricUsableHere) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryBiometricUnlock(),
      );
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (!_canTryBiometric ||
        _showEmailInput ||
        _isAttemptingBiometric ||
        _requires2FA) {
      return;
    }

    setState(() {
      _isAttemptingBiometric = true;
      _biometricAttempts++;
    });

    final success = await BiometricAuthService.authenticate(
      reason: 'Unlock to continue',
    );
    if (!mounted) return;
    setState(() => _isAttemptingBiometric = false);

    if (!success) {
      if (_biometricAttempts >= _maxBiometricAttempts) {
        setState(
          () => _errorMessage = 'Biometrics unavailable. Enter your PIN.',
        );
      }
      return;
    }

    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainTabScreen(isNewSignup: false),
        ),
        (route) => false,
      );
    }
  }

  bool get _isSwitchingAccount => _hasCachedUser && _showEmailInput;

  String get _activeEmail =>
      _showEmailInput ? _emailInputController.text.trim() : _cachedEmail;

  void _enterSwitchAccountMode() {
    setState(() {
      _showEmailInput = true;
      _emailInputController.clear();
      _pinInput = '';
      _errorMessage = null;
    });
  }

  void _cancelSwitchAccount() {
    setState(() {
      _showEmailInput = false;
      _pinInput = '';
      _errorMessage = null;
    });
  }

  void _cancelTwoFA() {
    setState(() {
      _requires2FA = false;
      _twoFAEmail = '';
      _pinInput = '';
      _errorMessage = null;
    });
  }

  Future<void> _handleResendCode() async {
    setState(() => _isResendingCode = true);
    try {
      await AuthApi.requestOtp(email: _twoFAEmail, purpose: 'login');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Code resent')));
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _isResendingCode = false);
    }
  }

  void _onDigitPressed(String digit) {
    if (_pinInput.length >= 6 || _isSubmitting) return;
    setState(() {
      _pinInput += digit;
      _errorMessage = null;
    });
    if (_pinInput.length == 6) {
      if (_requires2FA) {
        _handleVerify2FA();
      } else {
        _handleLogin();
      }
    }
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  Future<void> _handleLogin() async {
    if (_showEmailInput && !_activeEmail.contains('@')) {
      setState(() {
        _errorMessage = 'Enter a valid email address.';
        _pinInput = '';
      });
      return;
    }

    if (_activeEmail.isEmpty) {
      setState(() {
        _errorMessage = 'No email found. Please sign in again.';
        _pinInput = '';
      });
      return;
    }

    final isAppUnlock = !_showEmailInput;
    _lastIsAppUnlock = isAppUnlock;

    setState(() => _isSubmitting = true);
    try {
      final result = await AuthApi.login(
        email: _activeEmail,
        pin: _pinInput,
        isAppUnlock: isAppUnlock,
      );

      if (result.requires2FA) {
        if (!mounted) return;
        setState(() {
          _requires2FA = true;
          _twoFAEmail = result.email!;
          _pinInput = '';
          _errorMessage = null;
        });
        return;
      }

      await TokenStorage.saveTokens(
        access: result.access!,
        refresh: result.refresh!,
      );
      // CHANGED: now also caches phone, restored alongside email.
      await LocalUserCache.saveUser(
        email: _activeEmail,
        phone: result.phoneNumber!,
        name: result.fullName!,
      );

      if (!mounted) return;

      final wasAccountChange = _showEmailInput;

      if (widget.onUnlocked != null && !wasAccountChange) {
        widget.onUnlocked!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainTabScreen(isNewSignup: false),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _pinInput = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
        _pinInput = '';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleVerify2FA() async {
    setState(() => _isSubmitting = true);
    try {
      final (
        access,
        refresh,
        fullName,
        phoneNumber,
      ) = await AuthApi.verify2FALogin(
        email: _twoFAEmail,
        code: _pinInput,
        isAppUnlock: _lastIsAppUnlock,
      );

      await TokenStorage.saveTokens(access: access, refresh: refresh);
      // CHANGED: now also caches phone.
      await LocalUserCache.saveUser(
        email: _twoFAEmail,
        phone: phoneNumber,
        name: fullName,
      );

      if (!mounted) return;

      final wasAccountChange = _showEmailInput;

      if (widget.onUnlocked != null && !wasAccountChange) {
        widget.onUnlocked!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainTabScreen(isNewSignup: false),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _pinInput = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
        _pinInput = '';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: keyboardOpen ? null : _buildTrustFooter(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 34),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 20),
              ],
              if (_showEmailInput && !_requires2FA) ...[
                _buildEmailInputField(),
                const SizedBox(height: 35),
              ],
              _buildPinDots(),
              const SizedBox(height: 40),
              if (_requires2FA)
                _buildTwoFAActionLinks()
              else
                _buildActionLinks(),
              const SizedBox(height: 40),
              (_isAttemptingBiometric || _isSubmitting)
                  ? const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.teal),
                      ),
                    )
                  : _buildKeypad(),
              if (_canTryBiometric &&
                  !_showEmailInput &&
                  !_isSubmitting &&
                  !_isAttemptingBiometric &&
                  !_requires2FA) ...[
                const SizedBox(height: 16),
                _buildBiometricRetryButton(),
              ],
              const SizedBox(height: 40),
              if (!_requires2FA) _buildSwitchAccount(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricRetryButton() {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _tryBiometricUnlock,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.tealTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fingerprint, size: 28, color: AppColors.teal),
        ),
      ),
    );
  }

  Widget _buildTrustFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: Color.fromARGB(255, 11, 11, 12),
            ),
            SizedBox(width: 3.5),
            Flexible(
              child: Text(
                'In partnership with PayVessel and PalmPay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color.fromARGB(255, 23, 24, 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String title;
    final String subtitle;
    final String avatarText;

    if (_requires2FA) {
      title = 'Enter the code';
      subtitle = 'We sent a 6-digit code to $_twoFAEmail';
      avatarText = '🔒';
    } else if (!_hasCachedUser) {
      title = 'Sign in';
      subtitle = 'Enter your email and PIN.';
      avatarText = '👋';
    } else if (_isSwitchingAccount) {
      title = 'Switch account';
      subtitle = 'Enter another account\'s email and PIN.';
      avatarText = '👋';
    } else {
      final firstName = (_cachedFullName?.isNotEmpty ?? false)
          ? _cachedFullName!.split(' ').first
          : null;
      title = firstName != null ? 'Welcome back, $firstName' : 'Welcome back';
      subtitle = _canTryBiometric
          ? 'Use biometrics or enter your PIN to continue'
          : 'Enter your PIN to continue';

      avatarText = (_cachedFullName?.isNotEmpty ?? false)
          ? _cachedFullName![0]
          : '👋';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                avatarText,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ),
            const Spacer(),
            if (_isSwitchingAccount && !_requires2FA)
              InkWell(
                onTap: _cancelSwitchAccount,
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFD64545)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFD64545),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailInputField() {
    return TextField(
      controller: _emailInputController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'you@email.com',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < _pinInput.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.teal : Colors.transparent,
            border: Border.all(
              color: filled
                  ? AppColors.teal
                  : const Color.fromARGB(255, 163, 167, 172),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => ForgotPinScreen())),
          child: const Text(
            'Forgot PIN?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.teal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoFAActionLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: _cancelTwoFA,
          child: const Text(
            'Back',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 24),
        InkWell(
          onTap: _isResendingCode ? null : _handleResendCode,
          child: Text(
            _isResendingCode ? 'Sending...' : 'Resend code',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.teal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchAccount() {
    if (_hasCachedUser && !_isSwitchingAccount) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: _enterSwitchAccountMode,
            child: const Text(
              'Switch account',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ],
      );
    }

    if (!_hasCachedUser || _isSwitchingAccount) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Don\'t have an account yet?',
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => CreateAccountScreen()),
            ),
            child: const Text(
              'Create one',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildKeypad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        if (key == 'back') {
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _onBackspace,
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
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onDigitPressed(key),
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
    );
  }
}
