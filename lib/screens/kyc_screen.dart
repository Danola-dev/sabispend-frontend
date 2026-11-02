import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/kyc_api.dart';
import 'package:first_app/api_client.dart';

/// Shown the first time a user tries to fund their account. Collects name +
/// BVN and creates the user's personal account number in one step.
class BvnKycScreen extends StatefulWidget {
  const BvnKycScreen({super.key});

  @override
  State<BvnKycScreen> createState() => _BvnKycScreenState();
}

class _BvnKycScreenState extends State<BvnKycScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();

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
  /// immediately, not a blank form.
  Future<void> _checkExistingStatus() async {
    try {
      final status = await KYCApi.getStatus();
      if (!mounted) return;
      if (status.isActive) {
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
    super.dispose();
  }

  bool get _canSubmit =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _bvnController.text.length == 11 &&
      !_isSubmitting;

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
      );

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: _result?.isActive != true,
        leading: _result?.isActive == true
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Text(
          _result == null
              ? 'Verify your identity'
              : (_result!.isActive ? 'You\'re verified' : 'Verification'),
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
    if (_result == null) return _buildForm();
    if (_result!.isActive) return _buildSuccessState();
    if (_result!.isFailed) return _buildFailedState();
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
          'We use your BVN to confirm it\'s really you — this is what lets us '
          'generate a personal bank account number just for you, so you can fund '
          'your wallet by transfer, the same way you would with any other bank app.',
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
                  'Enter your name exactly as it appears on your BVN.',
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
          label: 'Verify and generate account',
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
                'Verified securely through PayVessel and PalmPay.',
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
