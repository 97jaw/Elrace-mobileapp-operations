import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

class VendorsDashboardVendorOption {
  const VendorsDashboardVendorOption({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.customerType = '',
  });

  final int id;
  final String name;
  final String imageUrl;
  final String customerType;

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
      customerType: (json['customer_type'] as String?)?.trim() ?? '',
    );
  }
}

class VendorsPartnerOptionsPage {
  const VendorsPartnerOptionsPage({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });

  final List<VendorsDashboardVendorOption> items;
  final int total;
  final bool hasMore;
  final int offset;
  final int limit;

  factory VendorsPartnerOptionsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return VendorsPartnerOptionsPage(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => VendorsDashboardVendorOption.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((e) => e.id > 0)
              .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 40,
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
    required this.totalPurchasesFormatted,
    required this.purchasesMomPct,
    required this.totalPaidFormatted,
    required this.paidPct,
    required this.paidInvoiceCount,
    required this.outstandingPayablesFormatted,
    required this.overduePayablesFormatted,
    required this.overduePayables,
    required this.overdueCount,
    required this.dueSoonAmountFormatted,
    required this.dueSoonAmount,
    required this.dueSoonCount,
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
  final String totalPurchasesFormatted;
  final double purchasesMomPct;
  final String totalPaidFormatted;
  final double paidPct;
  final int paidInvoiceCount;
  final String outstandingPayablesFormatted;
  final String overduePayablesFormatted;
  final double overduePayables;
  final int overdueCount;
  final String dueSoonAmountFormatted;
  final double dueSoonAmount;
  final int dueSoonCount;
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
      totalPurchasesFormatted: 'AED 0',
      purchasesMomPct: 0,
      totalPaidFormatted: 'AED 0',
      paidPct: 0,
      paidInvoiceCount: 0,
      outstandingPayablesFormatted: 'AED 0',
      overduePayablesFormatted: 'AED 0',
      overduePayables: 0,
      overdueCount: 0,
      dueSoonAmountFormatted: 'AED 0',
      dueSoonAmount: 0,
      dueSoonCount: 0,
      peakMonth: null,
      peakAnnotation: '',
      aging: VendorsDashboardAgingBucket.empty(),
    );
  }

  factory VendorsDashboardData.fromJson(Map<String, dynamic> json) {
    final yearsRaw = json['years'];
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
      totalPurchasesFormatted:
          (json['total_purchases_formatted'] as String?) ?? 'AED 0',
      purchasesMomPct: (json['purchases_mom_pct'] as num?)?.toDouble() ?? 0,
      totalPaidFormatted:
          (json['total_paid_formatted'] as String?) ?? 'AED 0',
      paidPct: (json['paid_pct'] as num?)?.toDouble() ?? 0,
      paidInvoiceCount: (json['paid_invoice_count'] as num?)?.toInt() ?? 0,
      outstandingPayablesFormatted:
          (json['outstanding_payables_formatted'] as String?) ?? 'AED 0',
      overduePayablesFormatted:
          (json['overdue_payables_formatted'] as String?) ?? 'AED 0',
      overduePayables: (json['overdue_payables'] as num?)?.toDouble() ?? 0,
      overdueCount: (json['overdue_count'] as num?)?.toInt() ?? 0,
      dueSoonAmountFormatted:
          (json['due_soon_amount_formatted'] as String?) ?? 'AED 0',
      dueSoonAmount: (json['due_soon_amount'] as num?)?.toDouble() ?? 0,
      dueSoonCount: (json['due_soon_count'] as num?)?.toInt() ?? 0,
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

class VendorsAgreementsSummary {
  const VendorsAgreementsSummary({
    required this.isAuthorized,
    required this.totalCount,
    required this.activeCount,
    required this.expiring90Count,
    required this.totalValueFormatted,
  });

  final bool isAuthorized;
  final int totalCount;
  final int activeCount;
  final int expiring90Count;
  final String totalValueFormatted;

  factory VendorsAgreementsSummary.empty() => const VendorsAgreementsSummary(
        isAuthorized: false,
        totalCount: 0,
        activeCount: 0,
        expiring90Count: 0,
        totalValueFormatted: 'AED 0',
      );

  factory VendorsAgreementsSummary.fromJson(Map<String, dynamic> json) {
    return VendorsAgreementsSummary(
      isAuthorized: json['is_authorized'] == true,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      expiring90Count: (json['expiring_90_count'] as num?)?.toInt() ?? 0,
      totalValueFormatted:
          (json['total_value_formatted'] as String?) ?? 'AED 0',
    );
  }
}

class VendorsAgreementRow {
  const VendorsAgreementRow({
    required this.id,
    required this.number,
    required this.startDate,
    required this.endDate,
    required this.valueFormatted,
  });

  final int id;
  final String number;
  final String startDate;
  final String endDate;
  final String valueFormatted;

  factory VendorsAgreementRow.fromJson(Map<String, dynamic> json) {
    return VendorsAgreementRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: (json['number'] as String?)?.trim().isNotEmpty == true
          ? (json['number'] as String).trim()
          : ((json['name'] as String?)?.trim() ?? ''),
      startDate: (json['start_date'] as String?)?.trim() ?? '',
      endDate: (json['end_date'] as String?)?.trim() ?? '',
      valueFormatted: (json['value_formatted'] as String?) ?? 'AED 0',
    );
  }
}

class VendorsAgreementsPage {
  const VendorsAgreementsPage({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });

  final List<VendorsAgreementRow> items;
  final int total;
  final bool hasMore;
  final int offset;
  final int limit;

  factory VendorsAgreementsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return VendorsAgreementsPage(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => VendorsAgreementRow.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((e) => e.id > 0)
              .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 40,
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

  Future<VendorsPartnerOptionsPage> fetchPartners({
    String keyword = '',
    int offset = 0,
    int limit = 40,
  }) async {
    final result = await _post('/vendors/partners', {
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      'offset': offset,
      'limit': limit,
    });
    final data = _unwrap(result);
    if (data == null) {
      return const VendorsPartnerOptionsPage(
        items: [],
        total: 0,
        hasMore: false,
        offset: 0,
        limit: 40,
      );
    }
    return VendorsPartnerOptionsPage.fromJson(data);
  }

  Future<VendorsAgreementsSummary> fetchAgreementsSummary({
    int? partnerId,
  }) async {
    final result = await _post('/vendors/agreements/summary', {
      if (partnerId != null && partnerId > 0) 'partner_id': partnerId,
    });
    final data = _unwrap(result);
    if (data == null) return VendorsAgreementsSummary.empty();
    return VendorsAgreementsSummary.fromJson(data);
  }

  Future<VendorsAgreementsPage> fetchAgreements({
    int? partnerId,
    String keyword = '',
    int offset = 0,
    int limit = 40,
  }) async {
    final result = await _post('/vendors/agreements', {
      if (partnerId != null && partnerId > 0) 'partner_id': partnerId,
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      'offset': offset,
      'limit': limit,
    });
    final data = _unwrap(result);
    if (data == null) {
      return const VendorsAgreementsPage(
        items: [],
        total: 0,
        hasMore: false,
        offset: 0,
        limit: 40,
      );
    }
    return VendorsAgreementsPage.fromJson(data);
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
