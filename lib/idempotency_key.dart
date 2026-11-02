import 'dart:math';

/// Generates a unique key for each money-moving request (Early Unlock,
/// Confirm/Edit Payout, Transfer). The backend uses this to recognize a
/// retried or double-tapped request and return the EXISTING transaction
/// instead of creating a duplicate — this is what makes those endpoints
/// safe to call more than once by accident.
///
/// A fresh key must be generated for each NEW attempt the user makes —
/// never reuse a key across two genuinely different actions.
class IdempotencyKey {
  static final Random _random = Random.secure();

  static String generate() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = List.generate(
      8,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$randomPart';
  }
}
