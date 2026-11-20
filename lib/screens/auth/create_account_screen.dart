import 'package:first_app/screens/auth/welcome_back_screen.dart';
import 'package:first_app/screens/legal_documents_screen.dart';
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

  // Each legal document now has its own, independent consent checkbox.
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Opens the real document. The user closes it with the back button /
  // back gesture and lands right here again, with everything they typed
  // still in place, then decides whether to tick the box.
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
      _agreedToPrivacy &&
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
              _buildConsentTile(
                title: 'Terms of Service',
                subtitle: 'I have read and agree to the Terms of Service.',
                value: _agreedToTerms,
                onToggle: () =>
                    setState(() => _agreedToTerms = !_agreedToTerms),
                onRead: _openTermsOfService,
              ),
              const SizedBox(height: 12),
              _buildConsentTile(
                title: 'Privacy Policy',
                subtitle: 'I have read and agree to the Privacy Policy.',
                value: _agreedToPrivacy,
                onToggle: () =>
                    setState(() => _agreedToPrivacy = !_agreedToPrivacy),
                onRead: _openPrivacyPolicy,
              ),
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

  /// A rounded, animated checkbox with a white tick.
  Widget _buildCheckbox(bool checked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? AppColors.teal : AppColors.textMuted,
          width: 1.6,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: checked
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey('checked'),
                size: 17,
                color: Colors.white,
              )
            : const SizedBox.shrink(key: ValueKey('unchecked')),
      ),
    );
  }

  /// One consent card per legal document. Tapping the card toggles the
  /// checkbox; tapping "Read" opens the document without toggling anything.
  Widget _buildConsentTile({
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onToggle,
    required VoidCallback onRead,
  }) {
    return Semantics(
      checked: value,
      label: subtitle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? AppColors.teal : AppColors.border,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  _buildCheckbox(value),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onRead,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Read',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.teal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
