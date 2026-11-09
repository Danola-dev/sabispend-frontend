import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import '../schedule_models.dart';
import '../wallet_api.dart';
import '../api_client.dart';
import '../transactions_api.dart';
import '../idempotency_key.dart';
import 'allowance_exhausted_screen.dart';
import 'package:first_app/money_format.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  double _lockedBalance = 0;
  double _spendableBalance = 0;

  PayoutPlanData? _currentPlanData;
  PayoutReadiness? _readiness;
  List<PayoutPlanData> _history = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Only true once the user taps "Edit" on the ready prompt — reveals
  // the frequency/amount editor. Continue never needs this at all.
  bool _isEditingNewPlan = false;

  PayoutFrequency _draftFrequency = PayoutFrequency.weekly;
  double _draftAmount = 0;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  PayoutFrequency _frequencyFromString(String value) {
    return PayoutFrequency.values.firstWhere(
      (f) => f.name == value,
      orElse: () => PayoutFrequency.weekly,
    );
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await WalletApi.getWallet();
      final history = await WalletApi.getPayoutPlanHistory();
      final readiness = wallet.currentPlan != null
          ? await TransactionsApi.getPayoutReadiness()
          : null;

      if (!mounted) return;
      setState(() {
        _lockedBalance = wallet.lockedBalance;
        _spendableBalance = wallet.spendableBalance;
        _currentPlanData = wallet.currentPlan;
        _history = history;
        _readiness = readiness;

        if (wallet.currentPlan != null) {
          _draftFrequency = _frequencyFromString(wallet.currentPlan!.frequency);
          _draftAmount = wallet.currentPlan!.amountPerPayout;
        }
        _amountController.text = _draftAmount == 0
            ? ''
            : _draftAmount.toStringAsFixed(0);

        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  bool get _isReady => _readiness?.ready ?? false;
  bool get _hasPlan => _currentPlanData != null;

  String _formatNaira(double amount) => formatNaira(amount);

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _setDraftAmount(double value) {
    final clamped = value < 0 ? 0.0 : value;
    setState(() {
      _draftAmount = clamped;
      _amountController.text = clamped == 0 ? '' : clamped.toStringAsFixed(0);
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
    });
  }

  void _startEditingNewPlan() {
    setState(() {
      _isEditingNewPlan = true;
      // Pre-fill with the CURRENT plan's terms — editing starts from
      // what they already have, not blank.
      if (_currentPlanData != null) {
        _draftFrequency = _frequencyFromString(_currentPlanData!.frequency);
        _draftAmount = _currentPlanData!.amountPerPayout;
        _amountController.text = _draftAmount.toStringAsFixed(0);
      }
    });
  }

  void _cancelEditingNewPlan() {
    setState(() => _isEditingNewPlan = false);
  }

  /// Used for BOTH "Continue with current plan" and "Confirm new plan" —
  /// the backend call is identical either way, just with different
  /// frequency/amount values.
  Future<void> _confirmOrEditPayout({
    required String frequency,
    required double amountPerPayout,
  }) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await TransactionsApi.confirmOrEditPayout(
        frequency: frequency,
        amountPerPayout: amountPerPayout,
        idempotencyKey: IdempotencyKey.generate(),
      );

      if (!mounted) return;
      setState(() => _isEditingNewPlan = false);
      await _fetchAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout released and plan updated'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Sets a user's very first plan. This now goes through the SAME
  /// backend call as Continue/Edit — transactions.confirmOrEditPayout —
  /// since a first plan also releases its amount to spendable
  /// immediately, just like a renewal does. wallet's old setPayoutPlan
  /// endpoint is retired.
  Future<void> _setFirstPlan() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await TransactionsApi.confirmOrEditPayout(
        frequency: _draftFrequency.name,
        amountPerPayout: _draftAmount,
        idempotencyKey: IdempotencyKey.generate(),
      );

      if (!mounted) return;
      await _fetchAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payout plan set — amount released to your spendable balance',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payout plan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              _buildCurrentPlanCard(),
              const SizedBox(height: 16),

              if (!_hasPlan) ...[
                // No plan at all yet — first-time setup form.
                _buildSectionLabel('Frequency'),
                const SizedBox(height: 12),
                _buildFrequencyPicker(),
                const SizedBox(height: 24),
                _buildSectionLabel('Amount per payout'),
                const SizedBox(height: 10),
                _buildAmountStepper(),
                const SizedBox(height: 22),
                _buildFirstPlanButton(),
              ] else if (_isReady && !_isEditingNewPlan) ...[
                // Payout ready — the actual prompt you asked for.
                _buildPayoutReadyPrompt(),
              ] else if (_isReady && _isEditingNewPlan) ...[
                // Mid-edit: show the editor, pre-filled with current terms.
                _buildSectionLabel('Frequency'),
                const SizedBox(height: 12),
                _buildFrequencyPicker(),
                const SizedBox(height: 24),
                _buildSectionLabel('Amount per payout'),
                const SizedBox(height: 10),
                _buildAmountStepper(),
                const SizedBox(height: 22),
                _buildProjectionBanner(),
                const SizedBox(height: 16),
                _buildEditActionButtons(),
              ] else ...[
                // Locked — plain read-only preview, nothing to do here.
                _buildLockedNotice(),
                const SizedBox(height: 20),
                _buildSectionLabel('Frequency'),
                const SizedBox(height: 12),
                _buildReadOnlyFrequencyPreview(),
                const SizedBox(height: 24),
                _buildSectionLabel('Amount per payout'),
                const SizedBox(height: 10),
                _buildReadOnlyAmountPreview(),
              ],

              const SizedBox(height: 12),
              _buildUnlockAccessButton(),
              const SizedBox(height: 28),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),
              _buildPlanHistory(),
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

  Widget _buildCurrentPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isReady ? 'Payout ready' : 'Current plan',
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromARGB(247, 253, 249, 249),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hasPlan
                ? '${_formatNaira(_currentPlanData!.amountPerPayout)} / ${_frequencyFromString(_currentPlanData!.frequency).label.toLowerCase()}'
                : 'No plan set yet',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (_hasPlan)
            Row(
              children: [
                Icon(
                  _isReady
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _isReady
                      ? 'Ready — choose to continue or edit below'
                      : 'Editable from ${_formatDate(_currentPlanData!.nextEditableDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            const Text(
              'Set your first plan below',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  /// THE new prompt — Continue with the same terms, or Edit to set new
  /// ones. This is the core of what was asked for.
  Widget _buildPayoutReadyPrompt() {
    final amount = _currentPlanData!.amountPerPayout;
    final freqLabel = _frequencyFromString(
      _currentPlanData!.frequency,
    ).label.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.celebration_outlined, size: 20, color: AppColors.teal),
              SizedBox(width: 8),
              Text(
                'Your payout is ready',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Continue with your current plan (${_formatNaira(amount)} / $freqLabel), or set new terms for this cycle. '
            'Either way, the amount releases to your spendable balance right away.',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_isSubmitting)
            const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          else
            Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _confirmOrEditPayout(
                    frequency: _currentPlanData!.frequency,
                    amountPerPayout: _currentPlanData!.amountPerPayout,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Continue with current plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _startEditingNewPlan,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.teal),
                    ),
                    child: const Text(
                      'Edit plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEditActionButtons() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSubmitting ? null : _cancelEditingNewPlan,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSubmitting || _draftAmount <= 0
                ? null
                : () => _confirmOrEditPayout(
                    frequency: _draftFrequency.name,
                    amountPerPayout: _draftAmount,
                  ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (_isSubmitting || _draftAmount <= 0)
                    ? AppColors.border
                    : AppColors.tealDark,
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
                      'Confirm new plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstPlanButton() {
    final enabled = _draftAmount > 0 && !_isSubmitting;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? _setFirstPlan : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealDark : AppColors.border,
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
            : Text(
                'Set plan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }

  Widget _buildLockedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 22,
            color: Color.fromARGB(255, 18, 18, 19),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Your plan is locked until your next payout on ${_formatDate(_currentPlanData!.nextEditableDate)}. '
              'Running low before then? You can unlock a bit from your locked balance instead.',
              style: const TextStyle(
                fontSize: 15,
                color: Color.fromARGB(255, 15, 16, 17),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color.fromARGB(255, 0, 0, 0),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildReadOnlyFrequencyPreview() {
    return Opacity(
      opacity: 0.5,
      child: Row(
        children: PayoutFrequency.values.map((freq) {
          final selected = freq == _draftFrequency;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.tealTint : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.teal : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  freq.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.teal : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadOnlyAmountPreview() {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _formatNaira(_draftAmount),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyPicker() {
    return Row(
      children: PayoutFrequency.values.map((freq) {
        final selected = freq == _draftFrequency;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _draftFrequency = freq),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.tealTint : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.teal : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  freq.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.teal : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountStepper() {
    final step = _draftFrequency == PayoutFrequency.daily
        ? 500.0
        : _draftFrequency == PayoutFrequency.weekly
        ? 1000.0
        : 5000.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  '₦',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                    onChanged: (value) => setState(
                      () => _draftAmount = double.tryParse(value) ?? 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _stepperButton(
                icon: Icons.remove,
                onTap: () => _setDraftAmount(_draftAmount - step),
              ),
              const SizedBox(width: 8),
              _stepperButton(
                icon: Icons.add,
                onTap: () => _setDraftAmount(_draftAmount + step),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.tealTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: AppColors.teal),
      ),
    );
  }

  Widget _buildProjectionBanner() {
    final weeksRemaining = _draftAmount > 0
        ? ((_lockedBalance / _draftAmount) * _draftFrequency.days / 7).floor()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 19, color: AppColors.teal),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Based on your locked balance of ${_formatNaira(_lockedBalance)}, this plan will last approximately $weeksRemaining more weeks.',
              style: const TextStyle(
                fontSize: 14.7,
                color: Colors.black,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockAccessButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                AllowanceExhaustedScreen(currentBalance: _spendableBalance),
          ),
        );
        if (result == true) _fetchAll();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt, size: 19, color: AppColors.teal),
            SizedBox(width: 2),
            Text(
              'Unlock from locked balance',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Plan history'),
        const SizedBox(height: 10),
        if (_currentPlanData != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_frequencyFromString(_currentPlanData!.frequency).label} · ${_formatNaira(_currentPlanData!.amountPerPayout)}',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 0, 0, 1),
                      ),
                    ),
                    Text(
                      'Since ${_formatDate(_currentPlanData!.startDate)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 84, 88, 95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.check_circle, size: 15, color: AppColors.teal),
              ],
            ),
          ),
        ..._history.map((entry) {
          final hasEndDate = entry.endDate != null;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_frequencyFromString(entry.frequency).label} · ${_formatNaira(entry.amountPerPayout)}',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: Color.fromARGB(255, 0, 0, 1),
                  ),
                ),
                Text(
                  '${_formatDate(entry.startDate)}${hasEndDate ? ' – ${_formatDate(entry.endDate!)}' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(255, 84, 88, 95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
