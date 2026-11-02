import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transactions_api.dart';
import 'package:first_app/transaction_display_helpers.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionResult transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  String _formatNaira(double amount) {
    final wholeAmount = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholeAmount.length; i++) {
      if (i != 0 && (wholeAmount.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeAmount[i]);
    }
    return '₦$buffer';
  }

  String _formatFullDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  ({String label, Color color, Color bgColor}) _statusDisplay(String status) {
    switch (status) {
      case 'finalized':
        return (
          label: 'Successful',
          color: AppColors.teal,
          bgColor: AppColors.tealTint,
        );
      case 'reserved':
      case 'processing':
        return (
          label: 'Processing',
          color: const Color(0xFFB8860B),
          bgColor: const Color(0xFFFFF6E0),
        );
      case 'failed':
      case 'reversed':
        return (
          label: 'Failed',
          color: const Color(0xFFD64545),
          bgColor: const Color(0xFFFDECEC),
        );
      default:
        return (
          label: status,
          color: AppColors.textMuted,
          bgColor: AppColors.card,
        );
    }
  }

  void _copyReference(BuildContext context, String reference) {
    Clipboard.setData(ClipboardData(text: reference));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reference copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = transactionIsOutgoing(transaction.transactionType);
    final sign = outgoing ? '-' : '+';
    final amountColor = outgoing ? const Color(0xFFD64545) : AppColors.teal;
    final status = _statusDisplay(transaction.status);
    final hasFees =
        transaction.feeAmount > 0 ||
        transaction.paystackFeePassthrough > 0 ||
        transaction.stampDutyAmount > 0;
    final totalDeducted =
        transaction.amount +
        transaction.feeAmount +
        transaction.paystackFeePassthrough +
        transaction.stampDutyAmount;

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
          'Transaction details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.tealTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transactionIconFor(transaction.transactionType),
                  size: 30,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$sign${_formatNaira(transaction.amount)}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: status.bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      'Transaction type',
                      transactionTitleFor(transaction.transactionType),
                    ),
                    _divider(),
                    _detailRow(
                      'Date & time',
                      _formatFullDateTime(transaction.createdAt),
                    ),
                    _divider(),
                    _detailRow(
                      'Reference',
                      transaction.id,
                      copyable: true,
                      onCopy: () => _copyReference(context, transaction.id),
                    ),
                    if (transaction.narration != null &&
                        transaction.narration!.isNotEmpty) ...[
                      _divider(),
                      _detailRow('Narration', transaction.narration!),
                    ],
                    if (transaction.recipientName != null &&
                        transaction.recipientName!.isNotEmpty) ...[
                      _divider(),
                      _detailRow('Recipient', transaction.recipientName!),
                    ],
                    if (transaction.recipientAccountNumber != null &&
                        transaction.recipientAccountNumber!.isNotEmpty) ...[
                      _divider(),
                      _detailRow(
                        'Account number',
                        transaction.recipientAccountNumber!,
                      ),
                    ],
                    if (transaction.failureReason != null &&
                        transaction.failureReason!.isNotEmpty) ...[
                      _divider(),
                      _detailRow(
                        'Reason',
                        transaction.failureReason!,
                        valueColor: const Color(0xFFD64545),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasFees) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Amount', _formatNaira(transaction.amount)),
                      if (transaction.feeAmount +
                              transaction.paystackFeePassthrough >
                          0) ...[
                        _divider(),
                        _detailRow(
                          'Fees',
                          _formatNaira(
                            transaction.feeAmount +
                                transaction.paystackFeePassthrough,
                          ),
                        ),
                      ],
                      if (transaction.stampDutyAmount > 0) ...[
                        _divider(),
                        _detailRow(
                          'Tax',
                          _formatNaira(transaction.stampDutyAmount),
                        ),
                      ],
                      _divider(),
                      _detailRow(
                        'Total',
                        _formatNaira(totalDeducted),
                        valueBold: true,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppColors.border);

  Widget _detailRow(
    String label,
    String value, {
    bool copyable = false,
    VoidCallback? onCopy,
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onCopy,
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
