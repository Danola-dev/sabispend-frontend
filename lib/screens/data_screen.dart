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

const List<BillerOption> kDataNetworks = [
  BillerOption(serviceId: 'mtn-data', name: 'MTN', color: Color(0xFFFFCC00)),
  BillerOption(
    serviceId: 'airtel-data',
    name: 'Airtel',
    color: Color(0xFFED1C24),
  ),
  BillerOption(serviceId: 'glo-data', name: 'Glo', color: Color(0xFF00A651)),
  BillerOption(
    serviceId: 'etisalat-data',
    name: '9mobile',
    color: Color(0xFF00805E),
  ),
];

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  double _spendableBalance = 0;
  bool _isLoadingBalance = true;

  BillerOption? _selectedNetwork;
  final TextEditingController _phoneController = TextEditingController();

  List<BillVariation> _plans = [];
  bool _isLoadingPlans = false;
  String? _plansError;
  BillVariation? _selectedPlan;

  final TextEditingController _planSearchController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  BillPaymentResult? _result;

  // One key identifies one purchase. It is created on the first attempt and
  // REUSED if we can't tell whether that attempt went through (network drop,
  // server error) — so tapping Proceed again can never buy the plan twice.
  // It is cleared as soon as we get a definite answer, or whenever the
  // network / phone / plan changes, so a genuinely new purchase always gets
  // a fresh key.
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _planSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _planSearchController.dispose();
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

  Future<void> _handleSelectNetwork(BillerOption network) async {
    setState(() {
      _selectedNetwork = network;
      _selectedPlan = null;
      _plans = [];
      _isLoadingPlans = true;
      _plansError = null;
      _planSearchController.clear();
      _onPurchaseInputsChanged();
    });

    try {
      final plans = await BillsApi.getVariations(network.serviceId);
      // The user may have switched network while this was loading. Without
      // this check a slow reply for the OLD network could replace the new
      // network's plans, and a plan from one network could be bought on
      // another.
      if (!mounted || _selectedNetwork != network) return;
      setState(() {
        _plans = plans;
        _isLoadingPlans = false;
      });
    } on ApiException catch (e) {
      if (!mounted || _selectedNetwork != network) return;
      setState(() {
        _plansError = e.message;
        _isLoadingPlans = false;
      });
    } catch (_) {
      // Network failure etc. — never leave the spinner running forever.
      if (!mounted || _selectedNetwork != network) return;
      setState(() {
        _plansError =
            'Couldn\'t load plans. Check your connection and try again.';
        _isLoadingPlans = false;
      });
    }
  }

  void _handleChangePlan() {
    setState(() {
      _selectedPlan = null;
      _planSearchController.clear();
      _onPurchaseInputsChanged();
    });
  }

  List<BillVariation> get _filteredPlans {
    final query = _planSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _plans;
    return _plans.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  String _formatNaira(double amount) => formatNaira(amount);

  // Nigerian mobile numbers are 11 digits and start with 0.
  bool get _isPhoneValid =>
      _phoneController.text.length == 11 &&
      _phoneController.text.startsWith('0');

  bool get _canProceed =>
      _selectedNetwork != null &&
      _isPhoneValid &&
      _selectedPlan != null &&
      !_isSubmitting;

  Future<void> _handleProceed() async {
    final amount = _selectedPlan!.amount;
    if (amount > _spendableBalance) {
      setState(() => _errorMessage = 'Insufficient balance for this plan.');
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
        billType: 'data',
        serviceId: _selectedNetwork!.serviceId,
        billerName: _selectedNetwork!.name,
        amount: amount,
        phone: _phoneController.text,
        variationCode: _selectedPlan!.code,
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
          'Data',
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
    // the plan/phone being paid can't change under it.
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
              options: kDataNetworks,
              selected: _selectedNetwork,
              onSelect: (network) => _handleSelectNetwork(network),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              _buildErrorBanner(_errorMessage!),
              const SizedBox(height: 16),
            ],
            if (_selectedNetwork != null) ...[
              const Text(
                'Phone number',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              _buildPhoneField(),
              const SizedBox(height: 20),
              const Text(
                'Plan',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              // THE CHANGE: once a plan is picked, the search field and
              // full list collapse into this compact summary — nothing
              // else clutters the screen until "Change" is tapped.
              _selectedPlan != null
                  ? _buildSelectedPlanSummary()
                  : _buildPlanSearchAndList(),
            ],
            const SizedBox(height: 32),
            _buildProceedButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPlanSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPlan!.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatNaira(_selectedPlan!.amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _handleChangePlan,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Change',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSearchAndList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_plans.isNotEmpty) ...[
          _buildPlanSearchField(),
          const SizedBox(height: 10),
        ],
        _buildPlansList(),
      ],
    );
  }

  Widget _buildPlanSearchField() {
    return TextField(
      controller: _planSearchController,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search plans (e.g. 1GB, 30 days)',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search,
          size: 19,
          color: AppColors.textMuted,
        ),
        suffixIcon: _planSearchController.text.isNotEmpty
            ? InkWell(
                onTap: () => _planSearchController.clear(),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
      decoration: InputDecoration(
        hintText: '0803XXXXXXX',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
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
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
      ),
      onChanged: (_) => setState(_onPurchaseInputsChanged),
    );
  }

  Widget _buildPlansList() {
    if (_isLoadingPlans) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    if (_plansError != null) {
      return _buildErrorBanner(_plansError!);
    }
    if (_plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No plans available for this network.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final filtered = _filteredPlans;
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No plans match your search.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: filtered.map((plan) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selectedPlan = plan;
            _onPurchaseInputsChanged();
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _formatNaira(plan.amount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
              isPending ? 'Processing' : 'Data purchase successful',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your data purchase is being processed — check your history shortly.'
                  : '${_selectedPlan?.name ?? ''} was sent to ${_phoneController.text}.',
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
