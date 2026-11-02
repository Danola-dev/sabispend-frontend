import 'api_client.dart';
import 'token_storage.dart';

class BillVariation {
  final String code;
  final String name;
  final double amount;
  final bool isFixedPrice;

  BillVariation({
    required this.code,
    required this.name,
    required this.amount,
    required this.isFixedPrice,
  });

  factory BillVariation.fromJson(Map<String, dynamic> json) {
    return BillVariation(
      code: json['variation_code'] as String,
      name: json['name'] as String,
      amount: double.tryParse(json['variation_amount'].toString()) ?? 0,
      isFixedPrice: (json['fixedPrice'] as String?)?.toLowerCase() == 'yes',
    );
  }
}

class MerchantVerification {
  final String customerName;

  MerchantVerification({required this.customerName});

  factory MerchantVerification.fromJson(Map<String, dynamic> json) {
    return MerchantVerification(
      customerName:
          (json['Customer_Name'] ?? json['customerName'] ?? json['name'] ?? '')
              as String,
    );
  }
}

class BillPaymentResult {
  final int id;
  final String billType;
  final String status;
  final double amount;
  final double commissionAmount;
  final double totalAmount;
  final String? customerName;
  final String? failureReason;
  final String? purchasedCode;

  BillPaymentResult({
    required this.id,
    required this.billType,
    required this.status,
    required this.amount,
    required this.commissionAmount,
    required this.totalAmount,
    this.customerName,
    this.failureReason,
    this.purchasedCode,
  });

  factory BillPaymentResult.fromJson(Map<String, dynamic> json) {
    return BillPaymentResult(
      id: json['id'] as int,
      billType: json['bill_type'] as String,
      status: json['status'] as String,
      amount: double.parse(json['amount'].toString()),
      commissionAmount: double.parse(
        (json['commission_amount'] ?? '0').toString(),
      ),
      totalAmount: double.parse(
        (json['total_amount'] ?? json['amount']).toString(),
      ),
      customerName: json['customer_name'] as String?,
      failureReason: json['failure_reason'] as String?,
      purchasedCode: json['purchased_code'] as String?,
    );
  }

  bool get isSuccessful => status == 'finalized';
  bool get isPending => status == 'processing';
}

class BillBeneficiary {
  final int id;
  final String billType;
  final String serviceId;
  final String billerName;
  final String billersCode;
  final String customerName;

  BillBeneficiary({
    required this.id,
    required this.billType,
    required this.serviceId,
    required this.billerName,
    required this.billersCode,
    required this.customerName,
  });

  factory BillBeneficiary.fromJson(Map<String, dynamic> json) {
    return BillBeneficiary(
      id: json['id'] as int,
      billType: json['bill_type'] as String,
      serviceId: json['service_id'] as String,
      billerName: json['biller_name'] as String,
      billersCode: json['billers_code'] as String,
      customerName: json['customer_name'] as String,
    );
  }
}

class BillsApi {
  static Future<List<BillVariation>> getVariations(String serviceId) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/bills/variations/?service_id=$serviceId',
      accessToken: token,
    );
    final variations = (response['variations'] as List<dynamic>? ?? []);
    return variations
        .map((v) => BillVariation.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  static Future<MerchantVerification> verifyMerchant({
    required String serviceId,
    required String billersCode,
    String? serviceType,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/bills/verify/', {
      'service_id': serviceId,
      'billers_code': billersCode,
      if (serviceType != null) 'service_type': serviceType,
    }, accessToken: token);
    return MerchantVerification.fromJson(response);
  }

  static Future<BillPaymentResult> payBill({
    required String billType,
    required String serviceId,
    required String billerName,
    required double amount,
    required String phone,
    String? billersCode,
    String? variationCode,
    String? customerName,
    required String transactionPin,
    required String idempotencyKey,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.post('/bills/pay/', {
      'bill_type': billType,
      'service_id': serviceId,
      'biller_name': billerName,
      'amount': amount.toStringAsFixed(2),
      'phone': phone,
      if (billersCode != null) 'billers_code': billersCode,
      if (variationCode != null) 'variation_code': variationCode,
      if (customerName != null) 'customer_name': customerName,
      'transaction_pin': transactionPin,
      'idempotency_key': idempotencyKey,
    }, accessToken: token);
    return BillPaymentResult.fromJson(response);
  }

  static Future<List<BillBeneficiary>> getBeneficiaries(String billType) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.getList(
      '/bills/beneficiaries/?bill_type=$billType',
      accessToken: token,
    );
    return response
        .map((b) => BillBeneficiary.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveBeneficiary({
    required String billType,
    required String serviceId,
    required String billerName,
    required String billersCode,
    required String customerName,
  }) async {
    final token = await TokenStorage.getAccessToken();
    await ApiClient.post('/bills/beneficiaries/create/', {
      'bill_type': billType,
      'service_id': serviceId,
      'biller_name': billerName,
      'billers_code': billersCode,
      'customer_name': customerName,
    }, accessToken: token);
  }
}
