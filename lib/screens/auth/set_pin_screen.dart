import 'package:first_app/screens/auth/set_transaction_pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/token_storage.dart';

class SetPinScreen extends StatefulWidget {
  final String pinSetupToken;
  final String email;
  final String phoneNumber;
  final String fullName;

  const SetPinScreen({
    super.key,
    required this.pinSetupToken,
    required this.email,
    required this.phoneNumber,
    required this.fullName,
  });

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

enum _Stage { enter, confirm }

class _SetPinScreenState extends State<SetPinScreen> {
  _Stage _stage = _Stage.enter;
  String _firstPin = '';
  String _currentInput = '';

  bool _isSubmitting = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_currentInput.length >= 6 || _isSubmitting) return;
    setState(() {
      _currentInput += digit;
      _errorMessage = null;
    });

    if (_currentInput.length == 6) _handleStageComplete();
  }

  void _onBackspace() {
    if (_currentInput.isEmpty) return;
    setState(
      () =>
          _currentInput = _currentInput.substring(0, _currentInput.length - 1),
    );
  }

  Future<void> _handleStageComplete() async {
    if (_stage == _Stage.enter) {
      setState(() {
        _firstPin = _currentInput;
        _currentInput = '';
        _stage = _Stage.confirm;
      });
      return;
    }

    if (_currentInput != _firstPin) {
      setState(() {
        _errorMessage = 'PINs don\'t match. Try again.';
        _currentInput = '';
        _firstPin = '';
        _stage = _Stage.enter;
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final (access, refresh) = await AuthApi.setPin(
        pinSetupToken: widget.pinSetupToken,
        pin: _firstPin,
      );
      await TokenStorage.saveTokens(access: access, refresh: refresh);

      // CHANGED: caches email AND phone — both are real, needed pieces
      // of local user info now (email for identity, phone for features
      // like bill payments).
      await LocalUserCache.saveUser(
        email: widget.email,
        phone: widget.phoneNumber,
        name: widget.fullName,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetTransactionPinScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _currentInput = '';
        _firstPin = '';
        _stage = _Stage.enter;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
        _currentInput = '';
        _firstPin = '';
        _stage = _Stage.enter;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              const SizedBox(height: 20),
              Text(
                _stage == _Stage.enter ? 'Create your PIN' : 'Confirm your PIN',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stage == _Stage.enter
                    ? 'You\'ll use this to log in to your account'
                    : 'Enter the same PIN again.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 52, 55, 59),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 20),
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
        final filled = index < _currentInput.length;
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
