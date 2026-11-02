import 'api_client.dart';
import 'token_storage.dart';

class TransactionResult {
  final String id;
  final String transactionType;
  final String status;
  final double amount;
  final double feeAmount;
  final double paystackFeePassthrough;
  final double stampDutyAmount;
  final String? failureReason;
  final String? narration;
  final String? recipientName;
  final String? recipientAccountNumber;
  final DateTime createdAt;

  TransactionResult({
    required this.id,
    required this.transactionType,
    required this.status,
    required this.amount,
    required this.feeAmount,
    required this.paystackFeePassthrough,
    required this.stampDutyAmount,
    this.failureReason,
    this.narration,
    this.recipientName,
    this.recipientAccountNumber,
    required this.createdAt,
  });

  double get totalDeducted =>
      amount + feeAmount + paystackFeePassthrough + stampDutyAmount;

  factory TransactionResult.fromJson(Map<String, dynamic> json) {
    // narration/recipient details live inside metadata, not as
    // top-level fields — set by transactions/services.py's
    // initiate_transfer when it creates the Transaction.
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    return TransactionResult(
      id: json['id'] as String,
      transactionType: json['transaction_type'] as String,
      status: json['status'] as String,
      amount: double.parse(json['amount'].toString()),
      feeAmount: double.parse((json['fee_amount'] ?? '0').toString()),
      paystackFeePassthrough: double.parse(
        (json['paystack_fee_passthrough'] ?? '0').toString(),
      ),
      stampDutyAmount: double.parse(
        (json['stamp_duty_amount'] ?? '0').toString(),
      ),
      failureReason: metadata['note'] as String?,
      narration: metadata['narration'] as String?,
      recipientName: metadata['resolved_account_name'] as String?,
      recipientAccountNumber: metadata['account_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PayoutReadiness {
  final bool ready;
  final double? releaseAmount;
  final String? currentFrequency;
  final double? currentAmountPerPayout;
  final DateTime? nextEditableDate;

  PayoutReadiness({
    required this.ready,
    this.releaseAmount,
    this.currentFrequency,
    this.currentAmountPerPayout,
    this.nextEditableDate,
  });

  factory PayoutReadiness.fromJson(Map<String, dynamic> json) {
    return PayoutReadiness(
      ready: json['ready'] as bool,
      releaseAmount: json['release_amount'] != null
          ? double.parse(json['release_amount'].toString())
          : null,
      currentFrequency: json['current_frequency'] as String?,
      currentAmountPerPayout: json['current_amount_per_payout'] != null
          ? double.parse(json['current_amount_per_payout'].toString())
          : null,
      nextEditableDate: json['next_editable_date'] != null
          ? DateTime.parse(json['next_editable_date'] as String)
          : null,
    );
  }
}

class TransactionsApi {
  static Future<TransactionResult> earlyUnlock({
    required double amount,
    required String idempotencyKey,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/transactions/early-unlock/', {
      'amount': amount.toStringAsFixed(2),
      'idempotency_key': idempotencyKey,
    }, accessToken: token);
    return TransactionResult.fromJson(response);
  }

  static Future<TransactionResult> confirmOrEditPayout({
    required String frequency,
    required double amountPerPayout,
    required String idempotencyKey,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response =
        await ApiClient.post('/transactions/payout/confirm-or-edit/', {
          'frequency': frequency,
          'amount_per_payout': amountPerPayout.toStringAsFixed(2),
          'idempotency_key': idempotencyKey,
        }, accessToken: token);
    return TransactionResult.fromJson(response);
  }

  static Future<TransactionResult> initiateTransfer({
    required String accountNumber,
    required String bankCode,
    required String resolvedAccountName,
    required double amount,
    String? narration,
    required String idempotencyKey,
    required String transactionPin,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/transactions/transfer/', {
      'account_number': accountNumber,
      'bank_code': bankCode,
      'resolved_account_name': resolvedAccountName,
      'amount': amount.toStringAsFixed(2),
      if (narration != null && narration.isNotEmpty) 'narration': narration,
      'idempotency_key': idempotencyKey,
      'transaction_pin': transactionPin,
    }, accessToken: token);
    return TransactionResult.fromJson(response);
  }

  static Future<PayoutReadiness> getPayoutReadiness() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/transactions/payout/readiness/',
      accessToken: token,
    );
    return PayoutReadiness.fromJson(response);
  }

  /// Every kind of money movement — deposits, transfers, bill payments,
  /// early unlocks, payout releases — comes back in one list, newest
  /// first (the backend already orders by -created_at).
  static Future<List<TransactionResult>> getHistory() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/transactions/history/',
      accessToken: token,
    );
    return response
        .map((json) => TransactionResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<String> getTransferStatus(String idempotencyKey) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/transactions/transfer/status/?idempotency_key=$idempotencyKey',
      accessToken: token,
    );
    return response['status'] as String;
  }

  // Add this method inside your existing TransactionsApi class:
  static Future<List<PayoutHistoryEntry>> getPayoutHistory() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/transactions/payout-history/',
      accessToken: token,
    );
    return response
        .map((e) => PayoutHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<BankData>> getBankList() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/transactions/banks/',
      accessToken: token,
    );
    return response
        .map((json) => BankData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<ResolvedAccount> resolveAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/transactions/banks/resolve/?account_number=$accountNumber&bank_code=$bankCode',
      accessToken: token,
    );
    return ResolvedAccount.fromJson(response);
  }
}

class BankData {
  final String name;
  final String code;

  BankData({required this.name, required this.code});

  factory BankData.fromJson(Map<String, dynamic> json) {
    return BankData(name: json['name'] as String, code: json['code'] as String);
  }
}

class ResolvedAccount {
  final String accountNumber;
  final String accountName;

  ResolvedAccount({required this.accountNumber, required this.accountName});

  factory ResolvedAccount.fromJson(Map<String, dynamic> json) {
    return ResolvedAccount(
      accountNumber: json['account_number'] as String,
      accountName: json['account_name'] as String,
    );
  }
}

class PayoutHistoryEntry {
  final double amount;
  final DateTime createdAt;

  PayoutHistoryEntry({required this.amount, required this.createdAt});

  factory PayoutHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PayoutHistoryEntry(
      amount: double.parse(json['amount'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
