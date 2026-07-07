/// Compact number display for purchase hub cards (e.g. 1.2K, 3.4M).
String formatPurchaseCompact(num value, {bool showSign = false}) {
  final n = value.toDouble().abs();
  final prefix = showSign && value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';

  String body;
  if (n >= 1000000) {
    final m = n / 1000000;
    body = m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  } else if (n >= 1000) {
    final k = n / 1000;
    body = k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  } else if (value is int || n == n.roundToDouble()) {
    body = '${n.toInt()}';
  } else {
    body = n.toStringAsFixed(1);
  }
  return '$prefix$body';
}

String formatPurchaseAedCompact(num value) => 'AED ${formatPurchaseCompact(value)}';
