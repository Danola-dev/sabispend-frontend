import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transactions_api.dart';
import 'package:first_app/api_client.dart';
import 'package:first_app/transaction_display_helpers.dart';
import 'transaction_detail_screen.dart';

enum _PeriodFilter { all, today, thisWeek, thisMonth, last3Months }

enum _TypeFilter { all, moneyIn, moneyOut }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<TransactionResult> _allTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  _PeriodFilter _periodFilter = _PeriodFilter.all;
  _TypeFilter _typeFilter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await TransactionsApi.getHistory();
      if (mounted) {
        setState(() {
          _allTransactions = history;
          _isLoading = false;
        });
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

  String _formatNaira(double amount) {
    final wholeAmount = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholeAmount.length; i++) {
      if (i != 0 && (wholeAmount.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeAmount[i]);
    }
    return '₦$buffer';
  }

  List<TransactionResult> get _filteredTransactions {
    final now = DateTime.now();
    return _allTransactions.where((txn) {
      // Period filter
      switch (_periodFilter) {
        case _PeriodFilter.all:
          break;
        case _PeriodFilter.today:
          if (!_isSameDay(txn.createdAt, now)) return false;
          break;
        case _PeriodFilter.thisWeek:
          if (now.difference(txn.createdAt).inDays > 7) return false;
          break;
        case _PeriodFilter.thisMonth:
          if (txn.createdAt.year != now.year ||
              txn.createdAt.month != now.month)
            return false;
          break;
        case _PeriodFilter.last3Months:
          final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
          if (txn.createdAt.isBefore(threeMonthsAgo)) return false;
          break;
      }

      // Type filter
      final outgoing = transactionIsOutgoing(txn.transactionType);
      switch (_typeFilter) {
        case _TypeFilter.all:
          return true;
        case _TypeFilter.moneyIn:
          return !outgoing;
        case _TypeFilter.moneyOut:
          return outgoing;
      }
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _hasActiveFilters =>
      _periodFilter != _PeriodFilter.all || _typeFilter != _TypeFilter.all;

  String _periodLabel(_PeriodFilter filter) {
    switch (filter) {
      case _PeriodFilter.all:
        return 'All time';
      case _PeriodFilter.today:
        return 'Today';
      case _PeriodFilter.thisWeek:
        return 'This week';
      case _PeriodFilter.thisMonth:
        return 'This month';
      case _PeriodFilter.last3Months:
        return 'Last 3 months';
    }
  }

  String _typeLabel(_TypeFilter filter) {
    switch (filter) {
      case _TypeFilter.all:
        return 'All';
      case _TypeFilter.moneyIn:
        return 'Money in';
      case _TypeFilter.moneyOut:
        return 'Money out';
    }
  }

  Future<void> _openFilterSheet() async {
    _PeriodFilter tempPeriod = _periodFilter;
    _TypeFilter tempType = _typeFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Filter transactions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PERIOD',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _PeriodFilter.values.map((filter) {
                      final selected = tempPeriod == filter;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setSheetState(() => tempPeriod = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.teal : AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.teal
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _periodLabel(filter),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'TYPE',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _TypeFilter.values.map((filter) {
                      final selected = tempType == filter;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setSheetState(() => tempType = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.teal : AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.teal
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _typeLabel(filter),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setSheetState(() {
                              tempPeriod = _PeriodFilter.all;
                              tempType = _TypeFilter.all;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _periodFilter = tempPeriod;
                              _typeFilter = tempType;
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.tealDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

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
          'Transaction history',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: _openFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_hasActiveFilters) _buildActiveFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    )
                  : _errorMessage != null
                  ? _buildErrorState()
                  : filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: _fetchHistory,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (context, index) =>
                            _buildTransactionRow(filtered[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          if (_periodFilter != _PeriodFilter.all) ...[
            _buildFilterPill(
              _periodLabel(_periodFilter),
              () => setState(() => _periodFilter = _PeriodFilter.all),
            ),
            const SizedBox(width: 8),
          ],
          if (_typeFilter != _TypeFilter.all)
            _buildFilterPill(
              _typeLabel(_typeFilter),
              () => setState(() => _typeFilter = _TypeFilter.all),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.tealDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionResult txn) {
    final outgoing = transactionIsOutgoing(txn.transactionType);
    final sign = outgoing ? '-' : '+';
    final amountColor = outgoing ? const Color(0xFFD64545) : AppColors.teal;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transaction: txn),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.tealTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    transactionIconFor(txn.transactionType),
                    size: 19,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transactionTitleFor(txn.transactionType),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTransactionTime(txn.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(255, 108, 113, 122),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '$sign${_formatNaira(txn.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _hasActiveFilters;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                color: AppColors.teal,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isFiltered ? 'No matching transactions' : 'No transactions yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try a different filter, or reset to see everything.'
                  : 'Your deposits, transfers, and payouts will show up here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
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
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _fetchHistory, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
