import 'package:intl/intl.dart';

/// Full money display for Purchase Management (no K/M abbreviation).
String formatPurchaseAed(num value, {String currency = 'AED'}) {
  final n = value.toDouble();
  final formatted = n % 1 == 0
      ? NumberFormat('#,##0', 'en_US').format(n)
      : NumberFormat('#,##0.##', 'en_US').format(n);
  final prefix = currency.trim();
  if (prefix.isEmpty) return formatted;
  return '$prefix $formatted';
}

/// Integer / count display without K/M abbreviation.
String formatPurchaseCompact(num value, {bool showSign = false}) {
  final n = value.toDouble().abs();
  final prefix = showSign && value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';

  final body = (value is int || n == n.roundToDouble())
      ? NumberFormat('#,##0', 'en_US').format(n)
      : NumberFormat('#,##0.##', 'en_US').format(n);
  return '$prefix$body';
}

String formatPurchaseAedCompact(num value) => formatPurchaseAed(value);
