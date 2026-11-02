import 'api_client.dart';
import 'token_storage.dart';

class WalletData {
  final double lockedBalance;
  final double spendableBalance;
  final PayoutPlanData? currentPlan;

  WalletData({
    required this.lockedBalance,
    required this.spendableBalance,
    this.currentPlan,
  });

  factory WalletData.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>;
    final planJson = json['current_plan'] as Map<String, dynamic>?;

    return WalletData(
      lockedBalance: double.parse(wallet['locked_balance'].toString()),
      spendableBalance: double.parse(wallet['spendable_balance'].toString()),
      currentPlan: planJson != null ? PayoutPlanData.fromJson(planJson) : null,
    );
  }
}

class PayoutPlanData {
  final String frequency; // 'daily' | 'weekly' | 'biweekly' | 'monthly'
  final double amountPerPayout;
  final DateTime startDate;
  final DateTime? endDate; // null = this is the current plan; set = a past one
  final DateTime nextEditableDate;
  final bool isEditable;

  PayoutPlanData({
    required this.frequency,
    required this.amountPerPayout,
    required this.startDate,
    this.endDate,
    required this.nextEditableDate,
    required this.isEditable,
  });

  factory PayoutPlanData.fromJson(Map<String, dynamic> json) {
    return PayoutPlanData(
      frequency: json['frequency'] as String,
      amountPerPayout: double.parse(json['amount_per_payout'].toString()),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      nextEditableDate: DateTime.parse(json['next_editable_date'] as String),
      isEditable: json['is_editable'] as bool,
    );
  }
}

class WalletApi {
  static Future<WalletData> getWallet() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get('/wallet/', accessToken: token);
    return WalletData.fromJson(response);
  }

  /// Throws ApiException with a 403 status specifically when the plan is
  /// still locked — the caller (Schedule screen) should surface e.message
  /// directly, since the backend's message already explains why.
  static Future<PayoutPlanData> setPayoutPlan({
    required String frequency,
    required double amountPerPayout,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/wallet/payout-plan/', {
      'frequency': frequency,
      'amount_per_payout': amountPerPayout.toStringAsFixed(2),
    }, accessToken: token);
    return PayoutPlanData.fromJson(response);
  }

  /// Past plans only (end_date is set on all of these) — the current
  /// plan comes from getWallet() instead.
  static Future<List<PayoutPlanData>> getPayoutPlanHistory() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/wallet/payout-plan/history/',
      accessToken: token,
    );
    return response
        .map((json) => PayoutPlanData.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
