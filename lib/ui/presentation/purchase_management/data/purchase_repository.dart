import 'dart:convert';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PurchaseRepository {
  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 15);
  static const _overviewClientCacheTtl = Duration(seconds: 90);

  PurchaseOverview? _cachedOverview;
  DateTime? _cachedOverviewAt;
  PurchaseDevTestRole? _cachedOverviewRole;

  String get _token =>
      SharedPref.getLoginData().result?.token ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Map<String, dynamic> _withTestRole(
    Map<String, dynamic> params,
    PurchaseDevTestRole? testRole,
  ) {
    final api = purchaseDevTestRoleApiParam(testRole);
    if (api != null) params['test_purchase_role'] = api;
    return params;
  }

  String _body(Map<String, dynamic> params) => jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      });

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> params,
  ) async {
    final url = Uri.parse('$_base$path');
    final body = _body(params);
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: data,
        duration: duration,
      );
      if (response.statusCode != 200) return null;
      final result = data['result'];
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (e, st) {
      ApiLogger.logError(endpoint: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  Map<String, dynamic>? _unwrap(Map<String, dynamic>? result) {
    if (result == null) return null;
    if (result['status'] == 'success') {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    return result;
  }

  List<dynamic> _unwrapList(Map<String, dynamic>? result) {
    if (result == null) return [];
    if (result['status'] == 'success' && result['data'] is List) {
      return List<dynamic>.from(result['data'] as List);
    }
    return [];
  }

  bool _flagTrue(dynamic value) {
    if (value == true || value == 1) return true;
    final s = value?.toString().trim().toLowerCase();
    return s == 'true' || s == '1';
  }

  /// Controllers pass pagination via `meta=`, but [helpers.success_response]
  /// flattens those keys onto the top-level result (`has_more`, `total`, `page`).
  bool _hasMore(Map<String, dynamic>? result) {
    if (result == null) return false;
    if (_flagTrue(result['has_more'])) return true;
    final meta = result['meta'];
    if (meta is Map && _flagTrue(meta['has_more'])) return true;
    return false;
  }

  int _readTotal(Map<String, dynamic>? result, int fallback) {
    if (result == null) return fallback;
    if (result['total'] != null) return _parseMetaInt(result['total']);
    final meta = result['meta'];
    if (meta is Map && meta['total'] != null) {
      return _parseMetaInt(meta['total']);
    }
    return fallback;
  }

  Future<PurchaseOverview> fetchOverview({
    PurchaseDevTestRole? testRole,
    bool refresh = false,
    bool mobile = true,
  }) async {
    if (mobile &&
        !refresh &&
        _cachedOverview != null &&
        _cachedOverviewAt != null &&
        _cachedOverviewRole == testRole &&
        DateTime.now().difference(_cachedOverviewAt!) <
            _overviewClientCacheTtl) {
      if (kDebugMode) {
        debugPrint('purchase/overview client cache hit');
      }
      return _cachedOverview!;
    }

    final result = await _post(
      '/purchase/overview',
      _withTestRole({
        if (mobile) 'mobile': true,
        if (refresh) 'refresh': true,
      }, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return PurchaseOverview.unauthorized();
    final overview = PurchaseOverview.fromJson(payload);
    if (mobile) {
      _cachedOverview = overview;
      _cachedOverviewAt = DateTime.now();
      _cachedOverviewRole = testRole;
    }

    if (kDebugMode && result?['meta'] is Map) {
      final perf = (result!['meta'] as Map)['perf'];
      if (perf != null) debugPrint('purchase/overview perf: $perf');
    }
    return overview;
  }

  Future<({List<MrItem> items, bool hasMore})> fetchRequisitions({
    int page = 1,
    int limit = 10,
    String keyword = '',
    String status = '',
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/requisitions',
      _withTestRole({
        'page': page,
        'limit': limit,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (status.isNotEmpty) 'status': status,
      }, testRole),
    );
    if (result == null) return (items: <MrItem>[], hasMore: false);
    final data = _unwrapList(result);
    return (
      items: data
          .whereType<Map>()
          .map((e) => MrItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: _hasMore(result),
    );
  }

  Future<MrDetail?> fetchRequisitionDetails(
    int mrId, {
    PurchaseDevTestRole? testRole,
    bool summary = true,
  }) async {
    final result = await _post(
      '/purchase/requisition_details',
      _withTestRole({
        'mr_id': mrId,
        if (summary) 'summary': true,
      }, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return null;
    return MrDetail.fromJson(payload);
  }

  Future<PurchaseFilterOptions> fetchPurchaseFilterOptions({
    String search = '',
    String kind = '',
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/filter_options',
      _withTestRole({
        if (search.isNotEmpty) 'search': search,
        if (kind.isNotEmpty) 'kind': kind,
      }, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return PurchaseFilterOptions.empty;
    return PurchaseFilterOptions.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<({List<RfqItem> items, bool hasMore})> fetchRfqs({
    int page = 1,
    int limit = 10,
    String keyword = '',
    String status = '',
    bool orderDesc = true,
    LpoListFilters? filters,
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/rfqs',
      _withTestRole({
        'page': page,
        'limit': limit,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (status.isNotEmpty) 'status': status,
        'order': orderDesc ? 'desc' : 'asc',
        ...?filters?.toApiParams(),
      }, testRole),
    );
    if (result == null) return (items: <RfqItem>[], hasMore: false);
    final data = _unwrapList(result);
    return (
      items: data
          .whereType<Map>()
          .map((e) => RfqItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: _hasMore(result),
    );
  }

  Future<Map<String, dynamic>?> fetchRfqDetails(int rfqId) async {
    final result = await _post('/get_rfq_details', {'rfq_id': rfqId});
    return result;
  }

  Future<String?> fetchPoReportUrl(int poId) async {
    final result = await _post('/po/report_url', {'po_id': poId});
    return result?['report_url']?.toString();
  }

  /// RFQ supporting docs preview (`attachment_lpo_ids` merged).
  /// Does not use LPO `/po/report_url`.
  /// Throws [RfqNoAttachmentException] when there are no PDF attachments.
  Future<String> fetchRfqReportUrl(int rfqId) async {
    final result = await _post('/rfq/report_url', {'rfq_id': rfqId});
    if (result == null) {
      throw Exception('Failed to load RFQ attachments');
    }
    final status = result['status']?.toString();
    final message = result['message']?.toString() ?? '';
    if (status == 'error' ||
        result['code']?.toString() == 'NO_ATTACHMENT' ||
        message.toLowerCase().contains('no attachment')) {
      throw RfqNoAttachmentException(
        message.isNotEmpty ? message : 'No attachment to show',
      );
    }
    final url = result['report_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw RfqNoAttachmentException('No attachment to show');
    }
    return url;
  }

  Future<({List<InvoiceReceivingItem> items, bool hasMore})>
      fetchInvoiceReceiving({
    int page = 1,
    int limit = 15,
    String keyword = '',
    String status = '',
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/invoice_receiving',
      _withTestRole({
        'page': page,
        'limit': limit,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (status.isNotEmpty) 'status': status,
      }, testRole),
    );
    if (result == null) return (items: <InvoiceReceivingItem>[], hasMore: false);
    final data = _unwrapList(result);
    return (
      items: data
          .whereType<Map>()
          .map((e) =>
              InvoiceReceivingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: _hasMore(result),
    );
  }

  Future<InvoiceReceivingDetail?> fetchInvoiceReceivingDetails(
    int invoiceId, {
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/invoice_receiving_details',
      _withTestRole({'invoice_id': invoiceId}, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return null;
    return InvoiceReceivingDetail.fromJson(payload);
  }

  Future<List<LpoOption>> fetchLpoOptions({
    String keyword = '',
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/lpo_options',
      _withTestRole({
        'limit': 40,
        if (keyword.isNotEmpty) 'keyword': keyword,
      }, testRole),
    );
    final data = _unwrapList(result);
    return data
        .whereType<Map>()
        .map((e) => LpoOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InvoiceReceivingItem?> createInvoiceReceiving({
    required String invoiceNo,
    required int lpoId,
    String invoiceDate = '',
    String invoicingDate = '',
    double amount = 0,
    String remark = '',
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/invoice_receiving_create',
      _withTestRole({
        'invoice_no': invoiceNo,
        'lpo_id': lpoId,
        if (invoiceDate.isNotEmpty) 'invoice_date': invoiceDate,
        if (invoicingDate.isNotEmpty) 'invoicing_date': invoicingDate,
        if (amount > 0) 'amount': amount,
        if (remark.isNotEmpty) 'remark': remark,
      }, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return null;
    return InvoiceReceivingItem.fromJson(payload);
  }

  Future<InvoiceReceivingItem?> receiveInvoiceReceiving(
    int invoiceId, {
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/invoice_receiving_receive',
      _withTestRole({'invoice_id': invoiceId}, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return null;
    return InvoiceReceivingItem.fromJson(payload);
  }

  Future<({List<DraftInvoiceItem> items, bool hasMore, int total})>
      fetchInvoices({
    int page = 1,
    int limit = 15,
    String keyword = '',
    PurchaseDevTestRole? testRole,
  }) async {
    // Prefer new route; fall back to legacy alias if not deployed yet.
    Map<String, dynamic>? result;
    try {
      result = await _post(
        '/purchase/invoices',
        _withTestRole({
          'page': page,
          'limit': limit,
          if (keyword.isNotEmpty) 'keyword': keyword,
        }, testRole),
      );
    } catch (_) {
      result = null;
    }
    final invoicesOk = result != null &&
        (result['status'] == 'success' || result['data'] is List);
    if (!invoicesOk) {
      result = await _post(
        '/purchase/draft_invoices',
        _withTestRole({
          'page': page,
          'limit': limit,
          if (keyword.isNotEmpty) 'keyword': keyword,
        }, testRole),
      );
    }
    if (result == null) {
      return (items: <DraftInvoiceItem>[], hasMore: false, total: 0);
    }
    final data = _unwrapList(result);
    final items = data
        .whereType<Map>()
        .map((e) => DraftInvoiceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = _readTotal(result, 0);
    // Flattened meta.has_more, then total math, then "full page" heuristic.
    var hasMore = _hasMore(result);
    if (!hasMore && total > 0) {
      final loadedThrough = ((page - 1) * limit) + items.length;
      hasMore = loadedThrough < total;
    }
    if (!hasMore && items.length >= limit) {
      hasMore = true;
    }
    if (kDebugMode) {
      debugPrint(
        'purchase/invoices page=$page items=${items.length} '
        'total=$total hasMore=$hasMore rawHasMore=${result['has_more']}',
      );
    }
    return (
      items: items,
      hasMore: hasMore,
      total: total > 0 ? total : (hasMore ? 0 : items.length),
    );
  }

  Future<DraftInvoicesPreview> fetchInvoicesPreview({
    PurchaseDevTestRole? testRole,
    int limit = 5,
    bool refresh = false,
  }) async {
    if (!refresh &&
        _cachedDraftPreview != null &&
        _cachedDraftPreviewAt != null &&
        _cachedDraftPreviewRole == testRole &&
        DateTime.now().difference(_cachedDraftPreviewAt!) <
            _overviewClientCacheTtl) {
      return _cachedDraftPreview!;
    }

    final result = await _post(
      '/purchase/invoices_preview',
      _withTestRole({'limit': limit}, testRole),
    );
    final payload = _unwrap(result);
    final preview = DraftInvoicesPreview.fromJson(payload);
    _cachedDraftPreview = preview;
    _cachedDraftPreviewAt = DateTime.now();
    _cachedDraftPreviewRole = testRole;
    return preview;
  }

  Future<PurchaseInvoiceDetail?> fetchInvoiceDetails(
    int invoiceId, {
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/invoice_details',
      _withTestRole({'invoice_id': invoiceId}, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return null;
    return PurchaseInvoiceDetail.fromJson(payload);
  }

  /// Legacy alias — same as [fetchInvoices].
  Future<({List<DraftInvoiceItem> items, bool hasMore, int total})>
      fetchDraftInvoices({
    int page = 1,
    int limit = 15,
    String keyword = '',
    PurchaseDevTestRole? testRole,
  }) =>
      fetchInvoices(
        page: page,
        limit: limit,
        keyword: keyword,
        testRole: testRole,
      );

  /// Legacy alias — same as [fetchInvoicesPreview].
  Future<DraftInvoicesPreview> fetchDraftInvoicesPreview({
    PurchaseDevTestRole? testRole,
    int limit = 5,
    bool refresh = false,
  }) =>
      fetchInvoicesPreview(
        testRole: testRole,
        limit: limit,
        refresh: refresh,
      );

  DraftInvoicesPreview? _cachedDraftPreview;
  DateTime? _cachedDraftPreviewAt;
  PurchaseDevTestRole? _cachedDraftPreviewRole;

  int _parseMetaInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<String?> fetchInvoiceReportUrl(int invoiceId) async {
    final result =
        await _post('/invoice/report_url', {'invoice_id': invoiceId});
    return result?['report_url']?.toString();
  }
}

class RfqNoAttachmentException implements Exception {
  RfqNoAttachmentException(this.message);
  final String message;

  @override
  String toString() => message;
}
