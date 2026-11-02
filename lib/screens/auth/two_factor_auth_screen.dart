import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/token_storage.dart';

enum _Stage { loading, off, turningOnOtp, on, turningOffPin }

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  _Stage _stage = _Stage.loading;
  String _codeInput = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final enabled = await AuthApi.get2FAStatus(accessToken: token!);
      if (mounted) setState(() => _stage = enabled ? _Stage.on : _Stage.off);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.off);
    }
  }

  Future<void> _handleStartTurnOn() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final email = await LocalUserCache.getCachedEmail();
      if (email == null) throw Exception('No cached email');
      await AuthApi.requestOtp(email: email, purpose: 'login');
      if (!mounted) return;
      setState(() {
        _stage = _Stage.turningOnOtp;
        _codeInput = '';
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleStartTurnOff() {
    setState(() {
      _stage = _Stage.turningOffPin;
      _codeInput = '';
      _errorMessage = null;
    });
  }

  void _onDigitPressed(String digit) {
    final maxLength = 6;
    if (_isSubmitting || _codeInput.length >= maxLength) return;
    final updated = _codeInput + digit;
    setState(() {
      _codeInput = updated;
      _errorMessage = null;
    });
    if (updated.length == maxLength) {
      if (_stage == _Stage.turningOnOtp) {
        _handleConfirmTurnOn(updated);
      } else if (_stage == _Stage.turningOffPin) {
        _handleConfirmTurnOff(updated);
      }
    }
  }

  void _onBackspace() {
    if (_codeInput.isEmpty || _isSubmitting) return;
    setState(() => _codeInput = _codeInput.substring(0, _codeInput.length - 1));
  }

  Future<void> _handleConfirmTurnOn(String code) async {
    setState(() => _isSubmitting = true);
    try {
      final token = await TokenStorage.getAccessToken();
      await AuthApi.enable2FAConfirm(code: code, accessToken: token!);
      if (!mounted) return;
      setState(() => _stage = _Stage.on);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _codeInput = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
        _codeInput = '';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleConfirmTurnOff(String pin) async {
    setState(() => _isSubmitting = true);
    try {
      final token = await TokenStorage.getAccessToken();
      await AuthApi.disable2FA(pin: pin, accessToken: token!);
      if (!mounted) return;
      setState(() => _stage = _Stage.off);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _codeInput = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
        _codeInput = '';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            if (_stage == _Stage.turningOnOtp ||
                _stage == _Stage.turningOffPin) {
              _loadStatus();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text(
          'Two-factor authentication',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        );
      case _Stage.off:
        return _buildStatusView(
          isOn: false,
          title: 'Add an extra layer of security',
          description:
              'When enabled, we\'ll send a code to your email every time you log in — even if someone has your PIN, they can\'t get in without your email too.',
          buttonLabel: 'Turn on',
          onButtonTap: _handleStartTurnOn,
        );
      case _Stage.on:
        return _buildStatusView(
          isOn: true,
          title: 'Two-factor authentication is on',
          description:
              'You\'ll be asked for a code sent to your email every time you log in, in addition to your PIN.',
          buttonLabel: 'Turn off',
          onButtonTap: _handleStartTurnOff,
        );
      case _Stage.turningOnOtp:
        return _buildCodeEntry(
          title: 'Enter the code',
          subtitle: 'We sent a 6-digit code to your email.',
          maxLength: 6,
        );
      case _Stage.turningOffPin:
        return _buildCodeEntry(
          title: 'Confirm your PIN',
          subtitle:
              'Enter your login PIN to turn off two-factor authentication.',
          maxLength: 6,
        );
    }
  }

  Widget _buildStatusView({
    required bool isOn,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onButtonTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isOn ? AppColors.tealTint : AppColors.card,
            shape: BoxShape.circle,
            border: isOn ? null : Border.all(color: AppColors.border),
          ),
          child: Icon(
            isOn ? Icons.verified_user_rounded : Icons.phonelink_lock_outlined,
            color: isOn ? AppColors.teal : AppColors.textMuted,
            size: 26,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSubmitting ? null : onButtonTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOn ? const Color(0xFFFDECEC) : AppColors.tealDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isOn ? const Color(0xFFD64545) : Colors.white,
                    ),
                  )
                : Text(
                    buttonLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isOn ? const Color(0xFFD64545) : Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEntry({
    required String title,
    required String subtitle,
    required int maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (index) {
            final filled = index < _codeInput.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.teal : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.teal : AppColors.border,
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        if (_isSubmitting)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else
          _buildKeypad(),
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

  Widget _buildKeypad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
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