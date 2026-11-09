import 'package:first_app/screens/payout_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/insight_models.dart';
import 'package:first_app/money_format.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final InsightsRepository _repository = InsightsRepository();

  InsightsPeriod _selectedPeriod = InsightsPeriod.week;
  late Future<InsightsData> _insightsFuture;

  // Distinct colors per category — kept stable so a category always maps
  // to the same color even as real data changes the underlying numbers.
  static const List<Color> _categoryColors = [
    AppColors.tealDark,
    AppColors.teal,
    Color(0xFF90CAF9),
    AppColors.tealTint,
  ];

  @override
  void initState() {
    super.initState();
    _insightsFuture = _repository.fetchInsights(_selectedPeriod);
  }

  void _onPeriodSelected(InsightsPeriod period) {
    if (period == _selectedPeriod) return;
    setState(() {
      _selectedPeriod = period;
      // Re-fetching (rather than filtering client-side) is deliberate: once
      // there's a real backend, each period is likely its own query/endpoint.
      _insightsFuture = _repository.fetchInsights(period);
    });
  }

  String _formatNaira(double amount) => formatNaira(amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insights',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildPeriodSelector(),
              const SizedBox(height: 20),
              FutureBuilder<InsightsData>(
                future: _insightsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.teal),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'Couldn\'t load insights right now.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCard(data),
                      if (data.smartInsight != null) ...[
                        const SizedBox(height: 16),
                        _buildSmartInsightBanner(data.smartInsight!),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Where your money went',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryBreakdown(data),
                      const SizedBox(height: 28),
                      const Text(
                        'Spending trend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTrendChart(data),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 16),
                      _buildPayoutHistory(data),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final labels = {
      InsightsPeriod.week: 'Week',
      InsightsPeriod.month: 'Month',
      InsightsPeriod.allTime: 'All time',
    };

    return Row(
      children: InsightsPeriod.values.map((period) {
        final selected = period == _selectedPeriod;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _onPeriodSelected(period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.tealTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[period]!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.teal : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverviewCard(InsightsData data) {
    final periodLabel = {
      InsightsPeriod.week: 'this week',
      InsightsPeriod.month: 'this month',
      InsightsPeriod.allTime: 'all time',
    }[_selectedPeriod]!;

    final percentUsed = (data.percentUsed * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent $periodLabel',
                style: const TextStyle(
                  fontSize: 16.5,
                  color: Color.fromARGB(255, 9, 10, 11),
                ),
              ),
              Text(
                'of ${_formatNaira(data.allowance)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromRGBO(9, 10, 11, 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatNaira(data.totalSpent),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: data.percentUsed,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$percentUsed% of allowance used',
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 24, 26, 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsightBanner(String insight) {
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
          const Icon(Icons.lightbulb_outline, size: 21, color: AppColors.teal),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(
                fontSize: 15,
                color: Color.fromARGB(255, 6, 10, 17),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(InsightsData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(data.categoryBreakdown.length, (i) {
                final category = data.categoryBreakdown[i];
                return PieChartSectionData(
                  value: category.percentage,
                  color: _categoryColors[i % _categoryColors.length],
                  radius: 18,
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: List.generate(data.categoryBreakdown.length, (i) {
              final category = data.categoryBreakdown[i];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == data.categoryBreakdown.length - 1 ? 0 : 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _categoryColors[i % _categoryColors.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.label,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color.fromARGB(255, 41, 43, 46),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${category.percentage.round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(InsightsData data) {
    final maxAmount = data.spendingTrend
        .map((p) => p.amount)
        .reduce((a, b) => a > b ? a : b);
    final latestIndex = data.spendingTrend.length - 1;

    return SizedBox(
      height: 110,
      child: BarChart(
        BarChartData(
          maxY: maxAmount * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.spendingTrend.length) {
                    return const SizedBox.shrink();
                  }
                  final isLatest = index == latestIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data.spendingTrend[index].label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLatest ? AppColors.teal : AppColors.textMuted,
                        fontWeight: isLatest
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.tealDark,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  _formatNaira(rod.toY),
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(data.spendingTrend.length, (i) {
            final isLatest = i == latestIndex;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data.spendingTrend[i].amount,
                  color: isLatest ? AppColors.teal : AppColors.border,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPayoutHistory(InsightsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payout history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
              ),
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...data.payoutHistory.map((payout) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payout.label,
                      style: const TextStyle(
                        fontSize: 16.5,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      payout.timeLabel,
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
        }),
      ],
    );
  }
}
