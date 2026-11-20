import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/kyc_api.dart';
import 'package:first_app/api_client.dart';

/// Shown the first time a user tries to fund their account. Two steps:
///   1. name, date of birth, gender, address + BVN  -> 9PSB sends a code to the phone linked to the BVN
///   2. enter the 6-digit code                      -> the user's personal 9PSB account number is created
class BvnKycScreen extends StatefulWidget {
  const BvnKycScreen({super.key});

  @override
  State<BvnKycScreen> createState() => _BvnKycScreenState();
}

class _BvnKycScreenState extends State<BvnKycScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  DateTime? _dob;
  String? _gender; // 'male' | 'female'

  bool _isSubmitting = false;
  bool _isCheckingExisting = true;
  String? _errorMessage;
  KYCStatus? _result;

  @override
  void initState() {
    super.initState();
    _checkExistingStatus();
  }

  /// A returning user who already has an account number should see it
  /// immediately, and one who is part-way through should see the code step,
  /// not a blank form.
  Future<void> _checkExistingStatus() async {
    try {
      final status = await KYCApi.getStatus();
      if (!mounted) return;
      if (status.isActive || status.isOtpPending) {
        setState(() => _result = status);
      }
    } catch (_) {
      // Fall through to the blank form — safe default.
    } finally {
      if (mounted) setState(() => _isCheckingExisting = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bvnController.dispose();
    _addressController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _bvnController.text.length == 11 &&
      _dob != null &&
      _gender != null &&
      _addressController.text.trim().length >= 5 &&
      !_isSubmitting;

  bool get _canVerify => _otpController.text.length == 6 && !_isSubmitting;

  String _two(int n) => n.toString().padLeft(2, '0');
  String _formatDob(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _isoDob(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth (as on your BVN)',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await KYCApi.submitKYC(
        bvn: _bvnController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _isoDob(_dob!),
        gender: _gender!,
        address: _addressController.text.trim(),
      );

      if (!mounted) return;
      _otpController.clear();
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Couldn\'t reach the server. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await KYCApi.verifyOtp(otp: _otpController.text);
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Couldn\'t reach the server. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startOver() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final String title;
    if (result == null) {
      title = 'Verify your identity';
    } else if (result.isActive) {
      title = 'You\'re verified';
    } else if (result.isOtpPending) {
      title = 'Enter your code';
    } else {
      title = 'Verification';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: result?.isActive != true,
        leading: result?.isActive == true
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isCheckingExisting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: _buildBody(),
              ),
      ),
    );
  }

  Widget _buildBody() {
    final result = _result;
    if (result == null) return _buildForm();
    if (result.isActive) return _buildSuccessState();
    if (result.isFailed) return _buildFailedState();
    if (result.isOtpPending) return _buildOtpState();
    return _buildForm();
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),
        const Text(
          'One quick step before you fund your wallet',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'We use your BVN to confirm it\'s really you. We\'ll text a code to '
          'the phone number linked to your BVN, then create a personal 9PSB '
          'account number just for you, so you can fund your wallet by '
          'transfer, the same way you would with any other bank app.',
          style: TextStyle(
            fontSize: 15.5,
            color: Color.fromARGB(255, 78, 83, 88),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('First name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _fieldDecoration(hint: 'Danola'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Last name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _fieldDecoration(hint: 'Okafor'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('Date of birth'),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDob,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dob == null ? 'DD/MM/YYYY' : _formatDob(_dob!),
                    style: TextStyle(
                      fontSize: 16,
                      color: _dob == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('Gender'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildGenderOption('Male', 'male')),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderOption('Female', 'female')),
          ],
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('Home address'),
        const SizedBox(height: 6),
        TextField(
          controller: _addressController,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: _fieldDecoration(hint: '12 Allen Avenue, Ikeja, Lagos'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('Bank Verification Number (BVN)'),
        const SizedBox(height: 6),
        TextField(
          controller: _bvnController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          decoration: _fieldDecoration(hint: '12345678901'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 5),
        const Text(
          'Dial *565*0# on your registered phone if you don\'t know your BVN.',
          style: TextStyle(
            fontSize: 13.5,
            color: Color.fromARGB(255, 76, 79, 85),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.tealTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.badge_outlined, size: 18, color: AppColors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter your name and date of birth exactly as they appear on your BVN.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Send me a code',
          enabled: _canSubmit,
          onTap: _handleSubmit,
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(
              Icons.lock_outline,
              size: 21,
              color: Color.fromARGB(255, 28, 111, 255),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Verified securely through 9PSB (9Payment Service Bank).',
                style: TextStyle(
                  fontSize: 15,
                  color: Color.fromARGB(255, 16, 100, 245),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String label, String value) {
    final selected = _gender == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.tealDark : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.tealDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildOtpState() {
    final phone = _result?.maskedPhone ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.tealTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sms_outlined,
            color: AppColors.teal,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter the code we sent you',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          phone.isEmpty
              ? 'We sent a 6-digit code to the phone number linked to your BVN. '
                    'It expires in 10 minutes.'
              : 'We sent a 6-digit code to $phone, the phone number linked to '
                    'your BVN. It expires in 10 minutes.',
          style: const TextStyle(
            fontSize: 15.5,
            color: Color.fromARGB(255, 78, 83, 88),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildFieldLabel('6-digit code'),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 20,
            color: AppColors.textPrimary,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(hint: '123456'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Verify and generate account',
          enabled: _canVerify,
          onTap: _handleVerifyOtp,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isSubmitting ? null : _startOver,
            child: const Text('Didn\'t get a code? Start again'),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFDECEC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Color(0xFFD64545),
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'We couldn\'t verify those details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _result?.failureReason ??
              'Please double-check your details and try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label: 'Try again',
          enabled: true,
          onTap: _startOver,
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.tealTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.teal,
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'You\'re verified',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Here\'s your personal account number — fund your wallet anytime by transferring to it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
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
              Text(
                _result?.dedicatedAccountBankName ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                _result?.dedicatedAccountNumber ?? '',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
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
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
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
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
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

  InputDecoration _fieldDecoration({required String hint}) {
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
}
