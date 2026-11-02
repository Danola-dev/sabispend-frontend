import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/wallet_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/bills_api.dart';
import 'package:first_app/token_storage.dart';
import 'package:first_app/biller_grid.dart';
import 'bill_review_screen.dart';

const List<BillerOption> kElectricityDiscos = [
  BillerOption(
    serviceId: 'ikeja-electric',
    name: 'Ikeja Electric',
    color: Color(0xFF1976D2),
  ),
  BillerOption(
    serviceId: 'eko-electric',
    name: 'Eko Electric',
    color: Color(0xFF388E3C),
  ),
  BillerOption(
    serviceId: 'abuja-electric',
    name: 'Abuja Electric',
    color: Color(0xFFF57C00),
  ),
  BillerOption(
    serviceId: 'kano-electric',
    name: 'Kano Electric',
    color: Color(0xFF7B1FA2),
  ),
  BillerOption(
    serviceId: 'portharcourt-electric',
    name: 'PH Electric',
    color: Color(0xFFD32F2F),
  ),
  BillerOption(
    serviceId: 'jos-electric',
    name: 'Jos Electric',
    color: Color(0xFF00796B),
  ),
  BillerOption(
    serviceId: 'ibadan-electric',
    name: 'Ibadan Electric',
    color: Color(0xFF5D4037),
  ),
  BillerOption(
    serviceId: 'kaduna-electric',
    name: 'Kaduna Electric',
    color: Color(0xFF455A64),
  ),
];

const double kElectricityCommission = 100;

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  double _spendableBalance = 0;
  bool _isLoadingBalance = true;
  String _userPhone = '';

  BillerOption? _selectedDisco;
  String _meterType = 'prepaid'; // 'prepaid' | 'postpaid'
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  Timer? _debounce;

  bool _isVerifying = false;
  String? _verifiedCustomerName;
  String? _verifyError;

  bool _saveAsBeneficiary = false;

  BillPaymentResult? _result;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _loadUserPhone();
    _meterController.addListener(_onMeterChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _meterController.removeListener(_onMeterChanged);
    _meterController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    try {
      final wallet = await WalletApi.getWallet();
      if (mounted)
        setState(() {
          _spendableBalance = wallet.spendableBalance;
          _isLoadingBalance = false;
        });
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _loadUserPhone() async {
    final phone = await LocalUserCache.getCachedPhone();
    if (mounted) setState(() => _userPhone = phone ?? '');
  }

  void _resetVerification() {
    _debounce?.cancel();
    setState(() {
      _verifiedCustomerName = null;
      _verifyError = null;
      _isVerifying = false;
      _saveAsBeneficiary = false;
    });
  }

  // THE CHANGE: auto-verifies once typing pauses, and re-verifies
  // automatically if the meter type toggle changes too (a meter number
  // can be valid for one type and not the other).
  void _onMeterChanged() {
    _debounce?.cancel();
    if (_verifiedCustomerName != null || _verifyError != null) {
      setState(() {
        _verifiedCustomerName = null;
        _verifyError = null;
      });
    }
    final value = _meterController.text.trim();
    if (_selectedDisco == null || value.length < 5) return;

    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _handleVerify();
    });
  }

  Future<void> _handleVerify() async {
    if (_selectedDisco == null || _meterController.text.trim().isEmpty) return;

    setState(() {
      _isVerifying = true;
      _verifiedCustomerName = null;
      _verifyError = null;
    });

    try {
      final result = await BillsApi.verifyMerchant(
        serviceId: _selectedDisco!.serviceId,
        billersCode: _meterController.text.trim(),
        serviceType: _meterType,
      );
      if (!mounted) return;
      // THE BUG FIX: same as cable — only ever shows a name that was
      // genuinely returned, never a placeholder "Verified" fallback.
      setState(() {
        _isVerifying = false;
        _verifiedCustomerName = result.customerName;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verifyError = e.message;
      });
    }
  }

  Future<void> _openBeneficiaryPicker() async {
    final picked = await showModalBottomSheet<BillBeneficiary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BillBeneficiaryPickerSheetElectricity(),
    );
    if (picked == null) return;

    final matchingDisco = kElectricityDiscos.firstWhere(
      (d) => d.serviceId == picked.serviceId,
      orElse: () => kElectricityDiscos.first,
    );
    setState(() {
      _selectedDisco = matchingDisco;
      _meterController.text = picked.billersCode;
      _verifiedCustomerName = picked.customerName;
      _verifyError = null;
      _saveAsBeneficiary = false;
    });
  }

  String _formatNaira(double amount) {
    final wholeAmount = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholeAmount.length; i++) {
      if (i != 0 && (wholeAmount.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeAmount[i]);
    }
    return '₦$buffer';
  }

  double? get _parsedAmount =>
      double.tryParse(_amountController.text.replaceAll(',', ''));

  bool get _canProceed =>
      _selectedDisco != null &&
      _verifiedCustomerName != null &&
      _userPhone.isNotEmpty &&
      _parsedAmount != null &&
      _parsedAmount! > 0;

  Future<void> _handleProceed() async {
    final amount = _parsedAmount!;
    final total = amount + kElectricityCommission;
    if (total > _spendableBalance) {
      setState(
        () => _verifyError =
            'Insufficient balance for this amount plus commission.',
      );
      return;
    }

    if (_saveAsBeneficiary) {
      BillsApi.saveBeneficiary(
        billType: 'electricity',
        serviceId: _selectedDisco!.serviceId,
        billerName: _selectedDisco!.name,
        billersCode: _meterController.text.trim(),
        customerName: _verifiedCustomerName!,
      ).catchError((_) {});
    }

    final result = await Navigator.of(context).push<BillPaymentResult>(
      MaterialPageRoute(
        builder: (_) => BillReviewScreen(
          billType: 'electricity',
          serviceId: _selectedDisco!.serviceId,
          billerName: _selectedDisco!.name,
          phone: _userPhone,
          amount: amount,
          commission: kElectricityCommission,
          billersCode: _meterController.text.trim(),
          variationCode: _meterType,
          customerName: _verifiedCustomerName,
          productLabel:
              '${_meterType == 'prepaid' ? 'Prepaid' : 'Postpaid'} electricity',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token copied')));
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
          'Electricity',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvailableBalance(),
          const SizedBox(height: 16),
          _buildSavedBeneficiariesButton(),
          const SizedBox(height: 20),
          const Text(
            'Select provider',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          BillerGrid(
            options: kElectricityDiscos,
            selected: _selectedDisco,
            onSelect: (d) => setState(() {
              _selectedDisco = d;
              _resetVerification();
            }),
          ),
          const SizedBox(height: 20),
          if (_verifyError != null && _selectedDisco == null) ...[
            _buildErrorBanner(_verifyError!),
            const SizedBox(height: 16),
          ],
          const Text(
            'Meter type',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildMeterTypeToggle(),
          const SizedBox(height: 18),
          const Text(
            'Meter number',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _buildMeterField(),
          if (_isVerifying ||
              _verifiedCustomerName != null ||
              _verifyError != null) ...[
            const SizedBox(height: 10),
            _buildVerificationBanner(),
          ],
          if (_verifiedCustomerName != null) ...[
            const SizedBox(height: 8),
            _buildSaveAsBeneficiaryToggle(),
          ],
          const SizedBox(height: 18),
          const Text(
            'Amount',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _buildAmountField(),
          const SizedBox(height: 32),
          _buildProceedButton(),
          const SizedBox(height: 12),
        ],
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

  Widget _buildSavedBeneficiariesButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openBeneficiaryPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.people_alt_outlined, size: 19, color: AppColors.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved meters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 17, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterTypeToggle() {
    return Row(
      children: [
        Expanded(child: _meterTypeChip('Prepaid', 'prepaid')),
        const SizedBox(width: 10),
        Expanded(child: _meterTypeChip('Postpaid', 'postpaid')),
      ],
    );
  }

  Widget _meterTypeChip(String label, String value) {
    final isSelected = _meterType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _meterType = value);
        _resetVerification();
        _onMeterChanged(); // re-trigger verification for the new type, if a number is already entered
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
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

  Widget _buildMeterField() {
    return TextField(
      controller: _meterController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: _fieldDecoration(
        hint: 'Meter number',
        suffix: _isVerifying
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildVerificationBanner() {
    if (_verifyError != null) return _buildErrorBanner(_verifyError!);
    if (_isVerifying) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Verifying...',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _verifiedCustomerName ?? '',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveAsBeneficiaryToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _saveAsBeneficiary = !_saveAsBeneficiary),
      child: Row(
        children: [
          Icon(
            _saveAsBeneficiary
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            size: 22,
            color: _saveAsBeneficiary
                ? AppColors.teal
                : const Color.fromARGB(255, 67, 69, 72),
          ),
          const SizedBox(width: 6),
          const Text(
            'Save this meter',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: _fieldDecoration(hint: '₦0'),
      onChanged: (_) => setState(() {}),
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
        child: Text(
          'Review',
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
    final hasToken =
        !isPending &&
        _result!.purchasedCode != null &&
        _result!.purchasedCode!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
            isPending ? 'Processing' : 'Payment successful',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'Your electricity payment is being processed — check your history shortly for your token.'
                : '${_formatNaira(_result!.amount)} was paid to $_verifiedCustomerName.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (hasToken) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.teal, AppColors.tealDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your token',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result!.purchasedCode!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _copyToken(_result!.purchasedCode!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Copy token',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    );
  }
}

class _BillBeneficiaryPickerSheetElectricity extends StatefulWidget {
  @override
  State<_BillBeneficiaryPickerSheetElectricity> createState() =>
      _BillBeneficiaryPickerSheetElectricityState();
}

class _BillBeneficiaryPickerSheetElectricityState
    extends State<_BillBeneficiaryPickerSheetElectricity> {
  List<BillBeneficiary> _beneficiaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await BillsApi.getBeneficiaries('electricity');
      if (mounted)
        setState(() {
          _beneficiaries = list;
          _isLoading = false;
        });
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Saved',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                  )
                : _beneficiaries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Nothing saved yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _beneficiaries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final b = _beneficiaries[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.tealTint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            b.customerName.isNotEmpty ? b.customerName[0] : '?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                        title: Text(
                          b.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${b.billerName} · ${b.billersCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(b),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
