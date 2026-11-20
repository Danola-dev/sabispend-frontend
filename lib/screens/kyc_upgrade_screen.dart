import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/kyc_api.dart';
import 'package:first_app/kyc_upgrade_api.dart';
import 'package:first_app/api_client.dart';

/// Raises the user's wallet tier (higher balance and deposit limits).
///   Tier 1 -> 2: NIN, address and 4 photos.
///   Tier 2 -> 3: ONE photo (proof of address).
/// 9PSB reviews the documents; the result arrives as a notification and shows here.
class WalletUpgradeScreen extends StatefulWidget {
  const WalletUpgradeScreen({super.key});

  @override
  State<WalletUpgradeScreen> createState() => _WalletUpgradeScreenState();
}

class _WalletUpgradeScreenState extends State<WalletUpgradeScreen> {
  static const int _maxImageBytes = 500 * 1024; // 9PSB limit per image

  final _picker = ImagePicker();

  KYCStatus? _status;
  WalletLimits? _limits;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _errorMessage;

  bool _pep = false;
  DateTime? _issueDate;

  final _ninController = TextEditingController();
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _lgaController = TextEditingController();
  final _stateController = TextEditingController();
  final _landmarkController = TextEditingController();

  final Map<String, String> _images = {}; // backend field name -> file path

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _ninController,
      _houseController,
      _streetController,
      _cityController,
      _lgaController,
      _stateController,
      _landmarkController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      var status = await KYCApi.getStatus();
      if (status.isUpgradePending) {
        status = await KYCUpgradeApi.refreshStatus();
      }
      WalletLimits? limits;
      try {
        limits = await KYCUpgradeApi.getLimits();
      } catch (_) {
        // Limits are nice to have; the screen works without them.
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _limits = limits;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Couldn\'t load your account. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  String _two(int n) => n.toString().padLeft(2, '0');
  String _display(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _naira(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final value = double.tryParse(raw);
    if (value == null) return raw;
    final whole = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i != 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '₦$buffer';
  }

  Future<void> _pickIssueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'Date your NIN was issued',
    );
    if (picked != null && mounted) setState(() => _issueDate = picked);
  }

  Future<void> _pickImage(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Downscaled and compressed so each photo stays under 9PSB's 500KB limit.
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 50,
    );
    if (picked == null || !mounted) return;

    final size = await File(picked.path).length();
    if (size > _maxImageBytes) {
      setState(
        () => _errorMessage =
            'That photo is too large (over 500KB). Take it again from a little further away or in lower resolution.',
      );
      return;
    }
    setState(() {
      _images[key] = picked.path;
      _errorMessage = null;
    });
  }

  bool _filled(TextEditingController c) => c.text.trim().isNotEmpty;

  /// 9PSB's test wallets report limits of 0. Only show limits that are real numbers above zero.
  bool _limitsKnown(WalletLimits? limits) {
    if (limits == null) return false;
    final balance = double.tryParse(limits.maximumBalance ?? '') ?? 0;
    final deposit = double.tryParse(limits.maximumDeposit ?? '') ?? 0;
    return balance > 0 || deposit > 0;
  }

  bool get _canSubmitTier2 =>
      !_isSubmitting &&
      _ninController.text.length == 11 &&
      _issueDate != null &&
      _filled(_houseController) &&
      _filled(_streetController) &&
      _filled(_cityController) &&
      _filled(_lgaController) &&
      _filled(_stateController) &&
      _filled(_landmarkController) &&
      _images.containsKey('user_photo') &&
      _images.containsKey('customer_signature') &&
      _images.containsKey('id_card_front') &&
      _images.containsKey('utility_bill');

  bool get _canSubmitTier3 {
    final needsNin = !(_status?.ninOnFile ?? false);
    return !_isSubmitting &&
        _images.containsKey('proof_of_address') &&
        (!needsNin || _ninController.text.length == 11);
  }

  Future<void> _submitTier2() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await KYCUpgradeApi.submitUpgrade(
        fields: {
          'nin': _ninController.text.trim(),
          'id_issue_date': _iso(_issueDate!),
          'pep': _pep ? 'YES' : 'NO',
          'house_number': _houseController.text.trim(),
          'street_name': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'local_government': _lgaController.text.trim(),
          'nearest_landmark': _landmarkController.text.trim(),
        },
        filePaths: {
          'user_photo': _images['user_photo']!,
          'customer_signature': _images['customer_signature']!,
          'id_card_front': _images['id_card_front']!,
          'utility_bill': _images['utility_bill']!,
        },
      );
      _afterSubmit(result);
    } on UpgradeException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitTier3() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await KYCUpgradeApi.submitTier3(
        nin: (_status?.ninOnFile ?? false) ? '' : _ninController.text.trim(),
        proofOfAddressPath: _images['proof_of_address']!,
      );
      _afterSubmit(result);
    } on UpgradeException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _afterSubmit(KYCStatus result) {
    if (!mounted) return;
    setState(() {
      _status = result;
      _images.clear();
      _errorMessage = null;
    });
  }

  // ------------------------------------------------------------------ build

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
          'Raise your limits',
          style: TextStyle(
            fontSize: 19,
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
            : _loadError != null
            ? _buildLoadError()
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

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFD64545)),
            const SizedBox(height: 14),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final status = _status!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTierCard(status),
        const SizedBox(height: 20),
        if (status.isUpgradePending)
          _buildPending(status)
        else if (status.walletTier >= 3)
          _buildNote(
            Icons.verified_outlined,
            'You\'re on the highest tier. There\'s nothing more to upgrade.',
          )
        else ...[
          if (status.isUpgradeDeclined &&
              (status.upgradeMessage ?? '').isNotEmpty) ...[
            _buildErrorBanner(status.upgradeMessage!),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],
          if (status.walletTier == 1) _buildTier2Form() else _buildTier3Form(),
        ],
      ],
    );
  }

  Widget _buildTierCard(KYCStatus status) {
    final limits = _limits;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your account level: Tier ${status.walletTier}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !_limitsKnown(limits)
                ? 'Higher tiers let you hold and receive more.'
                : 'Highest balance: ${_naira(limits!.maximumBalance)}\n'
                      'Highest single deposit: ${_naira(limits!.maximumDeposit)}',
            style: const TextStyle(
              fontSize: 14.5,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending(KYCStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNote(
          Icons.hourglass_top_rounded,
          status.upgradeMessage?.isNotEmpty == true
              ? status.upgradeMessage!
              : 'Your documents are being reviewed. This can take 1-2 business days. We\'ll notify you.',
        ),
        const SizedBox(height: 16),
        _buildButton(label: 'Check status', enabled: true, onTap: _load),
      ],
    );
  }

  Widget _buildTier2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNote(
          Icons.checklist_rounded,
          'Have these ready: your NIN, your NIN slip or card, a utility bill '
          '(light, water or similar), and a pen and paper for your signature.',
        ),
        const SizedBox(height: 20),
        _label('National Identification Number (NIN)'),
        _field(
          _ninController,
          hint: '11 digits',
          keyboard: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 16),
        _label('Date your NIN was issued'),
        _dateField(),
        const SizedBox(height: 22),
        const Text(
          'Where you live',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('House number'),
                  _field(_houseController, hint: '12'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Street'),
                  _field(_streetController, hint: 'Allen Avenue'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('City'),
                  _field(_cityController, hint: 'Ikeja'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('State'),
                  _field(_stateController, hint: 'Lagos'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Local government'),
        _field(_lgaController, hint: 'Ikeja'),
        const SizedBox(height: 14),
        _label('Nearest landmark'),
        _field(_landmarkController, hint: 'Opposite the Mobil filling station'),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pep,
          activeColor: AppColors.teal,
          title: const Text(
            'I hold, or recently held, a senior public office',
            style: TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
          ),
          subtitle: const Text(
            'Politically exposed person. Leave off if this doesn\'t apply.',
            style: TextStyle(fontSize: 12.5),
          ),
          onChanged: (v) => setState(() => _pep = v),
        ),
        const SizedBox(height: 18),
        const Text(
          'Photos',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _imageTile('user_photo', 'Your photo', 'A clear selfie, face visible'),
        _imageTile(
          'customer_signature',
          'Your signature',
          'Sign on plain white paper and photograph it',
        ),
        _imageTile(
          'id_card_front',
          'NIN slip or card',
          'The side with your photo and NIN',
        ),
        _imageTile(
          'utility_bill',
          'Utility bill',
          'Showing the address above, not older than 3 months',
        ),
        const SizedBox(height: 22),
        _buildButton(
          label: 'Submit for review',
          enabled: _canSubmitTier2,
          onTap: _submitTier2,
        ),
      ],
    );
  }

  Widget _buildTier3Form() {
    final needsNin = !(_status?.ninOnFile ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNote(
          Icons.home_outlined,
          'For tier 3 we only need ONE more thing: proof of your address. '
          'A recent utility bill, tenancy agreement or bank statement works.',
        ),
        const SizedBox(height: 20),
        if (needsNin) ...[
          _label('National Identification Number (NIN)'),
          _field(
            _ninController,
            hint: '11 digits',
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _imageTile(
          'proof_of_address',
          'Proof of address',
          'Clear photo of the whole document',
        ),
        const SizedBox(height: 22),
        _buildButton(
          label: 'Submit for review',
          enabled: _canSubmitTier3,
          onTap: _submitTier3,
        ),
      ],
    );
  }

  // ------------------------------------------------------------- small parts

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: keyboard == null
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: _decoration(hint),
      onChanged: (_) => setState(() {}),
    );
  }

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.teal, 1.5),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickIssueDate,
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
                _issueDate == null ? 'DD/MM/YYYY' : _display(_issueDate!),
                style: TextStyle(
                  fontSize: 16,
                  color: _issueDate == null
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
    );
  }

  Widget _imageTile(String key, String title, String subtitle) {
    final path = _images[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isSubmitting ? null : () => _pickImage(key),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: path == null ? AppColors.border : AppColors.teal,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: path == null
                    ? Container(
                        width: 56,
                        height: 56,
                        color: AppColors.tealTint,
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.teal,
                        ),
                      )
                    : Image.file(
                        File(path),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      path == null ? subtitle : 'Added. Tap to change.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (path != null)
                const Icon(Icons.check_circle, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNote(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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

  Widget _buildButton({
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
}
