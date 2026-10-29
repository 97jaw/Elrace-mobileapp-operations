import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_api_catalog.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:flutter/foundation.dart';

/// Thin client for `/api/labor_transfer/*` (same transport / JWT as timesheet).
class LaborTransferApi {
  LaborTransferApi(this._transport);

  final TimesheetOdooTransport _transport;

  Future<List<LaborTransferLaborOption>> fetchLabors({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferLabors,
      {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'limit': limit,
        'offset': offset,
      },
      debugLabel: 'labor_transfer/labors',
    );
    final rows = _transport.parseMapList(data, key: 'labors');
    return rows.map(LaborTransferLaborOption.fromJson).toList();
  }

  Future<List<LaborTransferPerson>> fetchForemen({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferForemen,
      {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'limit': limit,
        'offset': offset,
      },
      debugLabel: 'labor_transfer/foremen',
    );
    final rows = _transport.parseMapList(data, key: 'foremen');
    return rows.map(LaborTransferPerson.fromJson).toList();
  }

  Future<LaborTransferRecord> create({
    required List<int> laborIds,
    required int targetForemanId,
    String? note,
  }) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferCreate,
      {
        'labor_ids': laborIds,
        'target_foreman_id': targetForemanId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      debugLabel: 'labor_transfer/create',
    );
    return LaborTransferRecord.fromJson(data);
  }

  Future<List<LaborTransferRecord>> list({
    required LaborTransferBox box,
    String? state,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferList,
      {
        'box': box.apiValue,
        if (state != null && state.isNotEmpty) 'state': state,
        'limit': limit,
        'offset': offset,
      },
      debugLabel: 'labor_transfer/list',
    );
    final rows = _transport.parseMapList(data, key: 'transfers');
    return rows.map(LaborTransferRecord.fromJson).toList();
  }

  Future<LaborTransferCounts> counts() async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferCounts,
      const {},
      debugLabel: 'labor_transfer/counts',
    );
    return LaborTransferCounts.fromJson(data);
  }

  Future<LaborTransferRecord> detail(int id) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferDetail,
      {'id': id},
      debugLabel: 'labor_transfer/detail',
    );
    return LaborTransferRecord.fromJson(data);
  }

  Future<LaborTransferRecord> approve(int id) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferApprove,
      {'id': id},
      debugLabel: 'labor_transfer/approve',
    );
    return LaborTransferRecord.fromJson(data);
  }

  Future<LaborTransferRecord> reject(int id, {required String reason}) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferReject,
      {'id': id, 'reason': reason.trim()},
      debugLabel: 'labor_transfer/reject',
    );
    return LaborTransferRecord.fromJson(data);
  }

  Future<LaborTransferRecord> cancel(int id) async {
    final data = await _postMap(
      TimesheetOdooApiCatalog.laborTransferCancel,
      {'id': id},
      debugLabel: 'labor_transfer/cancel',
    );
    return LaborTransferRecord.fromJson(data);
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> params, {
    required String debugLabel,
  }) async {
    if (!_transport.hasSession) {
      throw TimesheetOdooException('Not signed in');
    }
    final body = await _transport.postJsonRpc(path, params: params);
    final result = _transport.parseResult(body, debugLabel: debugLabel);
    final map = _unwrapSuccessMap(result);
    if (map == null) {
      throw TimesheetOdooException('$debugLabel: empty response');
    }
    return map;
  }

  Map<String, dynamic>? _unwrapSuccessMap(Object? result) {
    if (result is! Map) return null;
    final outer = Map<String, dynamic>.from(result);
    if (outer['status']?.toString() == 'error') {
      throw TimesheetOdooException(
        outer['message']?.toString() ?? 'Odoo API error',
      );
    }
    if (outer['data'] is Map) {
      return Map<String, dynamic>.from(outer['data'] as Map);
    }
    // Some envelopes put the payload at the top level after unwrap.
    if (outer.containsKey('id') ||
        outer.containsKey('labors') ||
        outer.containsKey('foremen') ||
        outer.containsKey('transfers') ||
        outer.containsKey('to_approve') ||
        outer.containsKey('my_requests_pending') ||
        outer.containsKey('is_approver')) {
      return outer;
    }
    debugPrint('LaborTransferApi: unexpected payload keys=${outer.keys}');
    return outer;
  }
}
