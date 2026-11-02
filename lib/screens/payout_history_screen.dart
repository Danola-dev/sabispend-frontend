import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transactions_api.dart';

class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  late Future<List<PayoutHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = TransactionsApi.getPayoutHistory();
  }

  String _formatNaira(double amount) {
    final wholeAmount = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholeAmount.length; i++) {
      if (i != 0 && (wholeAmount.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeAmount[i]);
    }
    return '₦$buffer';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    int hour12 = local.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final ampm = local.hour < 12 ? 'AM' : 'PM';
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
    final month = months[local.month - 1];
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, $hour12:$minute $ampm';
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
          'Payout history',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<PayoutHistoryEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Couldn\'t load payout history right now.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              );
            }

            final payouts = snapshot.data ?? [];
            if (payouts.isEmpty) {
              return const Center(
                child: Text(
                  'No payouts yet.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: payouts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final payout = payouts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payout released',
                            style: TextStyle(
                              fontSize: 16.5,
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            _formatTime(payout.createdAt),
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color.fromARGB(255, 99, 103, 110),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+${_formatNaira(payout.amount)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
