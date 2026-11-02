import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/wallet_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/idempotency_key.dart';
import 'package:first_app/beneficiaries_api.dart';
import 'package:first_app/transactions_api.dart';
import 'summary_screen.dart';
import 'allowance_exhausted_screen.dart';

/// Inserts commas as thousand separators while typing (e.g. "5000" ->
/// "5,000"). Whole numbers only — this app's amount fields are always
/// entered as whole Naira, matching every other amount UI in the app.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i != 0 && (digitsOnly.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SendToBankScreen extends StatefulWidget {
  const SendToBankScreen({super.key});

  @override
  State<SendToBankScreen> createState() => _SendToBankScreenState();
}

class _SendToBankScreenState extends State<SendToBankScreen> {
  double _spendableBalance = 0;
  bool _isLoadingBalance = true;

  List<BeneficiaryData> _beneficiaries = [];
  bool _isLoadingBeneficiaries = true;

  List<BankData> _banks = [];
  bool _isLoadingBanks = true;
  String? _banksErrorMessage;

  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  BankData? _selectedBank;

  bool _isResolvingName = false;
  String? _resolvedAccountName;
  String? _resolveErrorMessage;

  bool _isExistingBeneficiary = false;
  bool _saveAsBeneficiary = false;

  static const double _minTransfer = 100;

  @override
  void initState() {
    super.initState();
    _accountNumberController.addListener(_maybeResolveAccountName);
    _fetchBalance();
    _fetchBeneficiaries();
    _fetchBanks();
  }

  @override
  void dispose() {
    _accountNumberController.removeListener(_maybeResolveAccountName);
    _accountNumberController.dispose();
    _amountController.dispose();
    _narrationController.dispose();
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

  Future<void> _fetchBeneficiaries() async {
    try {
      final list = await BeneficiariesApi.getAll();
      if (mounted) {
        setState(() {
          _beneficiaries = list;
          _isLoadingBeneficiaries = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoadingBeneficiaries = false);
    }
  }

  Future<void> _fetchBanks() async {
    try {
      final banks = await TransactionsApi.getBankList();
      if (mounted) {
        setState(() {
          _banks = banks;
          _isLoadingBanks = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _banksErrorMessage = e.message;
          _isLoadingBanks = false;
        });
      }
    }
  }

  bool _isAlreadySaved(String accountNumber, String bankName) {
    return _beneficiaries.any(
      (b) => b.accountNumber == accountNumber && b.bankName == bankName,
    );
  }

  void _maybeResolveAccountName() {
    final numberComplete = _accountNumberController.text.length == 10;
    if (numberComplete && _selectedBank != null) {
      _resolveAccountName();
    } else if (_resolvedAccountName != null) {
      setState(() => _resolvedAccountName = null);
    }
  }

  Future<void> _resolveAccountName() async {
    setState(() {
      _isResolvingName = true;
      _resolvedAccountName = null;
      _resolveErrorMessage = null;
      _saveAsBeneficiary = false;
    });

    try {
      final result = await TransactionsApi.resolveAccount(
        accountNumber: _accountNumberController.text,
        bankCode: _selectedBank!.code,
      );

      if (!mounted) return;
      setState(() {
        _isResolvingName = false;
        _resolvedAccountName = result.accountName;
        _isExistingBeneficiary = _isAlreadySaved(
          _accountNumberController.text,
          _selectedBank!.name,
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingName = false;
        _resolveErrorMessage = e.message;
      });
    }
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

  // NEW: the amount field now displays comma-formatted text (e.g.
  // "5,000"), which is NOT directly parseable as a number — every place
  // that needs the actual numeric value goes through this getter,
  // which strips the commas first.
  double? get _parsedAmount =>
      double.tryParse(_amountController.text.replaceAll(',', ''));

  bool get _canProceed =>
      _accountNumberController.text.length == 10 &&
      _selectedBank != null &&
      _resolvedAccountName != null &&
      _parsedAmount != null &&
      _parsedAmount! >= _minTransfer;

  Future<void> _openBankPicker() async {
    if (_banksErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t load banks: $_banksErrorMessage')),
      );
      return;
    }
    final picked = await showModalBottomSheet<BankData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _BankPickerSheet(banks: _banks, isLoading: _isLoadingBanks),
    );
    if (picked != null) {
      setState(() => _selectedBank = picked);
      _maybeResolveAccountName();
    }
  }

  void _applyBeneficiary(BeneficiaryData beneficiary) {
    final matchingBank = _banks.firstWhere(
      (b) => b.name == beneficiary.bankName,
      orElse: () => BankData(
        name: beneficiary.bankName,
        code: beneficiary.bankCode ?? '',
      ),
    );
    setState(() {
      _accountNumberController.text = beneficiary.accountNumber;
      _selectedBank = matchingBank;
      _resolvedAccountName = beneficiary.accountName;
      _isExistingBeneficiary = true;
      _saveAsBeneficiary = false;
      _isResolvingName = false;
    });
  }

  Future<void> _openBeneficiaryPicker() async {
    final picked = await showModalBottomSheet<BeneficiaryData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BeneficiaryPickerSheet(
        beneficiaries: _beneficiaries,
        isLoading: _isLoadingBeneficiaries,
      ),
    );
    if (picked != null) _applyBeneficiary(picked);
  }

  void _saveBeneficiaryInBackground() {
    BeneficiariesApi.create(
      accountName: _resolvedAccountName!,
      accountNumber: _accountNumberController.text,
      bankName: _selectedBank!.name,
      bankCode: _selectedBank!.code,
    ).catchError(
      (_) => BeneficiaryData(
        id: -1,
        accountName: '',
        accountNumber: '',
        bankName: '',
      ),
    );
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
          'Send to bank',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildAvailableBalance(),
              const SizedBox(height: 20),
              _buildSavedBeneficiariesButton(),
              const SizedBox(height: 20),
              _buildFieldLabel('Account number'),
              const SizedBox(height: 6),
              _buildAccountNumberField(),
              const SizedBox(height: 16),
              _buildFieldLabel('Bank'),
              const SizedBox(height: 6),
              _buildBankSelectorField(),
              if (_isResolvingName || _resolvedAccountName != null) ...[
                const SizedBox(height: 10),
                _buildResolvedNameBanner(),
              ],
              if (_resolveErrorMessage != null) ...[
                const SizedBox(height: 10),
                _buildResolveErrorBanner(),
              ],
              if (_resolvedAccountName != null && !_isExistingBeneficiary) ...[
                const SizedBox(height: 8),
                _buildSaveAsBeneficiaryToggle(),
              ],
              const SizedBox(height: 16),
              _buildFieldLabel('Amount'),
              const SizedBox(height: 6),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildFieldLabel('Narration (optional)'),
              const SizedBox(height: 6),
              _buildNarrationField(),
              const SizedBox(height: 32),
              _buildProceedButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
                'Saved beneficiaries',
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
            'Save as beneficiary',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
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

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
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

  Widget _buildAccountNumberField() {
    return TextField(
      controller: _accountNumberController,
      keyboardType: TextInputType.number,
      maxLength: 10,
      style: const TextStyle(
        fontSize: 15,
        color: Color.fromARGB(255, 0, 0, 0),
        letterSpacing: 0.5,
      ),
      decoration: _fieldDecoration(
        hint: '0123456789',
      ).copyWith(counterText: ''),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBankSelectorField() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openBankPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _isLoadingBanks
                ? const Text(
                    'Loading banks...',
                    style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                  )
                : Text(
                    _selectedBank?.name ?? 'Select bank',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedBank != null
                          ? const Color.fromARGB(255, 5, 6, 6)
                          : AppColors.textMuted,
                    ),
                  ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedNameBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (_isResolvingName) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Verifying account...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const Icon(Icons.check_circle, size: 16, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _resolvedAccountName ?? '',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolveErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFD64545)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _resolveErrorMessage ?? '',
              style: const TextStyle(fontSize: 13, color: Color(0xFFD64545)),
            ),
          ),
        ],
      ),
    );
  }

  // CHANGED: added inputFormatters — digits only, then the thousands
  // separator formatter. Hint updated since ₦0.00 implied decimals,
  // which this whole-number formatter doesn't support.
  Widget _buildAmountField() {
    final amount = _parsedAmount;
    final belowMinimum = amount != null && amount > 0 && amount < _minTransfer;

    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ThousandsSeparatorInputFormatter(),
      ],
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: _fieldDecoration(
        hint: '₦100 minimum',
      ).copyWith(errorText: belowMinimum ? 'Minimum transfer is ₦100' : null),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildNarrationField() {
    return TextField(
      controller: _narrationController,
      style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
      decoration: _fieldDecoration(hint: 'What\'s this for?'),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildProceedButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _canProceed
          ? () {
              // CHANGED: use the comma-stripping getter, not a raw parse
              // of the (now comma-formatted) controller text.
              final amount = _parsedAmount!;

              if (_saveAsBeneficiary) _saveBeneficiaryInBackground();

              if (amount > _spendableBalance) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AllowanceExhaustedScreen(
                      currentBalance: _spendableBalance,
                      attemptedAmount: amount,
                    ),
                  ),
                );
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SendToBankSummaryScreen(
                    recipientName: _resolvedAccountName!,
                    bank: _selectedBank!.name,
                    bankCode: _selectedBank!.code,
                    accountNumber: _accountNumberController.text,
                    amount: amount,
                    narration: _narrationController.text.trim().isEmpty
                        ? null
                        : _narrationController.text.trim(),
                    idempotencyKey: IdempotencyKey.generate(),
                  ),
                ),
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _canProceed ? AppColors.tealDark : AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
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
}

class _BankPickerSheet extends StatefulWidget {
  final List<BankData> banks;
  final bool isLoading;

  const _BankPickerSheet({required this.banks, required this.isLoading});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<BankData> _filteredBanks;

  @override
  void initState() {
    super.initState();
    _filteredBanks = widget.banks;
    _searchController.addListener(_filterBanks);
  }

  @override
  void didUpdateWidget(covariant _BankPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banks != widget.banks) _filteredBanks = widget.banks;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBanks() {
    final query = _searchController.text.toLowerCase();
    setState(
      () => _filteredBanks = widget.banks
          .where((b) => b.name.toLowerCase().contains(query))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
            'Select bank',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search banks',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted,
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.teal,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  )
                : _filteredBanks.isEmpty
                ? const Center(
                    child: Text(
                      'No banks found',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredBanks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final bank = _filteredBanks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.tealTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                            color: AppColors.teal,
                          ),
                        ),
                        title: Text(
                          bank.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(bank),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BeneficiaryPickerSheet extends StatelessWidget {
  final List<BeneficiaryData> beneficiaries;
  final bool isLoading;

  const _BeneficiaryPickerSheet({
    required this.beneficiaries,
    required this.isLoading,
  });

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
            'Saved beneficiaries',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                  )
                : beneficiaries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No saved beneficiaries yet.\nSave someone after your next transfer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Color.fromARGB(255, 50, 52, 56),
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: beneficiaries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final b = beneficiaries[index];
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
                            b.accountName.isNotEmpty ? b.accountName[0] : '?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                        title: Text(
                          b.accountName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${b.bankName} · ${b.accountNumber}',
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
