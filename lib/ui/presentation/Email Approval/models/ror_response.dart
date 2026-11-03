int _readIntFromKeys(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

/// ROR response from /api/my_delayed_approvals/ror
class RorResponse {
  final int? hrCount;
  final int? rfqCount;
  final int? invoiceCount;
  final int? pettyCashCount;
  final int rorPercentage;

  // Per-category ROR percentages (from new API shape)
  final int? hrRor;
  final int? rfqRor;
  final int? invoiceRor;
  final int? pettyCashRor;

  const RorResponse({
    required this.hrCount,
    required this.rfqCount,
    required this.invoiceCount,
    required this.pettyCashCount,
    required this.rorPercentage,
    this.hrRor,
    this.rfqRor,
    this.invoiceRor,
    this.pettyCashRor,
  });

  factory RorResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    final data = result is Map<String, dynamic>
        ? (result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : result)
        : <String, dynamic>{};

    final rorNode = data['ror'];
    // New API shape: ror is a map {overall, hr, rfq, invoice, petty_cash}
    final rorIsObject = rorNode is Map<String, dynamic>;
    final rorMap = rorIsObject
        ? rorNode
        : (data['response_rate'] is Map<String, dynamic>
            ? data['response_rate'] as Map<String, dynamic>
            : <String, dynamic>{});

    final countersNode = data['counters'];
    final countersMap = countersNode is Map<String, dynamic>
        ? countersNode
        : (data['counts'] is Map<String, dynamic>
            ? data['counts'] as Map<String, dynamic>
            : data);

    final hasCounters = _hasAnyKey(countersMap, const [
      'hr',
      'human_resources',
      'hr_count',
      'rfq',
      'rfqs',
      'rfq_count',
      'invoice',
      'invoices',
      'invoice_count',
      'invoices_count',
      'petty_cash',
      'pettycash',
      'petty_cash_count',
      'pettycash_count',
    ]);

    final hrCount = _readIntFromKeys(countersMap, [
      'hr',
      'human_resources',
      'hr_count',
    ]);
    final rfqCount = _readIntFromKeys(countersMap, [
      'rfq',
      'rfqs',
      'rfq_count',
    ]);
    final invoiceCount = _readIntFromKeys(countersMap, [
      'invoice',
      'invoices',
      'invoice_count',
      'invoices_count',
    ]);
    final pettyCashCount = _readIntFromKeys(countersMap, [
      'petty_cash',
      'pettycash',
      'petty_cash_count',
      'pettycash_count',
    ]);

    // Per-category ROR from new API shape
    final hrRor = rorIsObject ? _decimalKeyToPercent(rorMap, 'hr') : null;
    final rfqRor = rorIsObject ? _decimalKeyToPercent(rorMap, 'rfq') : null;
    final invoiceRor =
        rorIsObject ? _decimalKeyToPercent(rorMap, 'invoice') : null;
    final pettyCashRor =
        rorIsObject ? _decimalKeyToPercent(rorMap, 'petty_cash') : null;

    final rorPercentage = rorIsObject
        ? (_decimalKeyToPercent(rorMap, 'overall') ??
            _deriveOverallRor(
              hrRor: hrRor,
              rfqRor: rfqRor,
              invoiceRor: invoiceRor,
              pettyCashRor: pettyCashRor,
              hrCount: hasCounters ? hrCount : null,
              rfqCount: hasCounters ? rfqCount : null,
              invoiceCount: hasCounters ? invoiceCount : null,
              pettyCashCount: hasCounters ? pettyCashCount : null,
            ))
        : _readRorPercentage(rorMap, data);

    return RorResponse(
      hrCount: hasCounters ? hrCount : null,
      rfqCount: hasCounters ? rfqCount : null,
      invoiceCount: hasCounters ? invoiceCount : null,
      pettyCashCount: hasCounters ? pettyCashCount : null,
      rorPercentage: rorPercentage ?? 0,
      hrRor: hrRor,
      rfqRor: rfqRor,
      invoiceRor: invoiceRor,
      pettyCashRor: pettyCashRor,
    );
  }
}

bool _hasAnyKey(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source.containsKey(key) && source[key] != null) {
      return true;
    }
  }
  return false;
}

/// Reads a key from [map] and converts its decimal value to an integer
/// percentage. Values <= 1.5 are treated as ratios (0.26 → 26).
int? _decimalKeyToPercent(Map<String, dynamic> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim().replaceAll('%', ''));
  }
  if (value == null) return null;
  if (value <= 1.5) value = value * 100;
  return value.round().clamp(0, 100);
}

int _readRorPercentage(
  Map<String, dynamic> primary,
  Map<String, dynamic> fallback,
) {
  final fromPrimary = _readPercentageFromKeys(primary, const [
    'percentage',
    'percent',
    'value',
    'ror',
    'response_rate',
  ]);
  if (fromPrimary != null) return fromPrimary;

  final fromFallback = _readPercentageFromKeys(fallback, const [
    'ror',
    'ror_percentage',
    'response_rate_percentage',
    'response_rate',
    'percentage',
  ]);
  if (fromFallback != null) return fromFallback;

  return 0;
}

int? _readPercentageFromKeys(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    final parsed = _parsePercent(value);
    if (parsed != null) return parsed;
  }
  return null;
}

int? _parsePercent(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    final asDouble = value.toDouble();
    return _normalizePercentDouble(asDouble);
  }
  if (value is num) {
    return _normalizePercentDouble(value.toDouble());
  }
  if (value is String) {
    final normalized = value.trim().replaceAll('%', '');
    final parsed = double.tryParse(normalized);
    if (parsed != null) return _normalizePercentDouble(parsed);
  }
  return null;
}

int _normalizePercentDouble(double value) {
  var normalized = value;
  if (normalized <= 1.5) {
    normalized = normalized * 100;
  }
  return normalized.round().clamp(0, 100);
}

int? _deriveOverallRor({
  required int? hrRor,
  required int? rfqRor,
  required int? invoiceRor,
  required int? pettyCashRor,
  required int? hrCount,
  required int? rfqCount,
  required int? invoiceCount,
  required int? pettyCashCount,
}) {
  final entries = <({int? ror, int? count})>[
    (ror: hrRor, count: hrCount),
    (ror: rfqRor, count: rfqCount),
    (ror: invoiceRor, count: invoiceCount),
    (ror: pettyCashRor, count: pettyCashCount),
  ].where((e) => e.ror != null);

  if (entries.isEmpty) return null;

  final weightedEntries = entries.where((e) => (e.count ?? 0) > 0).toList();
  if (weightedEntries.isNotEmpty) {
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (final e in weightedEntries) {
      final weight = (e.count ?? 0).toDouble();
      weightedSum += (e.ror ?? 0) * weight;
      totalWeight += weight;
    }
    if (totalWeight > 0) {
      return (weightedSum / totalWeight).round().clamp(0, 100);
    }
  }

  final average = entries.fold<double>(0.0, (sum, e) => sum + (e.ror ?? 0)) /
      entries.length;
  return average.round().clamp(0, 100);
}
