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
import 'package:first_app/money_format.dart';

const List<BillerOption> kCableProviders = [
  BillerOption(serviceId: 'dstv', name: 'DSTV', color: Color(0xFF002F6C)),
  BillerOption(serviceId: 'gotv', name: 'GOtv', color: Color(0xFF00A651)),
  BillerOption(
    serviceId: 'startimes',
    name: 'StarTimes',
    color: Color(0xFFED1C24),
  ),
];

const double kCableCommission = 100;

// Card / IUC numbers are digits only. DStv cards are 10 OR 11 digits, so the
// cap has to allow 11 — a hard cap of 10 would block real customers.
const int _kMinCardLength = 10;
const int _kMaxCardLength = 11;

// How long the user must stop typing before we look the number up.
const Duration _kVerifyDebounce = Duration(milliseconds: 800);

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  double _spendableBalance = 0;
  bool _isLoadingBalance = true;
  String _userPhone = '';

  BillerOption? _selectedProvider;
  final TextEditingController _smartcardController = TextEditingController();
  Timer? _debounce;

  bool _isVerifying = false;
  String? _verifiedCustomerName;
  String? _verifyError;

  // The exact number the shown name belongs to. This — not whatever is
  // currently typed — is what gets saved and paid, so the name on screen
  // and the card being paid can never disagree.
  String? _verifiedNumber;

  // Bumped on every edit and every new lookup. A lookup only applies its
  // result if its number is still the latest one; otherwise it was
  // superseded and its (stale) answer is thrown away. Without this, a slow
  // reply for a half-typed number could land AFTER the reply for the
  // finished number and put an error on screen.
  int _verifySeq = 0;

  // Lets the listener tell a real edit apart from a cursor move / focus
  // change (which also notify the controller, but change no text).
  String _lastSmartcardText = '';

  List<BillVariation> _packages = [];
  bool _isLoadingPackages = false;
  String? _packagesError;
  BillVariation? _selectedPackage;
  final TextEditingController _packageSearchController =
      TextEditingController();

  bool _saveAsBeneficiary = false;

  String? _resultAfterReview;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _loadUserPhone();
    _smartcardController.addListener(_onSmartcardChanged);
    _packageSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _smartcardController.removeListener(_onSmartcardChanged);
    _smartcardController.dispose();
    _packageSearchController.dispose();
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

  Future<void> _loadUserPhone() async {
    final phone = await LocalUserCache.getCachedPhone();
    if (mounted) setState(() => _userPhone = phone ?? '');
  }

  Future<void> _handleSelectProvider(
    BillerOption provider, {
    bool fromSavedCard = false,
  }) async {
    // Anything verified or in flight belonged to the previous provider.
    _debounce?.cancel();
    _verifySeq++;

    setState(() {
      _selectedProvider = provider;
      _selectedPackage = null;
      _packages = [];
      _packagesError = null;
      _isLoadingPackages = true;
      _packageSearchController.clear();

      _isVerifying = false;
      _verifiedCustomerName = null;
      _verifiedNumber = null;
      _verifyError = null;
      _saveAsBeneficiary = false;
    });

    // A number already typed may be valid for the new provider — look it up.
    // (Skipped for saved cards: their name is already known.)
    if (!fromSavedCard) _scheduleVerify();

    try {
      final packages = await BillsApi.getVariations(provider.serviceId);
      // The user may have switched provider while this was loading.
      if (!mounted || _selectedProvider != provider) return;
      setState(() {
        _packages = packages;
        _isLoadingPackages = false;
      });
    } on ApiException catch (e) {
      if (!mounted || _selectedProvider != provider) return;
      setState(() {
        _packagesError = e.message;
        _isLoadingPackages = false;
      });
    } catch (_) {
      if (!mounted || _selectedProvider != provider) return;
      setState(() {
        _packagesError =
            'Couldn\'t load packages. Check your connection and try again.';
        _isLoadingPackages = false;
      });
    }
  }

  void _handleChangePackage() {
    setState(() {
      _selectedPackage = null;
      _packageSearchController.clear();
    });
  }

  List<BillVariation> get _filteredPackages {
    final query = _packageSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _packages;
    return _packages
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  void _onSmartcardChanged() {
    final value = _smartcardController.text;

    // The controller also notifies on cursor moves and focus changes. Those
    // aren't edits and must not wipe a good result.
    if (value == _lastSmartcardText) return;
    _lastSmartcardText = value;

    // A real edit: whatever was shown or still in flight is now out of date.
    _debounce?.cancel();
    _verifySeq++;
    if (_isVerifying ||
        _verifiedCustomerName != null ||
        _verifiedNumber != null ||
        _verifyError != null) {
      setState(() {
        _isVerifying = false;
        _verifiedCustomerName = null;
        _verifiedNumber = null;
        _verifyError = null;
      });
    }

    _scheduleVerify();
  }

  /// Looks the number up once the user has stopped typing — and only once it
  /// is long enough to be a real card number, so half-typed numbers are
  /// never sent to the server at all.
  void _scheduleVerify() {
    _debounce?.cancel();
    final value = _smartcardController.text.trim();
    if (_selectedProvider == null || value.length < _kMinCardLength) return;

    _debounce = Timer(_kVerifyDebounce, () {
      if (mounted) _handleVerify();
    });
  }

  Future<void> _handleVerify() async {
    final provider = _selectedProvider;
    final number = _smartcardController.text.trim();
    if (provider == null || number.length < _kMinCardLength) return;

    final mySeq = ++_verifySeq;

    setState(() {
      _isVerifying = true;
      _verifiedCustomerName = null;
      _verifiedNumber = null;
      _verifyError = null;
    });

    try {
      final result = await BillsApi.verifyMerchant(
        serviceId: provider.serviceId,
        billersCode: number,
      );
      // Superseded by a newer edit or lookup while we waited — drop it.
      if (!mounted || mySeq != _verifySeq) return;
      setState(() {
        _isVerifying = false;
        _verifiedCustomerName = result.customerName;
        _verifiedNumber = number;
        _verifyError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || mySeq != _verifySeq) return;
      setState(() {
        _isVerifying = false;
        _verifyError = e.message;
      });
    } catch (_) {
      // Network failure, expired session, anything unexpected — never leave
      // the spinner running forever.
      if (!mounted || mySeq != _verifySeq) return;
      setState(() {
        _isVerifying = false;
        _verifyError =
            'Couldn\'t verify right now. Check your connection and try again.';
      });
    }
  }

  Future<void> _openBeneficiaryPicker() async {
    final picked = await showModalBottomSheet<BillBeneficiary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BillBeneficiaryPickerSheet(billType: 'cable'),
    );
    if (picked == null) return;

    final matchingProvider = kCableProviders.firstWhere(
      (p) => p.serviceId == picked.serviceId,
      orElse: () => kCableProviders.first,
    );

    // Fill in the saved number without it counting as a user edit, so it
    // isn't cleared or re-looked-up — the saved name is already trusted.
    _lastSmartcardText = picked.billersCode;
    _smartcardController.text = picked.billersCode;

    await _handleSelectProvider(matchingProvider, fromSavedCard: true);
    if (!mounted) return;
    setState(() {
      _verifiedCustomerName = picked.customerName;
      _verifiedNumber = picked.billersCode;
      _verifyError = null;
      _saveAsBeneficiary = false;
    });
  }

  String _formatNaira(double amount) => formatNaira(amount);

  bool get _canProceed =>
      _selectedProvider != null &&
      _verifiedCustomerName != null &&
      _verifiedNumber != null &&
      _smartcardController.text.trim() == _verifiedNumber &&
      _selectedPackage != null &&
      _userPhone.isNotEmpty;

  Future<void> _handleProceed() async {
    // Always the number that was actually verified, never a later edit.
    final smartcard = _verifiedNumber!;

    final total = _selectedPackage!.amount + kCableCommission;
    if (total > _spendableBalance) {
      setState(
        () => _packagesError =
            'Insufficient balance for this package plus commission.',
      );
      return;
    }

    if (_saveAsBeneficiary) {
      BillsApi.saveBeneficiary(
        billType: 'cable',
        serviceId: _selectedProvider!.serviceId,
        billerName: _selectedProvider!.name,
        billersCode: smartcard,
        customerName: _verifiedCustomerName!,
      ).catchError((_) {});
    }

    final result = await Navigator.of(context).push<BillPaymentResult>(
      MaterialPageRoute(
        builder: (_) => BillReviewScreen(
          billType: 'cable',
          serviceId: _selectedProvider!.serviceId,
          billerName: _selectedProvider!.name,
          phone: _userPhone,
          amount: _selectedPackage!.amount,
          commission: kCableCommission,
          billersCode: smartcard,
          variationCode: _selectedPackage!.code,
          customerName: _verifiedCustomerName,
          productLabel: _selectedPackage!.name,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(
        () => _resultAfterReview = result.isPending ? 'pending' : 'success',
      );
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
          'Cable TV',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _resultAfterReview != null ? _buildSuccessState() : _buildForm(),
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
            options: kCableProviders,
            selected: _selectedProvider,
            onSelect: (provider) => _handleSelectProvider(provider),
          ),
          const SizedBox(height: 20),
          if (_packagesError != null) ...[
            _buildErrorBanner(_packagesError!),
            const SizedBox(height: 16),
          ],
          if (_selectedProvider != null) ...[
            const Text(
              'Smartcard / IUC number',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _buildSmartcardField(),
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
            const SizedBox(height: 20),
            const Text(
              'Package',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            // THE FIX: once a package is picked, search + full list
            // collapse into a compact summary — same pattern as Data.
            _selectedPackage != null
                ? _buildSelectedPackageSummary()
                : _buildPackageSearchAndList(),
          ],
          const SizedBox(height: 32),
          _buildProceedButton(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSelectedPackageSummary() {
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
                  _selectedPackage!.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatNaira(_selectedPackage!.amount),
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
            onTap: _handleChangePackage,
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

  Widget _buildPackageSearchAndList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_packages.isNotEmpty) ...[
          _buildPackageSearchField(),
          const SizedBox(height: 10),
        ],
        _buildPackagesList(),
      ],
    );
  }

  Widget _buildPackageSearchField() {
    return TextField(
      controller: _packageSearchController,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search packages',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search,
          size: 19,
          color: AppColors.textMuted,
        ),
        suffixIcon: _packageSearchController.text.isNotEmpty
            ? InkWell(
                onTap: () => _packageSearchController.clear(),
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
                'Saved smartcards',
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

  Widget _buildSmartcardField() {
    return TextField(
      controller: _smartcardController,
      keyboardType: TextInputType.number,
      // Digits only, and never longer than a real card number. Pasted text
      // is cleaned the same way (spaces/dashes stripped, then trimmed).
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_kMaxCardLength),
      ],
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Smartcard number ($_kMinCardLength-$_kMaxCardLength digits)',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        suffixIcon: _isVerifying
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
            'Save this smartcard',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesList() {
    if (_isLoadingPackages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    if (_packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No packages available.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final filtered = _filteredPackages;
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No packages match your search.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: filtered.map((pkg) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedPackage = pkg),
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
                    pkg.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _formatNaira(pkg.amount),
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
    final isPending = _resultAfterReview == 'pending';
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
              isPending ? 'Processing' : 'Subscription successful',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your subscription is being processed — check your history shortly.'
                  : '${_selectedPackage?.name ?? ''} was activated for $_verifiedCustomerName.',
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

class _BillBeneficiaryPickerSheet extends StatefulWidget {
  final String billType;
  const _BillBeneficiaryPickerSheet({required this.billType});

  @override
  State<_BillBeneficiaryPickerSheet> createState() =>
      _BillBeneficiaryPickerSheetState();
}

class _BillBeneficiaryPickerSheetState
    extends State<_BillBeneficiaryPickerSheet> {
  List<BillBeneficiary> _beneficiaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await BillsApi.getBeneficiaries(widget.billType);
      if (mounted) {
        setState(() {
          _beneficiaries = list;
          _isLoading = false;
        });
      }
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
                    separatorBuilder: (_, _) =>
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
