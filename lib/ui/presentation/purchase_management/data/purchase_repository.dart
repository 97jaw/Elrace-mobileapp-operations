import 'dart:convert';
import 'dart:typed_data';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PurchaseRepository {
  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 15);
  static const _overviewTimeout = Duration(seconds: 45);
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
    Map<String, dynamic> params, {
    Duration? timeout,
  }) async {
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
          .timeout(timeout ?? _timeout);
      final duration = DateTime.now().difference(start);
      // Decode as UTF-8 with malformation tolerance so bad attachment names
      // (e.g. WhatsApp Scan…) never crash the isolate via response.body.
      final rawText = utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(rawText) as Map<String, dynamic>;
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: _sanitizeLogPayload(data),
        duration: duration,
      );
      if (response.statusCode != 200) return null;
      final rpcError = data['error'];
      if (rpcError != null) {
        if (kDebugMode) {
          debugPrint('purchase API RPC error on $path: $rpcError');
        }
        return null;
      }
      final result = data['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      ApiLogger.logError(endpoint: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Strip huge base64 blobs before logging (content API).
  dynamic _sanitizeLogPayload(dynamic value) {
    if (value is Map) {
      return value.map((key, child) {
        if (key == 'file_data' && child is String && child.length > 120) {
          return MapEntry(key, '<base64 ${child.length} chars>');
        }
        return MapEntry(key, _sanitizeLogPayload(child));
      });
    }
    if (value is List) {
      return value.map(_sanitizeLogPayload).toList();
    }
    return value;
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
    final data = result['data'];
    if (data is! List) return [];
    // Reject only explicit errors. Empty/overwritten status must not drop rows —
    // helpers.success_response flattens meta and a meta key named "status"
    // previously wiped status=success (invoice status_filter bug).
    if (result['status']?.toString() == 'error') return [];
    return List<dynamic>.from(data);
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
    if (refresh) {
      _cachedOverview = null;
      _cachedOverviewAt = null;
      _cachedOverviewRole = null;
    } else if (mobile &&
        _cachedOverview != null &&
        _cachedOverviewAt != null &&
        _cachedOverviewRole == testRole &&
        DateTime.now().difference(_cachedOverviewAt!) <
            _overviewClientCacheTtl) {
      // Never keep serving an unauthorized/zero snapshot after a failed call.
      if (_cachedOverview!.isAuthorized &&
          _cachedOverview!.scope != 'none') {
        if (kDebugMode) {
          debugPrint('purchase/overview client cache hit');
        }
        return _cachedOverview!;
      }
    }

    final result = await _post(
      '/purchase/overview',
      _withTestRole({
        if (mobile) 'mobile': true,
        if (refresh) 'refresh': true,
      }, testRole),
      timeout: _overviewTimeout,
    );
    final payload = _unwrap(result);
    if (payload == null) return PurchaseOverview.unauthorized();
    final overview = PurchaseOverview.fromJson(payload);
    if (mobile && overview.isAuthorized && overview.scope != 'none') {
      _cachedOverview = overview;
      _cachedOverviewAt = DateTime.now();
      _cachedOverviewRole = testRole;
    }

    if (kDebugMode && result?['perf'] != null) {
      debugPrint('purchase/overview perf: ${result!['perf']}');
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

  Future<PurchaseFilterOptionsPage> fetchPurchaseFilterOptions({
    required String kind,
    String search = '',
    int offset = 0,
    int limit = 40,
    PurchaseDevTestRole? testRole,
  }) async {
    final result = await _post(
      '/purchase/filter_options',
      _withTestRole({
        'kind': kind,
        if (search.isNotEmpty) 'search': search,
        'offset': offset,
        'limit': limit,
      }, testRole),
    );
    final payload = _unwrap(result);
    if (payload == null) return PurchaseFilterOptionsPage.empty;
    return PurchaseFilterOptionsPage.fromJson(
      Map<String, dynamic>.from(payload),
      fallbackKind: kind,
    );
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

  /// RFQ supporting docs preview (`attachment_lpo_ids`).
  /// Prefers per-file public URLs so the app can Syncfusion-merge (server
  /// PyPDF2 merges often render as 1 page in the mobile viewer).
  /// Throws [RfqNoAttachmentException] when there are no PDF attachments.
  Future<RfqReportPreview> fetchRfqReportPreview(int rfqId) async {
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

    final urls = <String>[];
    final rawAttachments = result['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is! Map) continue;
        final url = item['url']?.toString().trim() ?? '';
        if (url.isNotEmpty) urls.add(url);
      }
    }

    final reportUrl = result['report_url']?.toString().trim() ?? '';
    if (urls.isEmpty && reportUrl.isNotEmpty) {
      urls.add(reportUrl);
    }
    if (urls.isEmpty) {
      throw RfqNoAttachmentException('No attachment to show');
    }
    return RfqReportPreview(pdfUrls: urls, reportUrl: reportUrl);
  }

  /// Backward-compatible single URL (may be a server merge).
  Future<String> fetchRfqReportUrl(int rfqId) async {
    final preview = await fetchRfqReportPreview(rfqId);
    return preview.pdfUrls.first;
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
    String status = '',
    PurchaseDevTestRole? testRole,
  }) async {
    // Always use /purchase/invoices (all vendor bills).
    // Do NOT fall back to /purchase/draft_invoices — on older deploys that
    // route still filters state=draft, which hides posted bills + payments.
    final result = await _post(
      '/purchase/invoices',
      _withTestRole({
        'page': page,
        'limit': limit,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (status.isNotEmpty) 'status': status,
      }, testRole),
    );
    if (result == null) {
      return (items: <DraftInvoiceItem>[], hasMore: false, total: 0);
    }
    final data = _unwrapList(result);
    final items = data
        .whereType<Map>()
        .map((e) => DraftInvoiceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = _readTotal(result, 0);
    var hasMore = _hasMore(result);
    if (!hasMore && total > 0) {
      final loadedThrough = ((page - 1) * limit) + items.length;
      hasMore = loadedThrough < total;
    }
    if (!hasMore && items.length >= limit) {
      hasMore = true;
    }
    if (kDebugMode) {
      final states = items.map((e) => e.displayStatus).toSet().join(',');
      debugPrint(
        'purchase/invoices page=$page status=$status items=${items.length} '
        'total=$total hasMore=$hasMore scope=${result['scope_version']} '
        'msg=${result['message']} states=$states',
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
    if (refresh) {
      _cachedDraftPreview = null;
      _cachedDraftPreviewAt = null;
      _cachedDraftPreviewRole = null;
    } else if (_cachedDraftPreview != null &&
        _cachedDraftPreviewAt != null &&
        _cachedDraftPreviewRole == testRole &&
        DateTime.now().difference(_cachedDraftPreviewAt!) <
            _overviewClientCacheTtl &&
        _cachedDraftPreview!.totalCount > 0) {
      return _cachedDraftPreview!;
    }

    final result = await _post(
      '/purchase/invoices_preview',
      _withTestRole({
        'limit': limit,
        if (refresh) 'refresh': true,
      }, testRole),
      timeout: _overviewTimeout,
    );
    final payload = _unwrap(result);
    final preview = DraftInvoicesPreview.fromJson(payload);
    if (preview.totalCount > 0 || preview.items.isNotEmpty) {
      _cachedDraftPreview = preview;
      _cachedDraftPreviewAt = DateTime.now();
      _cachedDraftPreviewRole = testRole;
    }
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
    String status = '',
    PurchaseDevTestRole? testRole,
  }) =>
      fetchInvoices(
        page: page,
        limit: limit,
        keyword: keyword,
        status: status,
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
    if (result == null) return null;
    final nested = result['data'];
    if (nested is Map && nested['report_url'] != null) {
      final url = nested['report_url']?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    final url = result['report_url']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  /// PDF bytes for invoice supporting documents via content API (base64).
  /// Prefer this over public `/my/public/file/...` URLs — those often return
  /// empty bodies when attachment metadata shows `file_size: 0`.
  Future<List<Uint8List>> fetchInvoiceSupportingDocumentPdfBytes(
    int invoiceId,
  ) async {
    final result = await _post(
      '/invoice/supporting_documents',
      {'invoice_id': invoiceId},
      timeout: _overviewTimeout,
    );
    final payload = _unwrap(result) ?? result;
    if (payload == null) return const [];

    final raw = payload['supporting_documents'];
    if (raw is! List) return const [];

    final pdfIds = <int>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final mimetype = (map['mimetype'] ?? '').toString().toLowerCase();
      final isPdf = map['is_pdf'] == true || mimetype.contains('pdf');
      if (!isPdf) continue;
      final id = _parseMetaInt(map['attachment_id'] ?? map['id']);
      if (id > 0) pdfIds.add(id);
    }
    if (pdfIds.isEmpty) return const [];

    final parts = <Uint8List>[];
    for (final attachmentId in pdfIds) {
      try {
        final bytes = await _fetchSupportingDocumentBytes(
          invoiceId: invoiceId,
          attachmentId: attachmentId,
        );
        if (bytes != null && bytes.length >= 4) parts.add(bytes);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'supporting doc $attachmentId failed: $e',
          );
        }
      }
    }
    return parts;
  }

  Future<Uint8List?> _fetchSupportingDocumentBytes({
    required int invoiceId,
    required int attachmentId,
  }) async {
    final result = await _post(
      '/invoice/supporting_documents/content',
      {
        'invoice_id': invoiceId,
        'attachment_id': attachmentId,
      },
      timeout: _overviewTimeout,
    );
    final payload = _unwrap(result) ?? result;
    if (payload == null) return null;

    final encoded = payload['file_data']?.toString().trim() ?? '';
    if (encoded.isEmpty) return null;

    var clean = encoded;
    if (clean.startsWith('data:') && clean.contains(',')) {
      clean = clean.split(',').last;
    }
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    try {
      final decoded = base64Decode(clean);
      if (decoded.length >= 4 &&
          decoded[0] == 0x25 &&
          decoded[1] == 0x50 &&
          decoded[2] == 0x44 &&
          decoded[3] == 0x46) {
        return decoded;
      }
      // Some stores wrap PDF as base64-of-base64 or UTF-8 text "%PDF".
      final asText = utf8.decode(decoded, allowMalformed: true).trim();
      if (asText.startsWith('%PDF')) {
        return Uint8List.fromList(utf8.encode(asText));
      }
      if (asText.startsWith('JVBERi0')) {
        return base64Decode(asText.replaceAll(RegExp(r'\s+'), ''));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PDF URLs for invoice supporting documents (legacy / fallback).
  Future<List<String>> fetchInvoiceSupportingDocumentPdfUrls(
    int invoiceId,
  ) async {
    final result = await _post(
      '/invoice/supporting_documents',
      {'invoice_id': invoiceId},
    );
    final payload = _unwrap(result) ?? result;
    if (payload == null) return const [];

    final raw = payload['supporting_documents'];
    if (raw is! List) return const [];

    final urls = <String>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final mimetype = (map['mimetype'] ?? '').toString().toLowerCase();
      final isPdf = map['is_pdf'] == true || mimetype.contains('pdf');
      if (!isPdf) continue;
      final url = (map['file_url'] ?? map['download_url'] ?? '')
          .toString()
          .trim();
      if (url.isNotEmpty) urls.add(url);
    }
    return urls;
  }
}

class RfqReportPreview {
  const RfqReportPreview({
    required this.pdfUrls,
    this.reportUrl = '',
  });

  final List<String> pdfUrls;
  final String reportUrl;
}

class RfqNoAttachmentException implements Exception {
  RfqNoAttachmentException(this.message);
  final String message;

  @override
  String toString() => message;
}
