import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

class VendorsDashboardVendorOption {
  const VendorsDashboardVendorOption({
    required this.id,
    required this.name,
    this.imageUrl = '',
  });

  final int id;
  final String name;
  final String imageUrl;

  factory VendorsDashboardVendorOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final rawImage = (json['image_url'] as String?)?.trim() ?? '';
    final imageUrl = rawImage.isEmpty
        ? ''
        : (rawImage.startsWith('http')
            ? rawImage
            : 'https://erp.elrace.com$rawImage');
    return VendorsDashboardVendorOption(
      id: id,
      name: (json['name'] as String?)?.trim() ?? '',
      imageUrl: imageUrl,
    );
  }
}

class VendorsDashboardMonthPoint {
  const VendorsDashboardMonthPoint({
    required this.month,
    required this.label,
    required this.shortLabel,
    required this.amount,
    required this.amountFormatted,
    required this.amountFull,
    required this.invoiceCount,
  });

  final int month;
  final String label;
  final String shortLabel;
  final double amount;
  final String amountFormatted;
  final String amountFull;
  final int invoiceCount;

  factory VendorsDashboardMonthPoint.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as String?)?.trim() ?? '';
    final short = (json['short_label'] as String?)?.trim();
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    return VendorsDashboardMonthPoint(
      month: (json['month'] as num?)?.toInt() ?? 0,
      label: label,
      shortLabel: (short != null && short.isNotEmpty)
          ? short
          : (label.isNotEmpty ? label[0] : ''),
      amount: amount,
      amountFormatted: (json['amount_formatted'] as String?) ?? 'AED 0',
      amountFull: (json['amount_full'] as String?) ??
          'AED ${amount.toStringAsFixed(2)}',
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
    );
  }

  static List<VendorsDashboardMonthPoint> emptySeries() {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return [
      for (var i = 0; i < 12; i++)
        VendorsDashboardMonthPoint(
          month: i + 1,
          label: labels[i],
          shortLabel: labels[i][0],
          amount: 0,
          amountFormatted: 'AED 0',
          amountFull: 'AED 0.00',
          invoiceCount: 0,
        ),
    ];
  }
}

class VendorsDashboardAgingBucket {
  const VendorsDashboardAgingBucket({
    required this.key,
    required this.label,
    required this.amount,
    required this.amountFormatted,
    required this.percent,
  });

  final String key;
  final String label;
  final double amount;
  final String amountFormatted;
  final double percent;

  factory VendorsDashboardAgingBucket.fromJson(Map<String, dynamic> json) {
    return VendorsDashboardAgingBucket(
      key: (json['key'] as String?)?.trim() ?? '',
      label: (json['label'] as String?)?.trim() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountFormatted: (json['amount_formatted'] as String?) ?? 'AED 0',
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }

  static List<VendorsDashboardAgingBucket> empty() => const [
        VendorsDashboardAgingBucket(
          key: '0_30',
          label: '0–30 Days',
          amount: 0,
          amountFormatted: 'AED 0',
          percent: 0,
        ),
        VendorsDashboardAgingBucket(
          key: '31_60',
          label: '31–60 Days',
          amount: 0,
          amountFormatted: 'AED 0',
          percent: 0,
        ),
        VendorsDashboardAgingBucket(
          key: '61_90',
          label: '61–90 Days',
          amount: 0,
          amountFormatted: 'AED 0',
          percent: 0,
        ),
        VendorsDashboardAgingBucket(
          key: '90_plus',
          label: '90+ Days',
          amount: 0,
          amountFormatted: 'AED 0',
          percent: 0,
        ),
      ];
}

class VendorsDashboardData {
  const VendorsDashboardData({
    required this.isAuthorized,
    required this.year,
    required this.month,
    required this.partnerId,
    required this.years,
    required this.months,
    required this.vendors,
    required this.totalPurchasesFormatted,
    required this.totalPaidFormatted,
    required this.paidPct,
    required this.outstandingPayablesFormatted,
    required this.overduePayablesFormatted,
    required this.overduePayables,
    required this.peakMonth,
    required this.peakAnnotation,
    required this.aging,
  });

  final bool isAuthorized;
  final int year;
  final int? month;
  final int? partnerId;
  final List<int> years;
  final List<VendorsDashboardMonthPoint> months;
  final List<VendorsDashboardVendorOption> vendors;
  final String totalPurchasesFormatted;
  final String totalPaidFormatted;
  final double paidPct;
  final String outstandingPayablesFormatted;
  final String overduePayablesFormatted;
  final double overduePayables;
  final int? peakMonth;
  final String peakAnnotation;
  final List<VendorsDashboardAgingBucket> aging;

  factory VendorsDashboardData.empty({int? year, int? month}) {
    final y = year ?? DateTime.now().year;
    return VendorsDashboardData(
      isAuthorized: false,
      year: y,
      month: month,
      partnerId: null,
      years: [y - 2, y - 1, y],
      months: VendorsDashboardMonthPoint.emptySeries(),
      vendors: const [],
      totalPurchasesFormatted: 'AED 0',
      totalPaidFormatted: 'AED 0',
      paidPct: 0,
      outstandingPayablesFormatted: 'AED 0',
      overduePayablesFormatted: 'AED 0',
      overduePayables: 0,
      peakMonth: null,
      peakAnnotation: '',
      aging: VendorsDashboardAgingBucket.empty(),
    );
  }

  factory VendorsDashboardData.fromJson(Map<String, dynamic> json) {
    final yearsRaw = json['years'];
    final vendorsRaw = json['vendors'];
    final monthsRaw = json['months'];
    final agingRaw = json['aging'];
    final partnerRaw = json['partner_id'];
    final monthRaw = json['month'];
    final peakMonthRaw = json['peak_month'];
    return VendorsDashboardData(
      isAuthorized: json['is_authorized'] == true,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: monthRaw == null ? null : (monthRaw as num).toInt(),
      partnerId: partnerRaw == null ? null : (partnerRaw as num).toInt(),
      years: yearsRaw is List
          ? yearsRaw.map((e) => (e as num).toInt()).toList()
          : <int>[DateTime.now().year],
      months: monthsRaw is List
          ? monthsRaw
              .whereType<Map>()
              .map(
                (e) => VendorsDashboardMonthPoint.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : VendorsDashboardMonthPoint.emptySeries(),
      vendors: vendorsRaw is List
          ? vendorsRaw
              .whereType<Map>()
              .map(
                (e) => VendorsDashboardVendorOption.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((v) => v.id > 0 && v.name.isNotEmpty)
              .toList()
          : const [],
      totalPurchasesFormatted:
          (json['total_purchases_formatted'] as String?) ?? 'AED 0',
      totalPaidFormatted:
          (json['total_paid_formatted'] as String?) ?? 'AED 0',
      paidPct: (json['paid_pct'] as num?)?.toDouble() ?? 0,
      outstandingPayablesFormatted:
          (json['outstanding_payables_formatted'] as String?) ?? 'AED 0',
      overduePayablesFormatted:
          (json['overdue_payables_formatted'] as String?) ?? 'AED 0',
      overduePayables: (json['overdue_payables'] as num?)?.toDouble() ?? 0,
      peakMonth:
          peakMonthRaw == null ? null : (peakMonthRaw as num).toInt(),
      peakAnnotation: (json['peak_annotation'] as String?)?.trim() ?? '',
      aging: agingRaw is List
          ? agingRaw
              .whereType<Map>()
              .map(
                (e) => VendorsDashboardAgingBucket.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : VendorsDashboardAgingBucket.empty(),
    );
  }
}

class VendorsDashboardRepository {
  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 15);

  String get _token => SharedPref.getLoginDataOrNull()?.result?.token ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<VendorsDashboardData> fetchDashboard({
    required int year,
    int? partnerId,
    int? month,
  }) async {
    final result = await _post('/vendors/dashboard', {
      'year': year,
      if (partnerId != null && partnerId > 0) 'partner_id': partnerId,
      if (month != null && month >= 1 && month <= 12) 'month': month,
    });
    final data = _unwrap(result);
    if (data == null) {
      return VendorsDashboardData.empty(year: year, month: month);
    }
    return VendorsDashboardData.fromJson(data);
  }

  Map<String, dynamic>? _unwrap(Map<String, dynamic>? result) {
    if (result == null) return null;
    if (result['status'] == 'success') {
      final data = result['data'];
      if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> params,
  ) async {
    final url = Uri.parse('$_base$path');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
    });
    ApiLogger.logRequest(
      endpoint: url.toString(),
      method: 'POST',
      headers: Map<String, dynamic>.from(_headers),
      body: body,
    );
    final start = DateTime.now();
    try {
      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);
      final duration = DateTime.now().difference(start);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: decoded,
        duration: duration,
      );
      if (response.statusCode != 200) return null;
      final result = decoded['result'];
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (e, st) {
      ApiLogger.logError(endpoint: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }
}
