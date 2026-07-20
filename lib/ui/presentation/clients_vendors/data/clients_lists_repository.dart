import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

class ArSummaryItem {
  const ArSummaryItem({
    required this.partnerId,
    required this.partnerName,
    required this.imageUrl,
    required this.totalOutstanding,
    required this.totalOutstandingFormatted,
    required this.overdueAmount,
    required this.overdueAmountFormatted,
    required this.current030,
    required this.current030Formatted,
    required this.totalInvoicedYtd,
    required this.totalInvoicedYtdFormatted,
  });

  final int partnerId;
  final String partnerName;
  final String imageUrl;
  final double totalOutstanding;
  final String totalOutstandingFormatted;
  final double overdueAmount;
  final String overdueAmountFormatted;
  final double current030;
  final String current030Formatted;
  final double totalInvoicedYtd;
  final String totalInvoicedYtdFormatted;

  factory ArSummaryItem.fromJson(Map<String, dynamic> json) {
    return ArSummaryItem(
      partnerId: (json['partner_id'] as num?)?.toInt() ?? 0,
      partnerName: (json['partner_name'] as String?)?.trim() ?? '',
      imageUrl: _absImage(json['image_url']),
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
      totalOutstandingFormatted:
          (json['total_outstanding_formatted'] as String?) ?? 'AED 0.00',
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0,
      overdueAmountFormatted:
          (json['overdue_amount_formatted'] as String?) ?? 'AED 0.00',
      current030: (json['current_0_30'] as num?)?.toDouble() ?? 0,
      current030Formatted:
          (json['current_0_30_formatted'] as String?) ?? 'AED 0.00',
      totalInvoicedYtd: (json['total_invoiced_ytd'] as num?)?.toDouble() ?? 0,
      totalInvoicedYtdFormatted:
          (json['total_invoiced_ytd_formatted'] as String?) ?? 'AED 0.00',
    );
  }
}

class OutstandingInvoiceItem {
  const OutstandingInvoiceItem({
    required this.id,
    required this.name,
    required this.invoiceDate,
    required this.invoiceDateDue,
    required this.partnerId,
    required this.partnerName,
    required this.imageUrl,
    required this.amountTotalFormatted,
    required this.amountPaidFormatted,
    required this.amountDueFormatted,
    required this.statusCode,
    required this.statusLabel,
  });

  final int id;
  final String name;
  final String invoiceDate;
  final String invoiceDateDue;
  final int? partnerId;
  final String partnerName;
  final String imageUrl;
  final String amountTotalFormatted;
  final String amountPaidFormatted;
  final String amountDueFormatted;
  final String statusCode;
  final String statusLabel;

  factory OutstandingInvoiceItem.fromJson(Map<String, dynamic> json) {
    return OutstandingInvoiceItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      invoiceDate: (json['invoice_date'] as String?) ?? '',
      invoiceDateDue: (json['invoice_date_due'] as String?) ?? '',
      partnerId: (json['partner_id'] as num?)?.toInt(),
      partnerName: (json['partner_name'] as String?)?.trim() ?? '',
      imageUrl: _absImage(json['image_url']),
      amountTotalFormatted:
          (json['amount_total_formatted'] as String?) ?? 'AED 0.00',
      amountPaidFormatted:
          (json['amount_paid_formatted'] as String?) ?? 'AED 0.00',
      amountDueFormatted:
          (json['amount_due_formatted'] as String?) ?? 'AED 0.00',
      statusCode: (json['status_code'] as String?) ?? 'open',
      statusLabel: (json['status_label'] as String?) ?? 'Open',
    );
  }
}

String _absImage(dynamic raw) {
  final value = (raw as String?)?.trim() ?? '';
  if (value.isEmpty) return '';
  if (value.startsWith('http')) return value;
  return 'https://erp.elrace.com$value';
}

class ClientsListsRepository {
  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 20);

  String get _token => SharedPref.getLoginDataOrNull()?.result?.token ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<ArSummaryItem>> fetchArSummary({
    required int year,
    String keyword = '',
  }) async {
    final result = await _post('/clients/ar_summary', {
      'year': year,
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    });
    final data = _unwrap(result);
    final items = data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => ArSummaryItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.partnerId > 0)
        .toList();
  }

  Future<List<OutstandingInvoiceItem>> fetchOutstandingInvoices({
    required int year,
    int? month,
    int? partnerId,
    String keyword = '',
  }) async {
    final result = await _post('/clients/outstanding_invoices', {
      'year': year,
      if (month != null && month >= 1 && month <= 12) 'month': month,
      if (partnerId != null && partnerId > 0) 'partner_id': partnerId,
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    });
    final data = _unwrap(result);
    final items = data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (e) => OutstandingInvoiceItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
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
