import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/token_storage.dart';
import 'package:first_app/screens/auth/otp_verification_screen.dart';

class ChangeLoginPinScreen extends StatefulWidget {
  const ChangeLoginPinScreen({super.key});

  @override
  State<ChangeLoginPinScreen> createState() => _ChangeLoginPinScreenState();
}

class _ChangeLoginPinScreenState extends State<ChangeLoginPinScreen> {
  String _pinInput = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_isSubmitting || _pinInput.length >= 6) return;
    final updated = _pinInput + digit;
    setState(() {
      _pinInput = updated;
      _errorMessage = null;
    });
    if (updated.length == 6) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleVerify(updated),
      );
    }
  }

  void _onBackspace() {
    if (_pinInput.isEmpty || _isSubmitting) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  Future<void> _handleVerify(String enteredPin) async {
    setState(() => _isSubmitting = true);
    try {
      final accessToken = await TokenStorage.getAccessToken();
      // CHANGED: verifyCurrentPin now returns email, not phone number.
      final email = await AuthApi.verifyCurrentPin(
        enteredPin,
        accessToken: accessToken!,
      );

      // Reuse the EXACT existing forgot-pin OTP request — from here on,
      // this is 100% your already-working flow.
      await AuthApi.requestOtp(email: email, purpose: 'pin_reset');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OtpVerificationScreen(email: email, purpose: 'pin_reset'),
        ),
      );
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
    return Scaffold(
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
          'Change login PIN',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Enter your current PIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'For your security, confirm your current login PIN. We\'ll then send a code to verify it\'s you before setting a new one.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              _buildPinDots(),
              const Spacer(),
              if (_isSubmitting)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                )
              else
                _buildKeypad(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
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

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < _pinInput.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
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
