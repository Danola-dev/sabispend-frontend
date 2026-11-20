import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'kyc_api.dart';
import 'token_storage.dart';

/// Thrown when an upgrade request is rejected. [message] is safe to show the user.
class UpgradeException implements Exception {
  final String message;
  UpgradeException(this.message);

  @override
  String toString() => message;
}

/// Live tier and limits from 9PSB (the backend never hard-codes them).
class WalletLimits {
  final int walletTier;
  final String? maximumBalance;
  final String? maximumDeposit;

  WalletLimits({
    required this.walletTier,
    this.maximumBalance,
    this.maximumDeposit,
  });

  factory WalletLimits.fromJson(Map<String, dynamic> json) {
    return WalletLimits(
      walletTier: (json['wallet_tier'] as num?)?.toInt() ?? 1,
      maximumBalance: json['maximum_balance']?.toString(),
      maximumDeposit: json['maximum_deposit']?.toString(),
    );
  }
}

class KYCUpgradeApi {
  /// Tier 1 -> 2.
  ///
  /// [fields]: nin, id_issue_date (yyyy-MM-dd), pep ('YES'/'NO'), house_number, street_name, city,
  /// state, local_government, nearest_landmark.
  /// [filePaths]: user_photo, customer_signature, id_card_front, utility_bill (all four required).
  static Future<KYCStatus> submitUpgrade({
    required Map<String, String> fields,
    required Map<String, String> filePaths,
  }) {
    return _postMultipart('/kyc/upgrade/', fields, filePaths);
  }

  /// Tier 2 -> 3: one proof-of-address photo. [nin] is only needed when the account has no NIN on
  /// file (see KYCStatus.ninOnFile).
  static Future<KYCStatus> submitTier3({
    String nin = '',
    required String proofOfAddressPath,
  }) {
    return _postMultipart(
      '/kyc/upgrade/tier3/',
      {if (nin.isNotEmpty) 'nin': nin},
      {'proof_of_address': proofOfAddressPath},
    );
  }

  /// Also asks 9PSB where a pending upgrade stands (safety net if a notification was missed).
  static Future<KYCStatus> refreshStatus() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/kyc/upgrade/status/',
      accessToken: token,
    );
    return KYCStatus.fromJson(response);
  }

  static Future<WalletLimits> getLimits() async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get('/kyc/limits/', accessToken: token);
    return WalletLimits.fromJson(response);
  }

  // Multipart upload. Uses package:http directly because a file upload cannot go through a
  // JSON-only client.  NOTE: [ApiClient.baseUrl] must be your API root (the same one ApiClient
  // uses for '/kyc/submit/'); if yours is named differently, change that one reference below.
  static Future<KYCStatus> _postMultipart(
    String path,
    Map<String, String> fields,
    Map<String, String> filePaths,
  ) async {
    // A normal call first: if ApiClient refreshes an expired access token, this triggers it, so
    // the token read below is fresh. (Access tokens last only 10 minutes and a form takes a while.)
    await KYCApi.getStatus();
    final token = await TokenStorage.getAccessToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}$path'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    for (final entry in filePaths.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return KYCStatus.fromJson(body);
      }
      throw UpgradeException(_errorMessage(body, response.statusCode));
    } on TimeoutException {
      throw UpgradeException(
        'The upload took too long. Check your connection and try again.',
      );
    } on UpgradeException {
      rethrow;
    } catch (_) {
      throw UpgradeException(
        'Couldn\'t reach the server. Check your connection and try again.',
      );
    }
  }

  static String _errorMessage(Map<String, dynamic> body, int status) {
    final error = body['error'];
    if (error is String && error.isNotEmpty) return error;
    if (status == 413) {
      return 'Your photos are too large. Use smaller photos and try again.';
    }
    if (status == 429) return 'Too many attempts. Please wait a minute.';
    // Field validation errors: {"field": ["message"]}
    for (final value in body.values) {
      if (value is List && value.isNotEmpty && value.first is String) {
        return value.first as String;
      }
      if (value is String && value.isNotEmpty) return value;
    }
    return 'Something went wrong. Please check your details and try again.';
  }
}
