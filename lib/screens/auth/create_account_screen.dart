import 'package:first_app/screens/auth/welcome_back_screen.dart';
import 'package:first_app/screens/legal_documents_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/auth_api.dart';
import 'package:first_app/api_client.dart';
import 'otp_verification_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Tap handlers for the two links inside the terms sentence. These must
  // be disposed, otherwise they leak.
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTermsOfService;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Opens the real document. The user closes it with the back button /
  // back gesture and lands right here again, with everything they typed
  // still in place, then decides whether to tick "I agree".
  void _openTermsOfService() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen.termsOfService()),
    );
  }

  void _openPrivacyPolicy() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen.privacyPolicy()),
    );
  }

  bool get _isPhoneValid {
    final phone = _phoneController.text;
    return phone.length == 11 &&
        phone.startsWith('0') &&
        RegExp(r'^\d{11}$').hasMatch(phone);
  }

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.') && email.length > 5;
  }

  bool get _canContinue =>
      _nameController.text.trim().length >= 2 &&
      _isPhoneValid &&
      _isEmailValid &&
      _agreedToTerms &&
      !_isSubmitting;

  Future<void> _handleContinue() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final fullName = _nameController.text.trim();

    try {
      final email = await AuthApi.signup(
        fullName: fullName,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            purpose: 'signup',
            fullName: fullName,
            phoneNumber: _phoneController.text
                .trim(), // carried forward — needed at SetPinScreen
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'ll email you a code to verify your account.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              _buildFieldLabel('Full name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: '',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'you@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Phone number'),
              const SizedBox(height: 8),
              _buildPhoneField(),
              const SizedBox(height: 24),
              _buildTermsCheckbox(),
              const SizedBox(height: 32),
              _buildContinueButton(),
              const SizedBox(height: 25),
              _buildSignIn(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
      counterText: counterText,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: _fieldDecoration(hint: hint),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
      decoration: _fieldDecoration(hint: '', counterText: ''),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSignIn() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account?', style: TextStyle(fontSize: 16)),
        SizedBox(width: 4),
        InkWell(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) {
                  return WelcomeBackScreen();
                },
              ),
            );
          },
          child: Text(
            'Sign in',
            style: TextStyle(
              fontSize: 18,
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    const linkStyle = TextStyle(
      color: AppColors.teal,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.teal,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only the checkbox itself toggles agreement. The links open the
        // documents and never tick the box by accident.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 8, bottom: 6),
            child: Icon(
              _agreedToTerms ? Icons.check_box : Icons.check_box_outline_blank,
              size: 23,
              color: _agreedToTerms
                  ? AppColors.teal
                  : const Color.fromARGB(255, 16, 16, 18),
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: Color.fromARGB(255, 13, 14, 15),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: linkStyle,
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: linkStyle,
                  recognizer: _privacyRecognizer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _canContinue ? _handleContinue : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _canContinue ? AppColors.tealDark : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.blue,
                ),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _canContinue ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}
