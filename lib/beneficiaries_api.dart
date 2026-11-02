import 'api_client.dart';
import 'token_storage.dart';

class BeneficiaryData {
  final int id;
  final String accountName;
  final String accountNumber;
  final String bankName;
  final String? bankCode;

  BeneficiaryData({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
    this.bankCode,
  });

  factory BeneficiaryData.fromJson(Map<String, dynamic> json) {
    return BeneficiaryData(
      id: json['id'] as int,
      accountName: json['account_name'] as String,
      accountNumber: json['account_number'] as String,
      bankName: json['bank_name'] as String,
      bankCode: json['bank_code'] as String?,
    );
  }
}

class BeneficiariesApi {
  static Future<List<BeneficiaryData>> getAll() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/beneficiaries/',
      accessToken: token,
    );
    return response
        .map((json) => BeneficiaryData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<BeneficiaryData> create({
    required String accountName,
    required String accountNumber,
    required String bankName,
    String? bankCode,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/beneficiaries/', {
      'account_name': accountName,
      'account_number': accountNumber,
      'bank_name': bankName,
      if (bankCode != null) 'bank_code': bankCode,
    }, accessToken: token);
    return BeneficiaryData.fromJson(response);
  }

  static Future<void> delete(int id) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.delete('/beneficiaries/$id/', accessToken: token);
  }
}
