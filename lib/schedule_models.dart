/// Data models for the Schedule / payout plan screen.
///
/// One unified plan model for everyone — no separate "irregular income"
/// type. If a user's income is irregular, they still just pick a
/// frequency + amount like anyone else; running low before the next
/// payout is handled by Early Unlock (withdraw from next payout),
/// not by editing the plan mid-cycle.
library;

enum PayoutFrequency { daily, weekly, biweekly, monthly }

extension PayoutFrequencyLabel on PayoutFrequency {
  String get label {
    switch (this) {
      case PayoutFrequency.daily:
        return 'Daily';
      case PayoutFrequency.weekly:
        return 'Weekly';
      case PayoutFrequency.biweekly:
        return 'Biweekly';
      case PayoutFrequency.monthly:
        return 'Monthly';
    }
  }

  /// Days between payouts — defines how long a plan stays locked before
  /// it becomes editable again.
  int get days {
    switch (this) {
      case PayoutFrequency.daily:
        return 1;
      case PayoutFrequency.weekly:
        return 7;
      case PayoutFrequency.biweekly:
        return 14;
      case PayoutFrequency.monthly:
        return 30;
    }
  }
}

class PayoutPlan {
  final PayoutFrequency frequency;
  final double amountPerPayout;
  final DateTime activeSince;

  const PayoutPlan({
    required this.frequency,
    required this.amountPerPayout,
    required this.activeSince,
  });

  /// The plan is locked from [activeSince] until this date — the start of
  /// the next payout cycle, which is the only point it can be edited.
  DateTime get nextEditableDate =>
      activeSince.add(Duration(days: frequency.days));

  bool get isEditable =>
      DateTime.now().isAfter(nextEditableDate) ||
      DateTime.now().isAtSameMomentAs(nextEditableDate);

  PayoutPlan withNewCycle({
    required PayoutFrequency frequency,
    required double amountPerPayout,
  }) {
    return PayoutPlan(
      frequency: frequency,
      amountPerPayout: amountPerPayout,
      activeSince: DateTime.now(),
    );
  }
}

/// One entry in the plan history list — a snapshot of a plan that was
/// active for some date range.
class PlanHistoryEntry {
  final String summaryLabel; // e.g. "Weekly · ₦45,000"
  final DateTime startDate;
  final DateTime endDate;

  const PlanHistoryEntry({
    required this.summaryLabel,
    required this.startDate,
    required this.endDate,
  });
}
