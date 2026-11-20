import 'api_client.dart';
import 'token_storage.dart';

/// What a bank transfer will cost, as calculated by the server.
/// The server is the single source of truth for fees: the app only displays these numbers.
class TransferQuote {
  final double amount;
  final double
  transferFee; // our fee + 9PSB's fee, shown to the user as one number
  final double stampDuty;
  final double totalFees;
  final double totalDebit; // amount + all fees: what leaves the user's balance

  TransferQuote({
    required this.amount,
    required this.transferFee,
    required this.stampDuty,
    required this.totalFees,
    required this.totalDebit,
  });

  factory TransferQuote.fromJson(Map<String, dynamic> json) {
    double num_(String key) => double.parse(json[key].toString());
    return TransferQuote(
      amount: num_('amount'),
      transferFee: num_('transfer_fee'),
      stampDuty: num_('stamp_duty'),
      totalFees: num_('total_fees'),
      totalDebit: num_('total_debit'),
    );
  }
}

class TransferFeesApi {
  static Future<TransferQuote> getQuote(double amount) async {
    final token = await TokenStorage.getAccessToken();
    final response = await ApiClient.get(
      '/transactions/transfer/fees/?amount=${amount.toStringAsFixed(2)}',
      accessToken: token,
    );
    return TransferQuote.fromJson(response);
  }
}
