import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'set_pin_screen.dart';
import 'reset_pin_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String purpose;
  final String? fullName;
  // NEW: only needed/available when purpose == 'signup' — forwarded to
  // SetPinScreen so it can cache phone alongside email once PIN is set.
  final String? phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.fullName,
    this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorMessage = null);

    if (_enteredCode.length == 6) _handleVerify();
  }

  Future<void> _handleVerify() async {
    if (_enteredCode.length != 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final scopedToken = await AuthApi.verifyOtp(
        email: widget.email,
        purpose: widget.purpose,
        code: _enteredCode,
      );

      if (!mounted) return;

      if (widget.purpose == 'signup' && scopedToken != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SetPinScreen(
              pinSetupToken: scopedToken,
              email: widget.email,
              phoneNumber: widget.phoneNumber ?? '',
              fullName: widget.fullName ?? '',
            ),
          ),
        );
      } else if (widget.purpose == 'pin_reset' && scopedToken != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPinScreen(pinResetToken: scopedToken),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
      _clearInputs();
    } catch (e) {
      setState(
        () => _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.',
      );
      _clearInputs();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await AuthApi.requestOtp(email: widget.email, purpose: widget.purpose);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color.fromARGB(255, 92, 179, 250),
            content: Text(
              'Code resent',
              style: TextStyle(
                fontSize: 19,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${widget.email}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 20),
              ],
              _buildOtpBoxes(),
              const SizedBox(height: 28),
              _buildResendRow(),
              const Spacer(),
              _buildVerifyButton(),
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

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 46,
          height: 56,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.card,
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
            onChanged: (value) => _onDigitChanged(index, value),
          ),
        );
      }),
    );
  }

  Widget _buildResendRow() {
    return Row(
      children: [
        const Text(
          'Didn\'t get a code? ',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        InkWell(
          onTap: _resendCooldown == 0 ? _handleResend : null,
          child: Text(
            _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _resendCooldown == 0
                  ? AppColors.teal
                  : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyButton() {
    final enabled = _enteredCode.length == 6 && !_isVerifying;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? _handleVerify : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealDark : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _isVerifying
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              )
            : Text(
                'Verify',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}
