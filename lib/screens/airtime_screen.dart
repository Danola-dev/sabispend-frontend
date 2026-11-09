import 'package:first_app/biller_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/wallet_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/bills_api.dart';
import 'package:first_app/idempotency_key.dart';
import 'transaction_pin_sheet.dart';
import 'package:first_app/money_format.dart';

const List<BillerOption> kAirtimeNetworks = [
  BillerOption(serviceId: 'mtn', name: 'MTN', color: Color(0xFFFFCC00)),
  BillerOption(serviceId: 'airtel', name: 'Airtel', color: Color(0xFFED1C24)),
  BillerOption(serviceId: 'glo', name: 'Glo', color: Color(0xFF00A651)),
  BillerOption(
    serviceId: 'etisalat',
    name: '9mobile',
    color: Color(0xFF00805E),
  ),
];

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  double _spendableBalance = 0;
  bool _isLoadingBalance = true;

  BillerOption? _selectedNetwork;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  static const List<double> _quickAmounts = [100, 200, 500, 1000, 2000];

  static const double _minAirtime = 50;

  bool _isSubmitting = false;
  String? _errorMessage;
  BillPaymentResult? _result;

  // One key identifies one purchase. It is created on the first attempt and
  // REUSED if we can't tell whether that attempt went through (network drop,
  // server error) — so tapping Proceed again can never buy the airtime
  // twice. It is cleared as soon as we get a definite answer, or whenever
  // the network / phone / amount changes, so a genuinely new purchase always
  // gets a fresh key.
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    try {
      final wallet = await WalletApi.getWallet();
      if (mounted) {
        setState(() {
          _spendableBalance = wallet.spendableBalance;
          _isLoadingBalance = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  /// Call inside setState whenever anything that defines the purchase
  /// changes: the old key and any old error no longer apply.
  void _onPurchaseInputsChanged() {
    _idempotencyKey = null;
    _errorMessage = null;
  }

  String _formatNaira(double amount) => formatNaira(amount);

  double? get _parsedAmount =>
      double.tryParse(_amountController.text.replaceAll(',', ''));

  // Nigerian mobile numbers are 11 digits and start with 0.
  bool get _isPhoneValid =>
      _phoneController.text.length == 11 &&
      _phoneController.text.startsWith('0');

  bool get _canProceed =>
      _selectedNetwork != null &&
      _isPhoneValid &&
      _parsedAmount != null &&
      _parsedAmount! >= _minAirtime &&
      !_isSubmitting;

  Future<void> _handleProceed() async {
    final amount = _parsedAmount!;
    if (amount > _spendableBalance) {
      setState(() => _errorMessage = 'Insufficient balance for this amount.');
      return;
    }

    final pin = await showTransactionPinSheet(context);
    if (pin == null || !mounted) return;

    _idempotencyKey ??= IdempotencyKey.generate();
    final idempotencyKey = _idempotencyKey!;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await BillsApi.payBill(
        billType: 'airtime',
        serviceId: _selectedNetwork!.serviceId,
        billerName: _selectedNetwork!.name,
        amount: amount,
        phone: _phoneController.text,
        transactionPin: pin,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      // We got a definite answer, so this attempt is finished. A later
      // purchase must use a new key.
      _idempotencyKey = null;

      if (result.isSuccessful || result.isPending) {
        setState(() => _result = result);
      } else {
        setState(
          () => _errorMessage =
              result.failureReason ?? 'Payment failed. Please try again.',
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode >= 500) {
        // The server hit a problem, so we can't be sure whether the
        // purchase happened. Keep the key: trying again is safe.
        setState(
          () => _errorMessage =
              'Couldn\'t confirm this purchase. Check your transaction history before trying again.',
        );
      } else {
        // Rejected outright (wrong PIN, validation, etc.): nothing was
        // bought, so the next attempt should start fresh.
        _idempotencyKey = null;
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      // Network drop / timeout: outcome unknown, key is kept.
      setState(
        () => _errorMessage =
            'Couldn\'t confirm this purchase. Check your connection and your transaction history before trying again.',
      );
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
          'Airtime',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _result != null ? _buildSuccessState() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    // While a purchase is in flight nothing on the form can be changed, so
    // the number/amount being paid can't change under it.
    return IgnorePointer(
      ignoring: _isSubmitting,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvailableBalance(),
            const SizedBox(height: 20),
            const Text(
              'Select network',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            BillerGrid(
              options: kAirtimeNetworks,
              selected: _selectedNetwork,
              onSelect: (n) => setState(() {
                _selectedNetwork = n;
                _onPurchaseInputsChanged();
              }),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              _buildErrorBanner(_errorMessage!),
              const SizedBox(height: 16),
            ],
            _buildFieldLabel('Phone number'),
            const SizedBox(height: 6),
            _buildPhoneField(),
            const SizedBox(height: 20),
            _buildFieldLabel('Amount'),
            const SizedBox(height: 10),
            _buildQuickAmountChips(),
            const SizedBox(height: 10),
            _buildAmountField(),
            const SizedBox(height: 32),
            _buildProceedButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableBalance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Available balance',
            style: TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 39, 41, 44),
            ),
          ),
          _isLoadingBalance
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                )
              : Text(
                  _formatNaira(_spendableBalance),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
      decoration: _fieldDecoration(hint: '0803XXXXXXX'),
      onChanged: (_) => setState(_onPurchaseInputsChanged),
    );
  }

  Widget _buildQuickAmountChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _quickAmounts.map((amount) {
        final isSelected = _parsedAmount == amount;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() {
            _amountController.text = amount.toStringAsFixed(0);
            _onPurchaseInputsChanged();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.teal : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.teal : AppColors.border,
              ),
            ),
            child: Text(
              '₦${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountField() {
    final amount = _parsedAmount;
    final belowMinimum = amount != null && amount > 0 && amount < _minAirtime;

    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: _fieldDecoration(
        hint: 'Enter custom amount',
      ).copyWith(errorText: belowMinimum ? 'Minimum airtime is ₦50' : null),
      onChanged: (_) => setState(_onPurchaseInputsChanged),
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

  Widget _buildProceedButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _canProceed ? _handleProceed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _canProceed ? AppColors.tealDark : AppColors.border,
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
                'Proceed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _canProceed ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessState() {
    final isPending = _result!.isPending;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFFFF6E0) : AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending ? Icons.hourglass_top_rounded : Icons.check_circle,
                color: isPending ? const Color(0xFFB8860B) : AppColors.teal,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPending ? 'Processing' : 'Airtime purchase successful',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your ${_formatNaira(_result!.amount)} airtime purchase is being processed — check your history shortly.'
                  : '${_formatNaira(_result!.amount)} airtime was sent to ${_phoneController.text}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Done',
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
      ),
    );
  }
}
