import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transaction_pin_api.dart';
import 'package:first_app/api_client.dart';
import '../main_tab_screen.dart';

/// Shown once, right after login PIN setup during signup. Sets up a
/// SEPARATE 4-digit transaction PIN required before any transfer —
/// matching the pattern most Nigerian banking apps use. After this,
/// navigation proceeds to MainTabScreen exactly as before.
class SetTransactionPinScreen extends StatefulWidget {
  const SetTransactionPinScreen({super.key});

  @override
  State<SetTransactionPinScreen> createState() =>
      _SetTransactionPinScreenState();
}

enum _Stage { intro, enter, confirm }

class _SetTransactionPinScreenState extends State<SetTransactionPinScreen> {
  _Stage _stage = _Stage.intro;
  String _firstPin = '';
  String _currentInput = '';

  bool _isSubmitting = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_isSubmitting) return;
    final updated = _currentInput + digit;
    if (updated.length > 4) return;

    setState(() {
      _currentInput = updated;
      _errorMessage = null;
    });

    if (updated.length == 4) {
      // Defer to the next frame — avoids any ambiguity about state
      // having fully settled before we act on it.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleStageComplete(updated),
      );
    }
  }

  void _onBackspace() {
    if (_currentInput.isEmpty || _isSubmitting) return;
    setState(
      () =>
          _currentInput = _currentInput.substring(0, _currentInput.length - 1),
    );
  }

  Future<void> _handleStageComplete(String enteredPin) async {
    if (_stage == _Stage.enter) {
      setState(() {
        _firstPin = enteredPin;
        _currentInput = '';
        _stage = _Stage.confirm;
        _errorMessage = null;
      });
      return;
    }

    // Compare against the EXACT value passed in, not whatever _currentInput
    // might be by the time this runs.
    if (enteredPin != _firstPin) {
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
      await SecurityApi.setTransactionPin(enteredPin);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainTabScreen(isNewSignup: true),
        ),
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

  void _startPinEntry() => setState(() => _stage = _Stage.enter);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _stage == _Stage.intro ? _buildIntro() : _buildPinEntry(),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.tealTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: AppColors.teal,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'One more thing — set a payment PIN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Persuasive, reassuring copy explaining WHY — matches the
        // framing used for the BVN screen.
        const Text(
          'This is a separate 4-digit PIN, just for confirming transfers and payments. '
          'Even if someone unlocks your phone, they still can\'t move your money without '
          'this — think of it as a second lock, specifically for your funds.',
          style: TextStyle(
            fontSize: 16,
            color: Color.fromARGB(255, 63, 67, 71),
            height: 1.5,
          ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _startPinEntry,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Set payment PIN',
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

  Widget _buildPinEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _stage == _Stage.enter
              ? 'Create your payment PIN'
              : 'Confirm your payment PIN',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stage == _Stage.enter
              ? 'Choose a 4-digit PIN.'
              : 'Enter the same PIN again.',
          style: const TextStyle(
            fontSize: 16.5,
            color: Color.fromARGB(255, 74, 79, 84),
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
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else
          _buildKeypad(),
        const SizedBox(height: 12),
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

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < _currentInput.length;
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
