import 'api_client.dart';
import 'token_storage.dart';

class KYCStatus {
  final String status; // 'not_submitted' | 'active' | 'failed'
  final String? failureReason;
  final String? dedicatedAccountNumber;
  final String? dedicatedAccountBankName;
  final String? dedicatedAccountName;

  KYCStatus({
    required this.status,
    this.failureReason,
    this.dedicatedAccountNumber,
    this.dedicatedAccountBankName,
    this.dedicatedAccountName,
  });

  factory KYCStatus.fromJson(Map<String, dynamic> json) {
    return KYCStatus(
      status: json['status'] as String,
      failureReason: json['failure_reason'] as String?,
      dedicatedAccountNumber: json['dedicated_account_number'] as String?,
      dedicatedAccountBankName: json['dedicated_account_bank_name'] as String?,
      dedicatedAccountName: json['dedicated_account_name'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isFailed => status == 'failed';
}

class KYCApi {
  /// SECURITY: the BVN travels only to YOUR backend, over the same
  /// authenticated connection as every other API call.
  static Future<KYCStatus> submitKYC({
    required String bvn,
    required String firstName,
    required String lastName,
  }) async {
    final token = await TokenStorage.getAccessToken();

    final response = await ApiClient.post('/kyc/submit/', {
      'bvn': bvn,
      'first_name': firstName,
      'last_name': lastName,
    }, accessToken: token);
    return KYCStatus.fromJson(response);
  }

  static Future<KYCStatus> getStatus() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get('/kyc/status/', accessToken: token);
    return KYCStatus.fromJson(response);
  }
}
