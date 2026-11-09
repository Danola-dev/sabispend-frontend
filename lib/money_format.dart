/// One place for every naira amount in the app.
/// 1234.5 -> ₦1,234.50   |   100 -> ₦100.00   |   -50 -> -₦50.00
String formatNaira(num amount) {
  final isNegative = amount < 0;
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i != 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${isNegative ? '-' : ''}₦$buffer.${parts[1]}';
}
