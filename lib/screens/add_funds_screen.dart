import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/kyc_api.dart';
import 'package:first_app/api_client.dart';
import 'kyc_screen.dart';

/// Add Funds screen — shows the user's REAL dedicated virtual account
/// number to transfer income into. First time this is opened, the user
/// is sent through BVN verification before ever seeing an account
/// number (since none exists yet). Every time after, this screen goes
/// straight to showing their existing account — no repeat verification.
class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  bool _isLoading = true;
  KYCStatus? _kycStatus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkKycAndProceed();
  }

  Future<void> _checkKycAndProceed() async {
    try {
      final status = await KYCApi.getStatus();
      if (!mounted) return;

      if (status.isActive) {
        // Already verified from a previous visit — show the account
        // straight away, no detour through the KYC screen.
        setState(() {
          _kycStatus = status;
          _isLoading = false;
        });
        return;
      }

      // Not verified yet (never submitted, or submitted but still
      // pending/failed) — send them through verification FIRST. This
      // screen shows nothing else until that's resolved.
      final completed = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const BvnKycScreen()));

      if (!mounted) return;

      if (completed == true) {
        // Re-check status now that BvnKycScreen reported success —
        // this is what gets us the real account number/bank name.
        final updated = await KYCApi.getStatus();
        if (!mounted) return;
        setState(() {
          _kycStatus = updated;
          _isLoading = false;
        });
      } else {
        // User backed out of verification without completing it —
        // nothing to show here, so leave with them.
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
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
          'Add funds',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : _errorMessage != null
            ? _buildErrorState()
            : _kycStatus?.isActive == true
            ? _buildAccountView(context, _kycStatus!)
            : const SizedBox.shrink(), // mid-navigation-away, nothing to show
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFD64545)),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _checkKycAndProceed,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountView(BuildContext context, KYCStatus kyc) {
    final bankName = kyc.dedicatedAccountBankName ?? '';
    final accountNumber = kyc.dedicatedAccountNumber ?? '';
    final accountName = kyc.dedicatedAccountName ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Transfer to your dedicated account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Any amount sent here is added to your locked balance and released on your payout schedule.',
            style: TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 38, 40, 43),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildAccountCard(context, bankName, accountNumber, accountName),
          const SizedBox(height: 16),
          _buildActionsRow(context, accountNumber),
          const SizedBox(height: 28),
          _buildHowItWorks(),
          const SizedBox(height: 20),
          _buildDepositFeeNote(),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    String bankName,
    String accountNumber,
    String accountName,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF14213D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bankName,
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Dedicated account',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _spacedAccountNumber(accountNumber),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _copyToClipboard(context, accountNumber),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (accountName.isNotEmpty)
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 17.5,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  String _spacedAccountNumber(String number) {
    final buffer = StringBuffer();
    for (int i = 0; i < number.length; i++) {
      buffer.write(number[i]);
      if ((i + 1) % 4 == 0 && i != number.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account number copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, String accountNumber) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.copy_rounded,
            label: 'Copy details',
            onTap: () => _copyToClipboard(context, accountNumber),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.tealTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      'Transfer any amount from your bank app to the account above',
      'We detect the deposit automatically — no need to confirm manually',
      'It\'s added to your locked balance and released on your payout schedule',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How it works',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.tealTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(255, 42, 45, 48),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDepositFeeNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 18, color: AppColors.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'A small 1% fee applies to deposits. It\'s required by our banking '
              'partners to process and secure your transfers.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
