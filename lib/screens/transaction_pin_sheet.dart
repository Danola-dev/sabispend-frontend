import 'package:first_app/screens/auth/forgot_transaction_pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';

/// Call this before any money-moving confirmation (e.g. the Transfer
/// button on the Send to Bank summary screen). Returns the entered
/// 4-digit PIN, or null if the user dismissed it without entering one.
///
/// Usage:
///   final pin = await showTransactionPinSheet(context);
///   if (pin == null) return; // user cancelled
///   // proceed with pin included in the API call
Future<String?> showTransactionPinSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TransactionPinSheet(),
  );
}

class _TransactionPinSheet extends StatefulWidget {
  const _TransactionPinSheet();

  @override
  State<_TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<_TransactionPinSheet> {
  String _pin = '';

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      // Small delay so the last dot fills in visibly before the sheet
      // closes — otherwise the 4th digit feels like it never registered.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).pop(_pin);
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handleForgotPin() async {
    Navigator.of(context).pop(null); // close the sheet first
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotTransactionPinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppColors.teal,
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Enter your transaction PIN',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'To confirm this transfer',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            _buildPinDots(),
            const SizedBox(height: 22),
            _buildKeypad(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _handleForgotPin,
              child: const Text(
                'Forgot PIN?',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < _pin.length;
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
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        if (key == 'back') {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _onBackspace,
            child: const Center(
              child: Icon(
                Icons.backspace_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onDigitPressed(key),
          child: Center(
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 22,
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
