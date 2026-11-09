import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/bills_api.dart';
import 'package:first_app/idempotency_key.dart';
import 'transaction_pin_sheet.dart';
import 'package:first_app/money_format.dart';

class BillReviewScreen extends StatefulWidget {
  final String billType;
  final String serviceId;
  final String billerName;
  final String phone;
  final double amount;
  final double commission;
  final String? billersCode;
  final String? variationCode;
  final String? customerName;
  final String
  productLabel; // e.g. "1.5GB - 30 Days", "DSTV Compact", "Prepaid electricity"

  const BillReviewScreen({
    super.key,
    required this.billType,
    required this.serviceId,
    required this.billerName,
    required this.phone,
    required this.amount,
    required this.commission,
    required this.productLabel,
    this.billersCode,
    this.variationCode,
    this.customerName,
  });

  @override
  State<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends State<BillReviewScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _total => widget.amount + widget.commission;

  String _formatNaira(double amount) => formatNaira(amount);

  Future<void> _handleConfirm() async {
    final pin = await showTransactionPinSheet(context);
    if (pin == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await BillsApi.payBill(
        billType: widget.billType,
        serviceId: widget.serviceId,
        billerName: widget.billerName,
        amount: widget.amount,
        phone: widget.phone,
        billersCode: widget.billersCode,
        variationCode: widget.variationCode,
        customerName: widget.customerName,
        transactionPin: pin,
        idempotencyKey: IdempotencyKey.generate(),
      );

      if (!mounted) return;

      if (result.isSuccessful || result.isPending) {
        Navigator.of(context).pop(result);
      } else {
        setState(
          () => _errorMessage =
              result.failureReason ?? 'Payment failed. Please try again.',
        );
      }
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Review',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _formatNaira(_total),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Total to be deducted',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(_errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      _buildDetailsCard(),
                    ],
                  ),
                ),
              ),
              _buildConfirmButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildRow('Provider', widget.billerName),
          if (widget.billersCode != null)
            _buildRow(
              widget.billType == 'electricity'
                  ? 'Meter number'
                  : 'Smartcard number',
              widget.billersCode!,
            ),
          if (widget.customerName != null)
            _buildRow('Customer', widget.customerName!),
          _buildRow('Product', widget.productLabel),
          _buildRow('Phone', widget.phone),
          const Divider(height: 1, color: AppColors.border),
          _buildRow('Amount', _formatNaira(widget.amount)),
          if (widget.commission > 0)
            _buildRow('Commission', _formatNaira(widget.commission)),
          _buildRow('Total', _formatNaira(_total), isBold: true, isLast: true),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textPrimary,
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

  Widget _buildConfirmButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isSubmitting ? null : _handleConfirm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.tealDark,
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
            : const Text(
                'Confirm & Pay',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
