import 'dart:async';
import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/transactions_api.dart';
import 'package:first_app/transfer_fees_api.dart';
import 'package:first_app/api_client.dart';
import 'transaction_pin_sheet.dart';
import 'package:first_app/money_format.dart';

enum _ResultState { none, processing, success, failed }

class SendToBankSummaryScreen extends StatefulWidget {
  final String recipientName;
  final String bank;
  final String bankCode;
  final String accountNumber;
  final double amount;
  final String? narration;
  final String idempotencyKey;

  const SendToBankSummaryScreen({
    super.key,
    required this.recipientName,
    required this.bank,
    required this.bankCode,
    required this.accountNumber,
    required this.amount,
    required this.idempotencyKey,
    this.narration,
  });

  @override
  State<SendToBankSummaryScreen> createState() =>
      _SendToBankSummaryScreenState();
}

class _SendToBankSummaryScreenState extends State<SendToBankSummaryScreen> {
  bool _isSubmitting = false;
  _ResultState _resultState = _ResultState.none;
  String? _errorMessage;
  String? _finalStatusMessage; // shown if polling times out still processing

  // Fees come from the server (GET /transactions/transfer/fees/), never calculated here,
  // so the screen can never show a different number from the one the server charges.
  TransferQuote? _quote;
  bool _isLoadingQuote = true;
  String? _quoteError;

  // Polling: re-calls initiateTransfer with the SAME idempotencyKey —
  // the backend short-circuits and just returns the transaction's
  // current state rather than reprocessing, so this is a safe way to
  // check "has the real webhook outcome arrived yet."
  static const int _maxPollAttempts = 5;
  static const Duration _pollInterval = Duration(seconds: 3);

  String _formatNaira(double amount) => formatNaira(amount);

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await TransferFeesApi.getQuote(widget.amount);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteError = e.message;
        _isLoadingQuote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoteError =
            'Couldn\'t work out the transfer fee. Check your connection and try again.';
        _isLoadingQuote = false;
      });
    }
  }

  Future<void> _handleTransfer() async {
    if (_quote == null) return;
    final pin = await showTransactionPinSheet(context);
    if (pin == null || !mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await TransactionsApi.initiateTransfer(
        accountNumber: widget.accountNumber,
        bankCode: widget.bankCode,
        resolvedAccountName: widget.recipientName,
        amount: widget.amount,
        narration: widget.narration,
        idempotencyKey: widget.idempotencyKey,
        transactionPin: pin,
      );

      if (!mounted) return;
      await _handleResult(result.status);
    } on ApiException catch (e) {
      setState(() {
        _resultState = _ResultState.failed;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _resultState = _ResultState.failed;
        _errorMessage =
            'Couldn\'t reach the server. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleResult(String status) async {
    if (status == 'finalized') {
      setState(() => _resultState = _ResultState.success);
    } else if (status == 'reversed') {
      setState(() {
        _resultState = _ResultState.failed;
        _errorMessage =
            'Your transfer didn\'t go through and has been refunded to your balance.';
      });
    } else if (status == 'processing') {
      setState(() => _resultState = _ResultState.processing);
      await _pollForOutcome();
    } else {
      setState(() {
        _resultState = _ResultState.failed;
        _errorMessage = 'Unexpected transfer status: $status';
      });
    }
  }

  Future<void> _pollForOutcome() async {
    for (int attempt = 0; attempt < _maxPollAttempts; attempt++) {
      await Future.delayed(_pollInterval);
      if (!mounted) return;

      try {
        // Read-only status check — no PIN needed, this never touches
        // money or re-authorizes anything.
        final currentStatus = await TransactionsApi.getTransferStatus(
          widget.idempotencyKey,
        );

        if (!mounted) return;

        if (currentStatus == 'finalized') {
          setState(() => _resultState = _ResultState.success);
          return;
        } else if (currentStatus == 'reversed') {
          setState(() {
            _resultState = _ResultState.failed;
            _errorMessage =
                'Your transfer didn\'t go through and has been refunded to your balance.';
          });
          return;
        }
        // still 'processing' — loop continues
      } catch (_) {
        // A poll attempt failing is not itself a transfer failure —
        // just try again next interval rather than jumping to "failed."
      }
    }

    // Timed out still processing — genuinely unresolved, not a failure.
    if (mounted) {
      setState(() {
        _finalStatusMessage =
            'Still processing — this can take a few minutes. Check your transaction history for the final status.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResultScreen = _resultState != _ResultState.none;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !isResultScreen,
        leading: isResultScreen
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Text(
          _titleFor(_resultState),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: isResultScreen ? _buildResultView() : _buildReviewView(),
      ),
    );
  }

  String _titleFor(_ResultState state) {
    switch (state) {
      case _ResultState.success:
        return 'Transfer successful';
      case _ResultState.failed:
        return 'Transfer failed';
      case _ResultState.processing:
        return 'Processing';
      case _ResultState.none:
        return 'Review transfer';
    }
  }

  // ============ REVIEW STATE ============

  Widget _buildReviewView() {
    final quote = _quote;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.tealTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: AppColors.teal,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatNaira(widget.amount),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'To',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 62, 66, 71),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],
          if (_quoteError != null) ...[
            _buildQuoteErrorBanner(_quoteError!),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _summaryRow('Recipient:', widget.recipientName),
                const Divider(height: 1, color: AppColors.border),
                _summaryRow('Bank', widget.bank),
                const Divider(height: 1, color: AppColors.border),
                _summaryRow('Account number', widget.accountNumber),
                const Divider(height: 1, color: AppColors.border),
                _summaryRow('Amount', _formatNaira(widget.amount)),
                if (quote != null) ...[
                  _summaryRow('Transfer fee', _formatNaira(quote.transferFee)),
                  if (quote.stampDuty > 0) ...[
                    const Divider(height: 1, color: AppColors.border),
                    _summaryRow('Stamp Duty', _formatNaira(quote.stampDuty)),
                  ],
                  const Divider(height: 1, color: AppColors.border),
                  _summaryRow('Total Debit', _formatNaira(quote.totalDebit)),
                ] else if (_isLoadingQuote) ...[
                  _summaryRow('Fees', 'Calculating…'),
                ],
                if (widget.narration != null) ...[
                  const Divider(height: 1, color: AppColors.border),
                  _summaryRow('Narration', widget.narration!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildTransferButton(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFD64545)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFD64545),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFD64545)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFD64545),
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: _loadQuote, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 81, 86, 91),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferButton() {
    // Only enabled once the server has told us the exact fee, so the user always sees the real total.
    final enabled = !_isSubmitting && _quote != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? _handleTransfer : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled || _isSubmitting
              ? AppColors.tealDark
              : AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
      ),
    );
  }

  // ============ RESULT STATES (success / failed / processing) ============

  Widget _buildResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultIcon(),
            const SizedBox(height: 20),
            Text(
              _resultHeadline(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _resultSubtext(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            if (_resultState == _ResultState.processing &&
                _finalStatusMessage == null)
              const CircularProgressIndicator(color: AppColors.teal)
            else
              _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultIcon() {
    Color bg;
    IconData icon;
    Color iconColor;

    switch (_resultState) {
      case _ResultState.success:
        bg = AppColors.tealTint;
        icon = Icons.check_circle;
        iconColor = AppColors.teal;
        break;
      case _ResultState.failed:
        bg = const Color(0xFFFDECEC);
        icon = Icons.close_rounded;
        iconColor = const Color(0xFFD64545);
        break;
      default:
        bg = const Color(0xFFFFF6E0);
        icon = Icons.hourglass_top_rounded;
        iconColor = const Color(0xFFB8860B);
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 36),
    );
  }

  String _resultHeadline() {
    switch (_resultState) {
      case _ResultState.success:
        return 'Transfer successful';
      case _ResultState.failed:
        return 'Transfer failed';
      default:
        return _finalStatusMessage != null
            ? 'Still processing'
            : 'Processing your transfer';
    }
  }

  String _resultSubtext() {
    switch (_resultState) {
      case _ResultState.success:
        return '${_formatNaira(widget.amount)} was sent to ${widget.recipientName}.';
      case _ResultState.failed:
        return _errorMessage ?? 'Something went wrong with this transfer.';
      default:
        return _finalStatusMessage ??
            'Hang tight — confirming this with your bank.';
    }
  }

  Widget _buildCloseButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.tealDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Close',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
