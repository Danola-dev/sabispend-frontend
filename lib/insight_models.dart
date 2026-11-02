import 'api_client.dart';
import 'token_storage.dart';

enum InsightsPeriod { week, month, allTime }

String _periodToQueryParam(InsightsPeriod period) {
  switch (period) {
    case InsightsPeriod.week:
      return 'week';
    case InsightsPeriod.month:
      return 'month';
    case InsightsPeriod.allTime:
      return 'all_time';
  }
}

class CategoryBreakdownItem {
  final String label;
  final double percentage;

  CategoryBreakdownItem({required this.label, required this.percentage});

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      label: json['label'] as String,
      percentage: double.parse(json['percentage'].toString()),
    );
  }
}

class SpendingTrendPoint {
  final String label;
  final double amount;

  SpendingTrendPoint({required this.label, required this.amount});

  factory SpendingTrendPoint.fromJson(Map<String, dynamic> json) {
    return SpendingTrendPoint(
      label: json['label'] as String,
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class PayoutHistoryItem {
  final String label;
  final String timeLabel;
  final double amount;

  PayoutHistoryItem({
    required this.label,
    required this.timeLabel,
    required this.amount,
  });

  factory PayoutHistoryItem.fromJson(Map<String, dynamic> json) {
    return PayoutHistoryItem(
      label: json['label'] as String,
      timeLabel: json['time_label'] as String,
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class InsightsData {
  final double allowance;
  final double totalSpent;
  final double percentUsed;
  final String? smartInsight;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<SpendingTrendPoint> spendingTrend;
  final List<PayoutHistoryItem> payoutHistory;

  InsightsData({
    required this.allowance,
    required this.totalSpent,
    required this.percentUsed,
    this.smartInsight,
    required this.categoryBreakdown,
    required this.spendingTrend,
    required this.payoutHistory,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    return InsightsData(
      allowance: double.parse(json['allowance'].toString()),
      totalSpent: double.parse(json['total_spent'].toString()),
      percentUsed: double.parse(json['percent_used'].toString()),
      smartInsight: json['smart_insight'] as String?,
      categoryBreakdown: (json['category_breakdown'] as List)
          .map((e) => CategoryBreakdownItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      spendingTrend: (json['spending_trend'] as List)
          .map((e) => SpendingTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      payoutHistory: (json['payout_history'] as List)
          .map((e) => PayoutHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Used when the backend call fails — an empty-but-valid state rather
  /// than null, so the screen's FutureBuilder error path is the only
  /// thing that needs to handle failure, not every field access downstream.
  factory InsightsData.empty() {
    return InsightsData(
      allowance: 0,
      totalSpent: 0,
      percentUsed: 0,
      smartInsight: null,
      categoryBreakdown: [],
      spendingTrend: [],
      payoutHistory: [],
    );
  }
}

class InsightsRepository {
  Future<InsightsData> fetchInsights(InsightsPeriod period) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/transactions/insights/?period=${_periodToQueryParam(period)}',
      accessToken: token,
    );
    return InsightsData.fromJson(response);
  }
}
