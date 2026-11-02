import 'package:flutter/material.dart';

IconData transactionIconFor(String type) {
  switch (type) {
    case 'deposit':
      return Icons.arrow_downward;
    case 'transfer':
      return Icons.arrow_upward;
    case 'bill_payment':
      return Icons.receipt_long_outlined;
    case 'early_unlock':
      return Icons.lock_open_rounded;
    case 'payout_release':
      return Icons.celebration_outlined;
    default:
      return Icons.swap_horiz;
  }
}

String transactionTitleFor(String type) {
  switch (type) {
    case 'deposit':
      return 'Deposit';
    case 'transfer':
      return 'Transfer to bank';
    case 'bill_payment':
      return 'Bill payment';
    case 'early_unlock':
      return 'Early unlock';
    case 'payout_release':
      return 'Payout released';
    default:
      return type;
  }
}

/// Outgoing (leaves spendable balance) vs incoming (adds to it) —
/// decides the +/- prefix and color everywhere a transaction is shown.
bool transactionIsOutgoing(String type) =>
    type == 'transfer' || type == 'bill_payment';

String formatTransactionTime(DateTime dateTime) {
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
  final now = DateTime.now();
  final isToday =
      dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day;

  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
  final timeLabel = '$hour:$minute $ampm';

  if (isToday) return 'Today, $timeLabel';
  return '${months[dateTime.month - 1]} ${dateTime.day}, $timeLabel';
}
