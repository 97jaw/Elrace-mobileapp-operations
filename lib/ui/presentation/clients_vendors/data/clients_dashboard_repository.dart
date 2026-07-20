import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

class ClientsDashboardClientOption {
  const ClientsDashboardClientOption({
    required this.id,
    required this.name,
    this.imageUrl = '',
  });

  final int id;
  final String name;
  final String imageUrl;

  factory ClientsDashboardClientOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final rawImage = (json['image_url'] as String?)?.trim() ?? '';
    final imageUrl = rawImage.isEmpty
        ? ''
        : (rawImage.startsWith('http')
            ? rawImage
            : 'https://erp.elrace.com$rawImage');
    return ClientsDashboardClientOption(
      id: id,
      name: (json['name'] as String?)?.trim() ?? '',
      imageUrl: imageUrl,
    );
  }
}

class ClientsDashboardMonthPoint {
  const ClientsDashboardMonthPoint({
    required this.month,
    required this.label,
    required this.amount,
    required this.invoiceCount,
  });

  final int month;
  final String label;
  final double amount;
  final int invoiceCount;

  factory ClientsDashboardMonthPoint.fromJson(Map<String, dynamic> json) {
    return ClientsDashboardMonthPoint(
      month: (json['month'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientsDashboardData {
  const ClientsDashboardData({
    required this.isAuthorized,
    required this.year,
    required this.partnerId,
    required this.scope,
    required this.years,
    required this.clients,
    required this.topClients,
    required this.months,
    required this.amountDue,
    required this.amountDueFormatted,
    required this.amountDueIsOverdue,
    required this.amountPaid,
    required this.amountPaidFormatted,
    required this.totalInvoiced,
    required this.totalInvoicedFormatted,
  });

  final bool isAuthorized;
  final int year;
  final int? partnerId;

  /// `top3` or `client`
  final String scope;
  final List<int> years;
  final List<ClientsDashboardClientOption> clients;
  final List<ClientsDashboardClientOption> topClients;
  final List<ClientsDashboardMonthPoint> months;
  final double amountDue;
  final String amountDueFormatted;
  final bool amountDueIsOverdue;
  final double amountPaid;
  final String amountPaidFormatted;
  final double totalInvoiced;
  final String totalInvoicedFormatted;

  factory ClientsDashboardData.empty({int? year}) {
    final y = year ?? DateTime.now().year;
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return ClientsDashboardData(
      isAuthorized: false,
      year: y,
      partnerId: null,
      scope: 'top3',
      years: [y - 2, y - 1, y],
      clients: const [],
      topClients: const [],
      months: [
        for (var i = 0; i < 12; i++)
          ClientsDashboardMonthPoint(
            month: i + 1,
            label: labels[i],
            amount: 0,
            invoiceCount: 0,
          ),
      ],
      amountDue: 0,
      amountDueFormatted: 'AED 0.00',
      amountDueIsOverdue: false,
      amountPaid: 0,
      amountPaidFormatted: 'AED 0.00',
      totalInvoiced: 0,
      totalInvoicedFormatted: 'AED 0.00',
    );
  }

  factory ClientsDashboardData.fromJson(Map<String, dynamic> json) {
    final yearsRaw = json['years'];
    final clientsRaw = json['clients'];
    final topRaw = json['top_clients'];
    final monthsRaw = json['months'];
    final partnerRaw = json['partner_id'];

    List<ClientsDashboardClientOption> parseClients(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => ClientsDashboardClientOption.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((c) => c.id > 0 && c.name.isNotEmpty)
          .toList();
    }

    return ClientsDashboardData(
      isAuthorized: json['is_authorized'] == true,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      partnerId: partnerRaw == null ? null : (partnerRaw as num).toInt(),
      scope: (json['scope'] as String?)?.trim().isNotEmpty == true
          ? (json['scope'] as String).trim()
          : 'top3',
      years: yearsRaw is List
          ? yearsRaw.map((e) => (e as num).toInt()).toList()
          : <int>[DateTime.now().year],
      clients: parseClients(clientsRaw),
      topClients: parseClients(topRaw),
      months: monthsRaw is List
          ? monthsRaw
              .whereType<Map>()
              .map(
                (e) => ClientsDashboardMonthPoint.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : ClientsDashboardData.empty().months,
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0,
      amountDueFormatted:
          (json['amount_due_formatted'] as String?) ?? 'AED 0.00',
      amountDueIsOverdue: json['amount_due_is_overdue'] == true,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      amountPaidFormatted:
          (json['amount_paid_formatted'] as String?) ?? 'AED 0.00',
      totalInvoiced: (json['total_invoiced'] as num?)?.toDouble() ?? 0,
      totalInvoicedFormatted:
          (json['total_invoiced_formatted'] as String?) ?? 'AED 0.00',
    );
  }
}

class ClientsDashboardRepository {
  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 15);

  String get _token => SharedPref.getLoginDataOrNull()?.result?.token ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<ClientsDashboardData> fetchDashboard({
    required int year,
    String scope = 'top3',
    int? partnerId,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'scope': scope,
      if (scope == 'client' && partnerId != null && partnerId > 0)
        'partner_id': partnerId,
    };
    final result = await _post('/clients/dashboard', params);
    final data = _unwrap(result);
    if (data == null) {
      return ClientsDashboardData.empty(year: year);
    }
    return ClientsDashboardData.fromJson(data);
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
