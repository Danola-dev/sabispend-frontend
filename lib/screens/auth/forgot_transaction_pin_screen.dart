import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transaction_pin_api.dart';
import 'package:first_app/api_client.dart';

enum _Stage { confirmEmail, otp, newPin, newPinConfirm }

class ForgotTransactionPinScreen extends StatefulWidget {
  const ForgotTransactionPinScreen({super.key});

  @override
  State<ForgotTransactionPinScreen> createState() =>
      _ForgotTransactionPinScreenState();
}

class _ForgotTransactionPinScreenState
    extends State<ForgotTransactionPinScreen> {
  _Stage _stage = _Stage.confirmEmail;
  String? _email;

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _newPinFirst = '';
  String _currentPinInput = '';

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final email = await SecurityApi.requestForgotPinOtp();
      if (!mounted) return;
      setState(() {
        _email = email;
        _stage = _Stage.otp;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
    setState(() => _errorMessage = null);
    if (_enteredOtp.length == 6) {
      setState(() => _stage = _Stage.newPin);
    }
  }

  void _onNewPinDigitPressed(String digit) {
    if (_currentPinInput.length >= 4 || _isSubmitting) return;
    setState(() {
      _currentPinInput += digit;
      _errorMessage = null;
    });
    if (_currentPinInput.length == 4) _handleNewPinStageComplete();
  }

  void _onNewPinBackspace() {
    if (_currentPinInput.isEmpty) return;
    setState(
      () => _currentPinInput = _currentPinInput.substring(
        0,
        _currentPinInput.length - 1,
      ),
    );
  }

  Future<void> _handleNewPinStageComplete() async {
    if (_stage == _Stage.newPin) {
      setState(() {
        _newPinFirst = _currentPinInput;
        _currentPinInput = '';
        _stage = _Stage.newPinConfirm;
      });
      return;
    }

    if (_currentPinInput != _newPinFirst) {
      setState(() {
        _errorMessage = 'PINs don\'t match. Try again.';
        _currentPinInput = '';
        _newPinFirst = '';
        _stage = _Stage.newPin;
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SecurityApi.verifyAndResetPin(
        code: _enteredOtp,
        newPin: _currentPinInput,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment PIN reset successfully')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _currentPinInput = '';
        _newPinFirst = '';
        _stage = _Stage.newPin;
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
          'Reset Payment PIN',
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
          child: switch (_stage) {
            _Stage.confirmEmail => _buildConfirmEmailStage(),
            _Stage.otp => _buildOtpStage(),
            _Stage.newPin || _Stage.newPinConfirm => _buildNewPinStage(),
          },
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

  Widget _buildConfirmEmailStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Forgot your Payment PIN?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // CHANGED: reflects email delivery now, not phone.
        const Text(
          'We\'ll send a code to your registered email to confirm it\'s you.',
          style: TextStyle(
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
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSubmitting ? null : _handleSendCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOtpStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Enter the code',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sent to ${_email ?? "your email"}',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 46,
              height: 56,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
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
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (value) => _onOtpDigitChanged(index, value),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNewPinStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _stage == _Stage.newPin
              ? 'Set a new Payment PIN'
              : 'Confirm your new PIN',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stage == _Stage.newPin
              ? 'Choose a 4-digit PIN.'
              : 'Enter the same PIN again.',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _currentPinInput.length;
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
        ),
        const Spacer(),
        if (_isSubmitting)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else
          _buildKeypad(),
        const SizedBox(height: 12),
      ],
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
            onTap: _onNewPinBackspace,
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
          onTap: () => _onNewPinDigitPressed(key),
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
