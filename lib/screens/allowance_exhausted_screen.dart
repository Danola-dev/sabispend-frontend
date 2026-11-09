import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/wallet_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/transactions_api.dart';
import 'package:first_app/idempotency_key.dart';
import 'package:first_app/money_format.dart';

/// Shown when a user tries to spend more than their spendable balance
/// before the next scheduled payout. Offers Early Unlock — pull from
/// locked balance now. Emergency Fund does NOT exist anywhere in this
/// screen — removed entirely, no backend concept of a separate reserve.
class AllowanceExhaustedScreen extends StatefulWidget {
  final double currentBalance;
  final double? attemptedAmount;

  const AllowanceExhaustedScreen({
    super.key,
    required this.currentBalance,
    this.attemptedAmount,
  });

  @override
  State<AllowanceExhaustedScreen> createState() =>
      _AllowanceExhaustedScreenState();
}

class _AllowanceExhaustedScreenState extends State<AllowanceExhaustedScreen> {
  double _lockedBalance = 0;
  double _amountPerPayout = 0;
  DateTime? _nextPayoutDate;
  bool _isLoading = true;

  double? _selectedUnlockAmount;
  bool _isConfirming = false;
  String? _errorMessage;

  static const List<double> _quickUnlockAmounts = [5000, 10000];

  bool get _isFullyExhausted => widget.currentBalance <= 0;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    try {
      final wallet = await WalletApi.getWallet();
      if (mounted) {
        setState(() {
          _lockedBalance = wallet.lockedBalance;
          _amountPerPayout = wallet.currentPlan?.amountPerPayout ?? 0;
          _nextPayoutDate = wallet.currentPlan?.nextEditableDate;
          _isLoading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNaira(double amount) => formatNaira(amount);

  String _formatNextPayoutLabel() {
    if (_nextPayoutDate == null) return 'your next payout';
    final daysLeft = _nextPayoutDate!.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'today';
    if (daysLeft == 1) return 'tomorrow';
    return 'in $daysLeft days';
  }

  /// Opens a compact bottom sheet where the user types the exact amount
  /// they want to unlock. Validates against the real locked balance
  /// before letting them confirm — never lets them submit something
  /// that's guaranteed to fail server-side.
  Future<void> _openCustomAmountSheet() async {
    final controller = TextEditingController(
      text:
          _selectedUnlockAmount != null &&
              !_quickUnlockAmounts.contains(_selectedUnlockAmount)
          ? _selectedUnlockAmount!.toStringAsFixed(0)
          : '',
    );
    String? sheetError;

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Enter amount to unlock',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Up to ${_formatNaira(_lockedBalance)} available',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sheetError != null) ...[
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Color(0xFFD64545),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFD64545),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '₦0',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
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
                        borderSide: const BorderSide(
                          color: AppColors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() => sheetError = null),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final entered = double.tryParse(controller.text.trim());
                      if (entered == null || entered <= 0) {
                        setSheetState(
                          () => sheetError = 'Enter a valid amount.',
                        );
                        return;
                      }
                      if (entered > _lockedBalance) {
                        setSheetState(
                          () => sheetError =
                              'That\'s more than your locked balance.',
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop(entered);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.tealDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Use this amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedUnlockAmount = result);
    }
  }

  Future<void> _handleConfirmUnlock() async {
    if (_selectedUnlockAmount == null) return;

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    try {
      await TransactionsApi.earlyUnlock(
        amount: _selectedUnlockAmount!,
        idempotencyKey: IdempotencyKey.generate(),
      );

      if (!mounted) return;
      // Pops with `true` so the screen that pushed this (Home/Schedule)
      // knows to refresh its own balance display.
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
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
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildIntro(),
                    const SizedBox(height: 20),
                    _buildLockedBalanceCard(),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'UNLOCK FROM LOCKED BALANCE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 31, 33, 35),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildUnlockOption(),
                    const SizedBox(height: 20),
                    if (_selectedUnlockAmount != null) _buildConsequenceNote(),
                    const SizedBox(height: 20),
                    _buildConfirmButton(),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_left,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Spendable balance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 26),
      ],
    );
  }

  Widget _buildIntro() {
    final String title;
    final String subtitle;

    if (widget.attemptedAmount == null) {
      title = 'Need a bit more to spend?';
      subtitle =
          'You currently have ${_formatNaira(widget.currentBalance)}. '
          'Unlock some of your locked balance now.';
    } else if (_isFullyExhausted) {
      title = 'Your spendable balance is used up';
      subtitle =
          'You\'ve spent all ${_formatNaira(_amountPerPayout)} for this cycle.\n'
          'Next payout: ${_formatNextPayoutLabel()}.';
    } else {
      final shortfall = widget.attemptedAmount! - widget.currentBalance;
      title = 'You\'re short by ${_formatNaira(shortfall)} for this service.';
      subtitle = 'Spendable balance: ${_formatNaira(widget.currentBalance)}';
    }

    return Column(
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.tealTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.teal,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Color.fromARGB(255, 8, 9, 9),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Locked balance available',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 61, 65, 69),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatNaira(_lockedBalance),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Icon(Icons.lock_outline, color: AppColors.teal, size: 22),
        ],
      ),
    );
  }

  Widget _buildUnlockOption() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt, size: 21, color: AppColors.teal),
              SizedBox(width: 6),
              Text(
                'Unlock from locked balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Get money now, straight from your locked balance.',
            style: TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 25, 27, 28),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ..._quickUnlockAmounts.map(
                (amount) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildAmountChip(
                      label: _formatNaira(amount),
                      selected: _selectedUnlockAmount == amount,
                      onTap: () =>
                          setState(() => _selectedUnlockAmount = amount),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildAmountChip(
                  label:
                      (_selectedUnlockAmount != null &&
                          !_quickUnlockAmounts.contains(_selectedUnlockAmount))
                      ? _formatNaira(_selectedUnlockAmount!)
                      : 'Custom',
                  selected:
                      _selectedUnlockAmount != null &&
                      !_quickUnlockAmounts.contains(_selectedUnlockAmount),
                  outlined: true,
                  onTap: _openCustomAmountSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.teal
                : AppColors.teal.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.teal,
          ),
        ),
      ),
    );
  }

  Widget _buildConsequenceNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 21,
            color: Color.fromARGB(255, 28, 29, 31),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Unlocking ${_formatNaira(_selectedUnlockAmount ?? 0)} now comes straight out of your locked '
              'balance (${_formatNaira(_lockedBalance)} currently available). Your next payout is unaffected.',
              style: const TextStyle(
                fontSize: 14,
                color: Color.fromARGB(255, 82, 85, 91),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final enabled = _selectedUnlockAmount != null && !_isConfirming;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? _handleConfirmUnlock : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealDark : AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isConfirming
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Confirm unlock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}
