import 'api_client.dart';
import 'token_storage.dart';

class KYCStatus {
  final String status; // 'not_submitted' | 'otp_pending' | 'active' | 'failed'
  final String? failureReason;
  final String? maskedPhone;
  final int walletTier; // 1 = BVN only; 2 / 3 after an approved upgrade
  final bool
  ninOnFile; // true once the tier 2 upgrade has been submitted (so tier 3 needs no NIN)
  final String upgradeStatus; // 'none' | 'pending' | 'approved' | 'declined'
  final String? upgradeMessage;
  final String? dedicatedAccountNumber;
  final String? dedicatedAccountBankName;
  final String? dedicatedAccountName;

  KYCStatus({
    required this.status,
    this.failureReason,
    this.maskedPhone,
    this.walletTier = 1,
    this.ninOnFile = false,
    this.upgradeStatus = 'none',
    this.upgradeMessage,
    this.dedicatedAccountNumber,
    this.dedicatedAccountBankName,
    this.dedicatedAccountName,
  });

  factory KYCStatus.fromJson(Map<String, dynamic> json) {
    return KYCStatus(
      status: json['status'] as String,
      failureReason: json['failure_reason'] as String?,
      maskedPhone: json['masked_phone'] as String?,
      walletTier: (json['wallet_tier'] as num?)?.toInt() ?? 1,
      ninOnFile: (json['nin_on_file'] as bool?) ?? false,
      upgradeStatus: (json['upgrade_status'] as String?) ?? 'none',
      upgradeMessage: json['upgrade_message'] as String?,
      dedicatedAccountNumber: json['dedicated_account_number'] as String?,
      dedicatedAccountBankName: json['dedicated_account_bank_name'] as String?,
      dedicatedAccountName: json['dedicated_account_name'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isFailed => status == 'failed';
  bool get isOtpPending => status == 'otp_pending';
  bool get isUpgradePending => upgradeStatus == 'pending';
  bool get isUpgradeDeclined => upgradeStatus == 'declined';
}

class KYCApi {
  /// Step 1. SECURITY: the BVN travels only to YOUR backend, over the same
  /// authenticated connection as every other API call.
  ///
  /// [dateOfBirth] is sent as yyyy-MM-dd and [gender] as 'male' or 'female'.
  /// 9PSB sends a 6-digit code to the phone linked to the BVN; the result then
  /// has status 'otp_pending' and the user continues with [verifyOtp].
  static Future<KYCStatus> submitKYC({
    required String bvn,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    required String address,
  }) async {
    final token = await TokenStorage.getAccessToken();

    final response = await ApiClient.post('/kyc/submit/', {
      'bvn': bvn,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'address': address,
    }, accessToken: token);
    return KYCStatus.fromJson(response);
  }

  /// Step 2. Confirms the 6-digit code. On success the backend opens the
  /// user's 9PSB account number and the result has status 'active'.
  static Future<KYCStatus> verifyOtp({required String otp}) async {
    final token = await TokenStorage.getAccessToken();

    final response = await ApiClient.post('/kyc/verify-otp/', {
      'otp': otp,
    }, accessToken: token);
    return KYCStatus.fromJson(response);
  }

  static Future<KYCStatus> getStatus() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get('/kyc/status/', accessToken: token);
    return KYCStatus.fromJson(response);
  }
}
