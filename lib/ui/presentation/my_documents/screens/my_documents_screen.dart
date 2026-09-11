import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../../../widgets/custom_slider_button.dart';
import '../utils/document_attachment_opener.dart';
import '../utils/document_display.dart';
import '../widgets/document_expiry_trailing.dart';
import 'add_document_wizard_screen.dart';
import 'document_details_screen.dart';
import 'family_documents_screen.dart';

const String _familyTaggedDocumentIdsKey = 'my_documents_family_tagged_ids_v1';

Set<int> _loadTaggedDocumentIds(String key) {
  try {
    final raw = SharedPref.preferences.getPreferenceString(key);
    if (raw.trim().isEmpty) return <int>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <int>{};

    return decoded
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .toSet();
  } catch (_) {
    return <int>{};
  }
}

Future<void> _saveTaggedDocumentIds(String key, Set<int> ids) async {
  await SharedPref.preferences
      .setPreferencesString(key, jsonEncode(ids.toList(growable: false)));
}

Future<void> _tagDocumentAsFamily(int id) async {
  final ids = _loadTaggedDocumentIds(_familyTaggedDocumentIdsKey);
  ids.add(id);
  await _saveTaggedDocumentIds(_familyTaggedDocumentIdsKey, ids);
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({
    super.key,
  });

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<Map<String, dynamic>> documents = [];
  bool _loading = false;
  String? _error;
  String _statTotal = '-';
  String _statActive = '-';
  String _statRequested = '-';
  String _statExpiringSoon = '-';
  String _statExpired = '-';
  /// Active stats filter: null = all, active / expiry_soon / requested / expired.
  String? _activeDocType;

  /// Local scope chip: all / personal / family.
  String _smartScope = 'all';

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  double? _edgeSwipeStartX;
  bool _isHandlingEdgeSwipeBack = false;

  @override
  void initState() {
    super.initState();
    _fetchMyDocuments();

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        unawaited(
          _fetchMyDocuments(
            keyword: text.isEmpty ? null : text,
            docType: _activeDocType,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isFamilyDoc(Map<String, dynamic> raw) {
    final map = raw;
    final typeStr =
        (map['type'] ?? map['document_type'] ?? map['category'] ?? '')
            .toString()
            .toLowerCase();
    final titleStr = (map['title'] ?? '').toString().toLowerCase();
    final isFamilyFlag = map['is_family'] == true || map['family'] == true;
    return isFamilyFlag ||
        typeStr.contains('family') ||
        titleStr.contains('family');
  }

  void _debugPrintLong(String message) {
    if (!kDebugMode) return;
    const chunkSize = 800;
    for (var i = 0; i < message.length; i += chunkSize) {
      final end =
          (i + chunkSize < message.length) ? i + chunkSize : message.length;
      debugPrint(message.substring(i, end));
    }
  }

  dynamic _firstAttachmentIdFrom(dynamic attachmentIds) {
    if (attachmentIds is List && attachmentIds.isNotEmpty) {
      final first = attachmentIds.first;
      if (first is Map) {
        return first['attachment_id'] ?? first['id'] ?? first['attachmentId'];
      }
      return first;
    }
    if (attachmentIds is Map) {
      return attachmentIds['attachment_id'] ??
          attachmentIds['id'] ??
          attachmentIds['attachmentId'];
    }
    return null;
  }

  int? _firstAttachmentIdAsInt(Map<String, dynamic> document) {
    final raw = _firstAttachmentIdFrom(document['attachment_ids']);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _openDocumentAttachment(Map<String, dynamic> document) async {
    if (!mounted) return;
    await DocumentAttachmentOpener.open(context, document);
  }

  void _debugPrintBodyPreview(String body, {int maxChars = 4000}) {
    if (!kDebugMode) return;
    if (body.length <= maxChars) {
      _debugPrintLong(body);
      return;
    }
    _debugPrintLong(body.substring(0, maxChars));
    debugPrint('... (truncated, length=${body.length})');
  }

  Future<void> _debugPrintDocumentTapApi(Map<String, dynamic> document) async {
    if (!kDebugMode) return;

    debugPrint('=========== MY DOCUMENT (TAP) START ===========');
    debugPrint('Doc id: ${document['id']}');
    _debugPrintLong(jsonEncode(document));

    final attachmentId = _firstAttachmentIdFrom(document['attachment_ids']);
    if (attachmentId == null) {
      debugPrint('No attachment_ids found for this document.');
      debugPrint('============ MY DOCUMENT (TAP) END ============');
      return;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    final url = Uri.parse('${UrlUtil.baseUrl}get_attachment_details');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'attachment_id': attachmentId,
      },
    });

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('----- get_attachment_details RESPONSE -----');
      debugPrint('Status: ${response.statusCode}');
      _debugPrintBodyPreview(response.body);
      debugPrint('-----------------------------------------');
    } catch (e) {
      debugPrint('❌ get_attachment_details failed: $e');
    } finally {
      debugPrint('============ MY DOCUMENT (TAP) END ============');
    }
  }

  String? _normalizeDocType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'all' || value == 'active') return null;
    if (value == 'expiry_soon' || value == 'expired' || value == 'requested') {
      return value;
    }
    return null;
  }

  /// Local-only filter key (not sent to API).
  bool _isLocalActiveFilter(String? raw) =>
      (raw ?? '').trim().toLowerCase() == 'active';

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _fetchMyDocuments({String? keyword, String? docType}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url = Uri.parse('${UrlUtil.baseUrl}get_employee_documents');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final requestedFilter = (docType ?? '').trim().toLowerCase();
      final normalizedDocType = _normalizeDocType(docType);
      final familyTaggedIds =
          _loadTaggedDocumentIds(_familyTaggedDocumentIdsKey);

      final personalBundle = await _requestAndMapDocuments(
        url: url,
        headers: headers,
        familyOnly: false,
        keyword: keyword,
        normalizedDocType: normalizedDocType,
        familyTaggedIds: familyTaggedIds,
      );
      final familyBundle = await _requestAndMapDocuments(
        url: url,
        headers: headers,
        familyOnly: true,
        keyword: keyword,
        normalizedDocType: normalizedDocType,
        familyTaggedIds: familyTaggedIds,
      );

      if (personalBundle == null && familyBundle == null) {
        setState(() {
          _error = 'Failed to load documents';
          _loading = false;
        });
        return;
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final doc in [
        ...?personalBundle?.docs,
        ...?familyBundle?.docs,
      ]) {
        final id = (doc['id'] ?? '').toString();
        final key = id.isEmpty
            ? '${doc['title']}_${doc['name']}_${doc['expiry_date']}'
            : id;
        byId[key] = doc;
      }
      final visibleMapped = byId.values.toList(growable: false);

      final personalStats = personalBundle?.stats;
      final familyStats = familyBundle?.stats;
      final mergedStats = _mergeDocumentStats(
        personal: personalStats,
        family: familyStats,
        visibleDocs: visibleMapped,
      );

      if (!mounted) return;
      setState(() {
        documents = visibleMapped;
        _statTotal = mergedStats['total'] ?? '-';
        _statActive = mergedStats['active'] ?? '-';
        _statRequested = mergedStats['requested'] ?? '-';
        _statExpiringSoon = mergedStats['expiringSoon'] ?? '-';
        _statExpired = mergedStats['expired'] ?? '-';
        _activeDocType =
            _isLocalActiveFilter(requestedFilter) ? 'active' : normalizedDocType;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      ApiLogger.logError(
        endpoint: '${UrlUtil.baseUrl}get_employee_documents',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<_DocsFetchBundle?> _requestAndMapDocuments({
    required Uri url,
    required Map<String, String> headers,
    required bool familyOnly,
    required String? keyword,
    required String? normalizedDocType,
    required Set<int> familyTaggedIds,
  }) async {
    final Map<String, dynamic> params = {
      'family_only': familyOnly,
      if (normalizedDocType != null) 'doc_type': normalizedDocType,
    };
    final body = jsonEncode({'jsonrpc': '2.0', 'params': params});

    ApiLogger.logRequest(
      endpoint: url.toString(),
      method: 'POST',
      headers: headers,
      body: body,
    );

    final startTime = DateTime.now();
    final response = await http.post(url, headers: headers, body: body);
    final duration = DateTime.now().difference(startTime);

    final data = jsonDecode(response.body);
    final resultEnvelope = (data is Map && data['result'] is Map)
        ? Map<String, dynamic>.from(data['result'] as Map)
        : (data is Map && data['status'] != null)
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
    final statusToken = _normalizeToken(resultEnvelope['status']);

    ApiLogger.logResponse(
      endpoint: url.toString(),
      statusCode: response.statusCode,
      responseBody: data,
      duration: duration,
    );

    if (response.statusCode != 200 ||
        (statusToken != 'success' &&
            statusToken != 'ok' &&
            statusToken != 'true')) {
      return null;
    }

    final resultData = resultEnvelope['data'];
    final List list = _extractDocumentGroups(resultData);

    String resolveIcon(String type, String name) {
      var icon = 'assets/png/other-documetns-icon.png';
      final t = type.toLowerCase();
      final n = name.toLowerCase();

      if (t.contains('pdf')) {
        icon = 'assets/png/pdf-icon.png';
      } else if (t.contains('certificate') || t.contains('cert')) {
        icon = 'assets/png/certificate-icon.png';
      } else if (t.contains('contract')) {
        icon = 'assets/png/contract-icon.png';
      } else if (t.contains('passport')) {
        icon = 'assets/png/passport.png';
      } else if (t.contains('emirates') ||
          t.contains('id') ||
          n.contains('emirates') ||
          n.contains('eid')) {
        icon = 'assets/png/emitates_id.png';
      } else if (t.contains('driving') ||
          t.contains('license') ||
          n.contains('driving') ||
          n.contains('license')) {
        icon = 'assets/png/driving_license.png';
      } else if (t.contains('insurance') || n.contains('insurance')) {
        icon = 'assets/png/personal-icon.png';
      } else if (t.contains('labor') || t.contains('labour')) {
        icon = 'assets/png/labor-cards-icon.png';
      } else if (t.contains('personal') || t.contains('profile')) {
        icon = 'assets/png/personal-icon.png';
      }

      return icon;
    }

    final mapped = <Map<String, dynamic>>[];

    for (final raw in list) {
      if (raw is! Map) continue;

      final group = Map<String, dynamic>.from(raw);
      final groupType =
          (group['document_type'] ?? group['type'] ?? '-').toString();
      final groupDocs = group['documents'];

      if (groupDocs is List && groupDocs.isNotEmpty) {
        for (final docRaw in groupDocs) {
          if (docRaw is! Map) continue;
          final map = Map<String, dynamic>.from(docRaw);
          mapped.add(_mapDocumentRow(
            map: map,
            group: group,
            groupType: groupType,
            familyOnly: familyOnly,
            familyTaggedIds: familyTaggedIds,
            resolveIcon: resolveIcon,
          ));
        }
      } else {
        mapped.add(_mapDocumentRow(
          map: group,
          group: group,
          groupType: groupType,
          familyOnly: familyOnly,
          familyTaggedIds: familyTaggedIds,
          resolveIcon: resolveIcon,
        ));
      }
    }

    final filteredMapped = keyword != null && keyword.trim().isNotEmpty
        ? mapped.where((d) {
            final title = (d['title'] ?? '').toString().toLowerCase();
            final name = (d['name'] ?? '').toString().toLowerCase();
            final searchTerm = keyword.toLowerCase();
            return title.contains(searchTerm) || name.contains(searchTerm);
          }).toList()
        : mapped;

    final stats = _buildDocumentsStats(
      resultEnvelope: resultEnvelope,
      resultData: resultData,
      visibleDocs: filteredMapped,
    );

    return _DocsFetchBundle(docs: filteredMapped, stats: stats);
  }

  Map<String, dynamic> _mapDocumentRow({
    required Map<String, dynamic> map,
    required Map<String, dynamic> group,
    required String groupType,
    required bool familyOnly,
    required Set<int> familyTaggedIds,
    required String Function(String type, String name) resolveIcon,
  }) {
    final type =
        (map['document_type'] ?? map['type'] ?? groupType).toString();
    final name = (map['name'] ?? '-').toString();
    final docIdInt = int.tryParse((map['id'] ?? '').toString());

    final resolvedIsFamily = familyOnly ||
        _isFamilyDoc(group) ||
        _isFamilyDoc(map) ||
        (docIdInt != null && familyTaggedIds.contains(docIdInt));

    final issueDate = _normalizeApiDate(DocumentDisplay.pickIssueRaw(map) ??
        map['issue_date'] ??
        map['issue'] ??
        map['date_issue']);
    final expiryDate = _normalizeApiDate(DocumentDisplay.pickExpiryRaw(map) ??
        map['expiry_date'] ??
        map['expiry'] ??
        map['date_expiry']);
    final statusRaw = (map['status'] ?? '').toString().trim().toLowerCase();
    final resolvedStatus = (statusRaw.isNotEmpty && statusRaw != 'unknown')
        ? statusRaw
        : _statusFromExpiry(expiryDate);

    return {
      'id': map['id'],
      'icon': resolveIcon(type, name),
      'title': type.toUpperCase(),
      'name': name,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'date_expiry': expiryDate,
      'description': map['description'],
      'status': resolvedStatus,
      'document_number': map['document_number'] ?? map['id_number'] ?? name,
      'attachment_ids': map['attachment_ids'] ??
          (map['attachment_id'] != null
              ? [
                  {
                    'attachment_id': map['attachment_id'],
                  }
                ]
              : []),
      'state': map['state'],
      'request_date': map['request_date'],
      'is_family': map['is_family'],
      'family_member': map['family_member'],
      'family_member_label': map['family_member_label'],
      'relation': map['relation'],
      'person_name': map['person_name'] ??
          map['family_member_name'] ??
          map['family_member'] ??
          map['employee'],
      'family_member_name': map['family_member_name'],
      'passport_no': map['passport_no'] ?? map['passport_number'],
      'eid_no': map['eid_no'] ?? map['emirates_id_no'],
      'id_number': map['id_number'] ??
          map['document_number'] ??
          map['document_no'] ??
          map['number'],
      'nationality': map['nationality'] ??
          map['family_member_nationality_id'] ??
          map['nationality_name'],
      'birth_date': map['birth_date'] ?? map['family_member_dob'],
      'passport_expiry_date': map['passport_expiry_date'] ?? expiryDate,
      'eid_expiry_date': map['eid_expiry_date'] ?? expiryDate,
      'photo': map['photo'],
      'image_url': map['image_url'] ?? map['photo_url'],
      'avatar': map['avatar'],
      'write_date': map['write_date'] ??
          map['updated_at'] ??
          map['writeDate'] ??
          map['create_date'],
      '_isFamily': resolvedIsFamily,
    };
  }

  String? _normalizeApiDate(dynamic raw) {
    if (raw == null || raw == false) return null;
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'null' || lower == 'none') return null;
    if (s.contains('T')) s = s.split('T').first;
    if (s.contains(' ')) s = s.split(' ').first;
    return s;
  }

  String _statusFromExpiry(String? expiryIso) {
    final parsed = DocumentDisplay.parseDate(expiryIso);
    if (parsed == null) return 'unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(parsed.year, parsed.month, parsed.day);
    final days = expiry.difference(today).inDays;
    if (days < 0) return 'expired';
    if (days <= 30) return 'expiring';
    return 'valid';
  }

  Map<String, String> _mergeDocumentStats({
    required Map<String, String>? personal,
    required Map<String, String>? family,
    required List<Map<String, dynamic>> visibleDocs,
  }) {
    int? parseStat(String? raw) {
      if (raw == null || raw == '-' || raw.trim().isEmpty) return null;
      return int.tryParse(raw.trim());
    }

    String sumOrDash(String? a, String? b) {
      final av = parseStat(a);
      final bv = parseStat(b);
      if (av == null && bv == null) return '-';
      return ((av ?? 0) + (bv ?? 0)).toString();
    }

    final totalMerged = sumOrDash(personal?['total'], family?['total']);
    final requestedMerged =
        sumOrDash(personal?['requested'], family?['requested']);
    final expiringMerged =
        sumOrDash(personal?['expiringSoon'], family?['expiringSoon']);
    final expiredMerged =
        sumOrDash(personal?['expired'], family?['expired']);

    // Prefer merged API counters; fall back to visible list length / dates.
    final fallback = _buildDocumentsStats(
      resultEnvelope: const {},
      resultData: const {},
      visibleDocs: visibleDocs,
    );

    return {
      'total': totalMerged == '-'
          ? visibleDocs.length.toString()
          : totalMerged,
      'requested':
          requestedMerged == '-' ? (fallback['requested'] ?? '-') : requestedMerged,
      'expiringSoon': expiringMerged == '-'
          ? (fallback['expiringSoon'] ?? '-')
          : expiringMerged,
      'expired':
          expiredMerged == '-' ? (fallback['expired'] ?? '-') : expiredMerged,
      'active': _resolveActiveCount(
        total: totalMerged == '-'
            ? visibleDocs.length.toString()
            : totalMerged,
        expired: expiredMerged == '-'
            ? (fallback['expired'] ?? '-')
            : expiredMerged,
        visibleDocs: visibleDocs,
        fallbackActive: fallback['active'],
      ),
    };
  }

  String _resolveActiveCount({
    required String total,
    required String expired,
    required List<Map<String, dynamic>> visibleDocs,
    String? fallbackActive,
  }) {
    final t = int.tryParse(total);
    final e = int.tryParse(expired);
    if (t != null && e != null) {
      return (t - e).clamp(0, t).toString();
    }
    if (fallbackActive != null && fallbackActive != '-') return fallbackActive;
    var active = 0;
    for (final doc in visibleDocs) {
      if (DocumentDisplay.status(doc) != DocumentStatus.expired) active++;
    }
    return active.toString();
  }

  List<dynamic> _extractDocumentGroups(dynamic resultData) {
    if (resultData is List) return resultData;
    if (resultData is Map) {
      final map = Map<String, dynamic>.from(resultData);
      final direct = map['documents'];
      if (direct is List) return direct;
      final groups = map['groups'];
      if (groups is List) return groups;
      final items = map['items'];
      if (items is List) return items;
    }
    return const [];
  }

  String _countOrDash(dynamic value) {
    if (value == null || value == false) return '-';
    if (value is num) return value.toInt().toString();
    final parsed = int.tryParse(value.toString().trim());
    return parsed == null ? '-' : parsed.toString();
  }

  dynamic _pickCountFromMaps(
      List<Map<String, dynamic>> maps, List<String> keys) {
    for (final map in maps) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null && map[key] != false) {
          return map[key];
        }
      }
    }
    return null;
  }

  Map<String, String> _buildDocumentsStats({
    required Map<String, dynamic> resultEnvelope,
    required dynamic resultData,
    required List<Map<String, dynamic>> visibleDocs,
  }) {
    final envelopeSummary = resultEnvelope['summary'] is Map<String, dynamic>
        ? resultEnvelope['summary'] as Map<String, dynamic>
        : (resultEnvelope['summary'] is Map
            ? Map<String, dynamic>.from(resultEnvelope['summary'] as Map)
            : <String, dynamic>{});

    final envelopeCounters = resultEnvelope['counters'] is Map<String, dynamic>
        ? resultEnvelope['counters'] as Map<String, dynamic>
        : (resultEnvelope['counters'] is Map
            ? Map<String, dynamic>.from(resultEnvelope['counters'] as Map)
            : <String, dynamic>{});

    final primary = resultData is Map<String, dynamic>
        ? resultData
        : (resultData is Map
            ? Map<String, dynamic>.from(resultData)
            : <String, dynamic>{});
    final counters = primary['counters'] is Map<String, dynamic>
        ? primary['counters'] as Map<String, dynamic>
        : <String, dynamic>{};
    final summary = primary['summary'] is Map<String, dynamic>
        ? primary['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    final totalRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['total', 'total_count', 'documents_count'],
    );
    final requestedRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['requested', 'requested_count', 'pending_count'],
    );
    final expiringSoonRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['expiring_soon', 'expiringSoon', 'expiring_soon_count'],
    );
    final expiredRaw = _pickCountFromMaps(
      [envelopeSummary, envelopeCounters, primary, counters, summary],
      ['expired', 'expired_count'],
    );

    final now = DateTime.now();
    var expiringSoonComputed = 0;
    var expiredComputed = 0;
    var activeComputed = 0;
    var hasDateData = false;
    for (final doc in visibleDocs) {
      final status = DocumentDisplay.status(doc);
      if (status != DocumentStatus.expired) activeComputed++;
      final raw = DocumentDisplay.pickExpiryRaw(doc) ?? doc['expiry_date'];
      if (raw == null || raw == false) continue;
      final s = raw.toString().trim();
      if (s.isEmpty) continue;
      final parsed = DateTime.tryParse(s);
      if (parsed == null) continue;
      hasDateData = true;
      final days = parsed.difference(now).inDays;
      if (days < 0) {
        expiredComputed++;
      } else if (days <= 30) {
        expiringSoonComputed++;
      }
    }

    final total = totalRaw != null
        ? _countOrDash(totalRaw)
        : visibleDocs.length.toString();
    final expired = expiredRaw != null
        ? _countOrDash(expiredRaw)
        : (hasDateData ? expiredComputed.toString() : '-');

    return {
      'total': total,
      'requested': _countOrDash(requestedRaw),
      'expiringSoon': expiringSoonRaw != null
          ? _countOrDash(expiringSoonRaw)
          : (hasDateData ? expiringSoonComputed.toString() : '-'),
      'expired': expired,
      'active': _resolveActiveCount(
        total: total,
        expired: expired,
        visibleDocs: visibleDocs,
        fallbackActive: activeComputed.toString(),
      ),
    };
  }

  List<Map<String, dynamic>> _filteredDocs() {
    Iterable<Map<String, dynamic>> docs = documents;
    if (_smartScope == 'personal') {
      docs = docs.where((d) => d['_isFamily'] != true);
    } else if (_smartScope == 'family') {
      docs = docs.where((d) => d['_isFamily'] == true);
    }
    if (_activeDocType == 'active') {
      docs = docs.where(
        (d) => DocumentDisplay.status(d) != DocumentStatus.expired,
      );
    }
    return docs.toList(growable: false);
  }

  String _toTitleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _formatCardDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final s = raw.toString().trim();
    if (s.isEmpty) return '-';
    try {
      final date = DateTime.parse(s);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '-';
    }
  }

  Widget _buildDocumentsSummaryCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: _buildTotalDocumentsMetallicCard(
                    value: _statTotal,
                    selected: _activeDocType == null && _smartScope == 'all',
                    onTap: () {
                      _applySmartChip(scope: 'all', docType: null);
                    },
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  flex: 9,
                  child: _buildActiveDocumentsCard(
                    value: _statActive,
                    selected: _activeDocType == 'active',
                    onTap: () {
                      _applySmartChip(scope: 'all', docType: 'active');
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.th),
          Row(
            children: [
              Expanded(
                child: _buildCategoryStatCard(
                  label: 'Expiring',
                  value: _statExpiringSoon,
                  icon: Icons.schedule_rounded,
                  accent: const Color(0xFFC47A12),
                  softFill: const Color(0xFFFFF1D9),
                  compact: true,
                  selected: _activeDocType == 'expiry_soon',
                  onTap: () {
                    _applySmartChip(scope: 'all', docType: 'expiry_soon');
                  },
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _buildCategoryStatCard(
                  label: 'Requested',
                  value: _statRequested,
                  icon: Icons.pending_actions_rounded,
                  accent: const Color(0xFF2F6AD8),
                  softFill: const Color(0xFFE3EDFF),
                  compact: true,
                  selected: _activeDocType == 'requested',
                  onTap: () {
                    _applySmartChip(scope: 'all', docType: 'requested');
                  },
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _buildCategoryStatCard(
                  label: 'Expired',
                  value: _statExpired,
                  icon: Icons.event_busy_rounded,
                  accent: const Color(0xFFC62828),
                  softFill: const Color(0xFFFFE5E5),
                  compact: true,
                  selected: _activeDocType == 'expired',
                  onTap: () {
                    _applySmartChip(scope: 'all', docType: 'expired');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDocumentsMetallicCard({
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const blueDeep = Color(0xFF3D7FDB);
    const blueMid = Color(0xFF5BA3EA);
    const blueLight = Color(0xFF7EC0F5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.tr),
            gradient: const LinearGradient(
              begin: Alignment(-0.95, -1),
              end: Alignment(0.9, 1.1),
              colors: [
                Color(0xFF4A8FE8),
                blueMid,
                blueLight,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.55 : 0.28),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: blueDeep.withValues(alpha: selected ? 0.38 : 0.22),
                blurRadius: selected ? 18 : 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.tr),
            child: Stack(
              children: [
                // Soft metallic sheen
                Positioned(
                  top: -28.th,
                  right: -18.tw,
                  child: Transform.rotate(
                    angle: -0.55,
                    child: Container(
                      width: 120.tw,
                      height: 90.th,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -10.tw,
                  bottom: -20.th,
                  child: Container(
                    width: 70.tw,
                    height: 70.tw,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                // Document watermark
                Positioned(
                  right: 6.tw,
                  bottom: -6.th,
                  child: Opacity(
                    opacity: 0.18,
                    child: Icon(
                      Icons.description_rounded,
                      size: 72.tsp,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: 22.tw,
                  bottom: 4.th,
                  child: Opacity(
                    opacity: 0.12,
                    child: Icon(
                      Icons.description_outlined,
                      size: 54.tsp,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.tw, 14.th, 12.tw, 14.th),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        size: 28.tsp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10.tw),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Total Documents',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            SizedBox(height: 4.th),
                            Text(
                              value,
                              style: GoogleFonts.poppins(
                                fontSize: 28.tsp,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30.tw,
                        height: 30.tw,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20.tsp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDocumentsCard({
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const green = Color(0xFF1F7A4D);
    const mint = Color(0xFFE7F6EE);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 10.tw, 12.th),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.tr),
            color: selected ? const Color(0xFFD5F0E2) : mint,
            border: Border.all(
              color: green.withValues(alpha: selected ? 0.45 : 0.16),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: selected ? 0.14 : 0.06),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28.tw,
                height: 28.tw,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 26.tsp,
                      color: green,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -1,
                      child: Container(
                        width: 14.tw,
                        height: 14.tw,
                        decoration: const BoxDecoration(
                          color: mint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14.tsp,
                          color: green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Active Documents',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w600,
                        color: green,
                      ),
                    ),
                    SizedBox(height: 2.th),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 24.tsp,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                    Text(
                      'Up to date',
                      style: GoogleFonts.poppins(
                        fontSize: 10.tsp,
                        fontWeight: FontWeight.w500,
                        color: green.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.tsp,
                color: green.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required Color softFill,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
    bool labelItalic = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            compact ? 10.tw : 16.tw,
            compact ? 12.th : 14.th,
            compact ? 10.tw : 16.tw,
            compact ? 12.th : 14.th,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.tr),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                softFill.withValues(alpha: selected ? 0.98 : 0.82),
                Colors.white.withValues(alpha: selected ? 0.72 : 0.48),
                accent.withValues(alpha: selected ? 0.16 : 0.08),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.55 : 0.22),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.18 : 0.08),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 22.tsp, color: accent),
                    SizedBox(height: 10.th),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            labelItalic ? FontStyle.italic : FontStyle.normal,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                    SizedBox(height: 4.th),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 22.tsp,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, size: 28.tsp, color: accent),
                    SizedBox(width: 12.tw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              fontWeight: FontWeight.w500,
                              fontStyle: labelItalic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: accent.withValues(alpha: 0.88),
                            ),
                          ),
                          SizedBox(height: 4.th),
                          Text(
                            value,
                            style: GoogleFonts.poppins(
                              fontSize: 28.tsp,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.tsp,
                      color: accent.withValues(alpha: 0.45),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDocumentsHeroHeader() {
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Documents',
                  style: GoogleFonts.poppins(
                    fontSize: 24.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2365),
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4.th),
                Text(
                  'Organize • Track • Stay Updated',
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7B8290),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.tw),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14.tr),
              border: Border.all(
                color: const Color(0xFF7EB6D9).withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28.tw,
                  height: 28.tw,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F0FF),
                    borderRadius: BorderRadius.circular(8.tr),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 16.tsp,
                    color: const Color(0xFF2F6AD8),
                  ),
                ),
                SizedBox(width: 8.tw),
                Text(
                  dateLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2365),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final hasActiveFilter =
        _smartScope != 'all' || (_activeDocType ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 4.th),
      child: Container(
        height: 48.th,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.78),
          border: Border.all(
            color: const Color(0xFF7EB6D9).withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            color: const Color(0xFF1F2933),
          ),
          cursorColor: const Color(0xFF2E8B57),
          decoration: InputDecoration(
            hintText: 'Search documents, people or keywords...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: const Color(0xFF7B8290),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20.tsp,
              color: const Color(0xFF5A6A5E),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasQuery)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => _searchController.clear(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.tsp,
                      color: const Color(0xFF7B8290),
                    ),
                  ),
                IconButton(
                  tooltip: 'Smart filters',
                  onPressed: _openSmartFilterSheet,
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 20.tsp,
                    color: hasActiveFilter
                        ? const Color(0xFF1F7A4D)
                        : const Color(0xFF5A6A5E),
                  ),
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.th),
          ),
        ),
      ),
    );
  }

  Future<void> _openSmartFilterSheet() async {
    final options = <({String label, String scope, String? docType, IconData icon})>[
      (label: 'All', scope: 'all', docType: null, icon: Icons.apps_rounded),
      (
        label: 'Personal',
        scope: 'personal',
        docType: null,
        icon: Icons.person_outline_rounded
      ),
      (
        label: 'Family',
        scope: 'family',
        docType: null,
        icon: Icons.family_restroom_rounded
      ),
      (
        label: 'Active',
        scope: 'all',
        docType: 'active',
        icon: Icons.verified_outlined
      ),
      (
        label: 'Expiring',
        scope: 'all',
        docType: 'expiry_soon',
        icon: Icons.schedule_rounded
      ),
      (
        label: 'Expired',
        scope: 'all',
        docType: 'expired',
        icon: Icons.event_busy_rounded
      ),
      (
        label: 'Requested',
        scope: 'all',
        docType: 'requested',
        icon: Icons.pending_actions_rounded
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 16.th),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22.tr),
                border: Border.all(
                  color: const Color(0xFF7EB6D9).withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.th),
                  Container(
                    width: 42.tw,
                    height: 4.th,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.tw, 14.th, 8.tw, 6.th),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter documents',
                            style: GoogleFonts.poppins(
                              fontSize: 16.tsp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E2365),
                            ),
                          ),
                        ),
                        if (_smartScope != 'all' ||
                            (_activeDocType ?? '').isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _applySmartChip(scope: 'all', docType: null);
                            },
                            child: Text(
                              'Clear',
                              style: GoogleFonts.poppins(
                                fontSize: 13.tsp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F7A4D),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...options.map((option) {
                    final selected = option.docType != null
                        ? _activeDocType == option.docType
                        : (_activeDocType == null &&
                            _smartScope == option.scope);
                    return ListTile(
                      leading: Icon(
                        option.icon,
                        color: selected
                            ? const Color(0xFF1F7A4D)
                            : const Color(0xFF5A6A5E),
                      ),
                      title: Text(
                        option.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? const Color(0xFF1B5E40)
                              : const Color(0xFF3B4352),
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: const Color(0xFF1F7A4D),
                              size: 20.tsp,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _applySmartChip(
                          scope: option.scope,
                          docType: option.docType,
                        );
                      },
                    );
                  }),
                  SizedBox(height: 8.th),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applySmartChip({
    required String scope,
    required String? docType,
  }) {
    final keyword = _searchController.text.trim();
    setState(() {
      if (docType != null) {
        _smartScope = 'all';
        _activeDocType = docType;
      } else {
        _smartScope = scope;
        _activeDocType = null;
      }
    });

    // Personal/Family are local filters — still refresh list with cleared API type.
    unawaited(_fetchMyDocuments(
      keyword: keyword.isEmpty ? null : keyword,
      docType: docType,
    ));
  }

  bool _isMeaningfulDocLabel(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.toLowerCase() == 'n/a') return false;
    // Avoid showing pure numeric IDs as the main label.
    if (RegExp(r'^\d+$').hasMatch(v)) return false;
    // Require at least one letter (Latin or Arabic).
    return RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(v);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.tw, vertical: 10.th),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42.tsp,
            color: const Color(0xFF3B4352),
          ),
          SizedBox(height: 6.th),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.tsp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3B4352),
            ),
          ),
          SizedBox(height: 6.th),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7B8290),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // @override
  // void initState() {
  //   super.initState();
  //   Future.delayed(const Duration(seconds: 5), () {
  //     if (mounted) showBabyGirlPopup(context);
  //   });
  // }

  // Tab chrome removed — unified personal + family documents list.

  void _onEdgeSwipeStart(DragStartDetails details) {
    if (!Platform.isIOS) return;
    _edgeSwipeStartX = details.globalPosition.dx;
    _isHandlingEdgeSwipeBack = false;
  }

  Future<void> _onEdgeSwipeUpdate(DragUpdateDetails details) async {
    if (!Platform.isIOS || _isHandlingEdgeSwipeBack) return;
    final startX = _edgeSwipeStartX;
    if (startX == null) return;

    final deltaX = details.globalPosition.dx - startX;
    if (deltaX < 72) return;

    _isHandlingEdgeSwipeBack = true;
    await Navigator.of(context).maybePop();
  }

  void _onEdgeSwipeEnd(DragEndDetails details) {
    _edgeSwipeStartX = null;
    _isHandlingEdgeSwipeBack = false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_activeDocType != null || _smartScope != 'all') {
          setState(() {
            _activeDocType = null;
            _smartScope = 'all';
            _loading = true;
            _error = null;
          });

          final keyword = _searchController.text.trim();
          unawaited(
            _fetchMyDocuments(
              keyword: keyword.isEmpty ? null : keyword,
              docType: null,
            ),
          );
          return false;
        }

        return true;
      },
      child: Stack(
        children: [
          MyDocumentsSilkBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  const ProductivityGlassHeader(
                    showBack: false,
                    transparentGlassBar: true,
                    scrimTopOpacity: 0.08,
                  ),
                  _buildDocumentsHeroHeader(),
                  ListenableBuilder(
                    listenable: _searchController,
                    builder: (context, _) => _buildTopSearchBar(),
                  ),
                  SizedBox(height: 6.th),
                  Expanded(child: _buildMyDocumentsContent()),
                ],
              ),
            ),
          ),
          if (Platform.isIOS)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 28,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onEdgeSwipeStart,
                onHorizontalDragUpdate: _onEdgeSwipeUpdate,
                onHorizontalDragEnd: _onEdgeSwipeEnd,
                onHorizontalDragCancel: () {
                  _edgeSwipeStartX = null;
                  _isHandlingEdgeSwipeBack = false;
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the unified documents content (personal + family).
  Widget _buildMyDocumentsContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildDocumentsSummaryCard(),
              SizedBox(height: 14.th),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.tw),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 14.tsp,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF3B4352),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.th),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.tw),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        label: 'Add New',
                        icon: Icons.add_circle_outline_rounded,
                        accent: const Color(0xFF1F7A4D),
                        softFill: const Color(0xFFDFF3E8),
                        onTap: () {
                          unawaited(_openAddDocumentWizard());
                        },
                      ),
                    ),
                    SizedBox(width: 10.tw),
                    Expanded(
                      child: _buildQuickActionButton(
                        label: 'View Family',
                        icon: Icons.family_restroom_rounded,
                        accent: const Color(0xFF2F6AD8),
                        softFill: const Color(0xFFE3EDFF),
                        onTap: _openFamilyDocumentsView,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.th),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.tw),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Documents',
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF3B4352),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAllDocumentsView,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2F6AD8),
                        padding: EdgeInsets.symmetric(horizontal: 8.tw),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View all',
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.th),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_recentDocuments().isEmpty)
                _buildEmptyState(
                  icon: Icons.folder_off_outlined,
                  title: 'No documents found',
                  subtitle: _searchController.text.trim().isEmpty
                      ? 'Use Quick Actions to add a document.'
                      : 'Try a different search term.',
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.tw),
                  child: Column(
                    children: [
                      for (final item in _recentDocuments()) ...[
                        _buildRecentDocumentPlaceholderRow(item),
                        SizedBox(height: 8.th),
                      ],
                    ],
                  ),
                ),
              SizedBox(height: 20.th),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _recentDocuments() {
    final docs = _filteredDocs();
    if (docs.length <= 5) return docs;
    return docs.take(5).toList(growable: false);
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color accent,
    required Color softFill,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          height: 56.th,
          padding: EdgeInsets.symmetric(horizontal: 12.tw),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.tr),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                softFill.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.55),
                accent.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20.tsp, color: accent),
              SizedBox(width: 8.tw),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Temporary recent-row chrome — list design TBD.
  Widget _buildRecentDocumentPlaceholderRow(Map<String, dynamic> item) {
    final title = DocumentDisplay.typeLabel(item);
    final isFamily = item['_isFamily'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (kDebugMode) {
            unawaited(_debugPrintDocumentTapApi(item));
          }
          _openDocumentDetails(item);
        },
        borderRadius: BorderRadius.circular(14.tr),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14.tr),
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: Row(
            children: [
              Image.asset(
                (item['icon'] ?? 'assets/png/other-documetns-icon.png')
                    .toString(),
                width: 28.tw,
                height: 28.tw,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.insert_drive_file_outlined,
                  size: 24.tsp,
                  color: const Color(0xFF5A6A5E),
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    SizedBox(height: 2.th),
                    Text(
                      isFamily ? 'Family' : 'Personal',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.tw),
              DocumentExpiryTrailing(document: item),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocumentDetails(Map<String, dynamic> document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(document: document),
      ),
    );
  }

  Future<void> _openAddDocumentWizard() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AddDocumentWizardScreen(),
      ),
    );
    if (!mounted) return;
    if (added == true) {
      final keyword = _searchController.text.trim();
      await _fetchMyDocuments(
        keyword: keyword.isEmpty ? null : keyword,
        docType: _activeDocType,
      );
    }
  }

  void _openAllDocumentsView() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DocumentsListViewPage(
          title: 'All Documents',
          emptyMessage: 'No documents found',
          documents: _filteredDocs(),
          onOpenDocument: _openDocumentDetails,
        ),
      ),
    );
  }

  void _openFamilyDocumentsView() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FamilyDocumentsScreen(),
      ),
    );
  }

  void showDocumentDialog(BuildContext context) async {
    _showDocumentDialogByType(DocumentDialogType.my);
  }

  Future<void> _showDocumentDialogByType(
    DocumentDialogType type, {
    String? fixedDocumentType,
    int? documentId,
  }) async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: DocumentDialog(
            type: type,
            fixedDocumentType: fixedDocumentType,
            documentId: documentId,
          ),
        );
      },
    );

    // If document was added successfully, refresh the list
    if (result == true) {
      print('🔄 Refreshing documents list...');
      final keyword = _searchController.text.trim();
      await _fetchMyDocuments(
        keyword: keyword.isEmpty ? null : keyword,
        docType: _activeDocType,
      );
    }
  }

  void _showDocumentDetailsDialog(
      BuildContext context, Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final hasAttachment = _firstAttachmentIdAsInt(document) != null;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      document['icon'] ?? 'assets/png/other-documetns-icon.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (document['title'] ?? '-').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff191F52),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Document Name
                _buildInfoRow(
                  icon: Icons.description,
                  label: 'Name',
                  value: (document['name'] ?? '-').toString(),
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),

                // ID Number
                if (document['id_number'] != null &&
                    document['id_number'] != false)
                  _buildInfoRow(
                    icon: Icons.numbers,
                    label: 'ID Number',
                    value: document['id_number'].toString(),
                    color: Colors.green,
                  ),
                if (document['id_number'] != null &&
                    document['id_number'] != false)
                  const SizedBox(height: 12),

                // Issue Date
                if (document['issue_date'] != null &&
                    document['issue_date'] != false)
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Issue Date',
                    value: _formatDate(document['issue_date'].toString()),
                    color: Colors.purple,
                  ),
                if (document['issue_date'] != null &&
                    document['issue_date'] != false)
                  const SizedBox(height: 12),

                // Expiry Date
                if (document['expiry_date'] != null &&
                    document['expiry_date'] != false)
                  _buildInfoRow(
                    icon: Icons.event,
                    label: 'Expiry Date',
                    value: _formatDate(document['expiry_date'].toString()),
                    color: _isExpired(document['expiry_date'].toString())
                        ? const Color(0xFFBA1719)
                        : Colors.orange,
                  ),
                if (document['expiry_date'] != null &&
                    document['expiry_date'] != false)
                  const SizedBox(height: 20),

                // View Attachment Button
                if (hasAttachment)
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF191F52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        unawaited(_openDocumentAttachment(document));
                      },
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      label: Text(
                        'VIEW ATTACHMENT',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (!hasAttachment)
                  const Center(
                    child: Text(
                      'No attachment available',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  bool _isExpired(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -0.8, // in radians (not degrees)
                child: const Icon(
                  Icons.attachment,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "ATTACHMENTS",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  //letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🔸 LPO No
          Row(
            children: [
              const Icon(Icons.tag, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                "LPO NO",
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔸 Vendor Name
          Row(
            children: [
              const Icon(Icons.handshake, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "VENDOR NAME",
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔸 Project Name
          Row(
            children: [
              const Icon(Icons.business_center, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                "PROJECT NAME",
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 🔘 Button
          Center(
            child: SizedBox(
              width: 180,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF191F52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: -0.8, // in radians (not degrees)
                      child: const Icon(
                        Icons.attachment,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "VIEW ATTACHMENT",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
//   void showBabyGirlPopup(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierColor: Colors.black.withAlpha((0.5 * 255).toInt()),
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.white.withAlpha((0.95 * 255).toInt()),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(28),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   "🎉 Congratulations ✨",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w800,
//                     color: Colors.black,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 10),
//                 const Text(
//                   "Congratulations to",
//                   style: TextStyle(fontSize: 13, color: Colors.black),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 5),
//                 const Text(
//                   "Eng. Hassan Abuebied",
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 14),
//                 const Text(
//                   "on the arrival of his baby girl! 🎀✨ Wishing her a life filled with love, joy, and endless blessings. May she bring happiness and prosperity to the family! 💖👶🏼",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 13,
//                     height: 1.5,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Image.asset(
//                   'assets/png/Baby_girl.png',
//                   height: 80,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
}

enum DocumentDialogType {
  my,
  family,
  company,
}

class DocumentDialog extends StatefulWidget {
  const DocumentDialog({
    super.key,
    required this.type,
    this.fixedDocumentType,
    this.documentId,
  });

  final DocumentDialogType type;
  final String? fixedDocumentType;

  /// Existing `hr.employee.document` id when updating (not Add New).
  final int? documentId;

  @override
  State<DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<DocumentDialog> {
  static const List<String> _fallbackTypes = [
    'Passport',
    'Labor Card',
    'Medical Insurance',
    'Emirates ID',
    'photo',
    'CV',
    'Certifications',
  ];

  // Safety fallback based on backend-provided document_types response.
  static const Map<String, int> _knownTypeIdsByNormalizedName = {
    'passport': 1,
    'emiratesid': 2,
    'laborcard': 3,
    'medicalinsurance': 4,
    'drivinglicense': 6,
    'visa': 10,
    'noc': 11,
    'contract': 89,
    'universitycertificate': 93,
    'cv': 94,
    'residence': 147,
    'photo': 172,
    'pension': 175,
    'family': 176,
  };

  final TextEditingController _idController = TextEditingController();
  DateTime? _expiryDate;
  String? _selectedType;
  final List<String> _types = <String>[];
  final Map<String, int> _documentTypeIds = <String, int>{};
  String? _attachedFileName;
  String? _attachedFilePath;
  bool _isUploading = false;
  bool _isLoadingTypes = false;

  bool get _showIdAndExpiry => widget.type != DocumentDialogType.company;
  bool get _familyOnly => widget.type == DocumentDialogType.family;
  bool get _hasFixedDocumentType =>
      (widget.fixedDocumentType ?? '').trim().isNotEmpty;
  bool get _isUpdate => (widget.documentId ?? 0) > 0;
  String get _fixedDocumentType => (widget.fixedDocumentType ?? '').trim();

  String get _dialogTitle {
    if (_hasFixedDocumentType) return 'Update Documents';

    switch (widget.type) {
      case DocumentDialogType.family:
        return 'Family Documents';
      case DocumentDialogType.company:
        return 'Company Documents';
      case DocumentDialogType.my:
      default:
        return 'My Documents';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_hasFixedDocumentType) {
      _selectedType = _fixedDocumentType;
      _types.add(_fixedDocumentType);
    }

    if (widget.type == DocumentDialogType.company) {
      if (_hasFixedDocumentType) return;
      _types.addAll(_fallbackTypes);
      _selectedType = _types.isNotEmpty ? _types.first : null;
    } else {
      unawaited(_loadDocumentTypes());
    }
  }

  void _addDocumentTypeFromRaw(
    dynamic raw,
    List<String> names,
    Map<String, int> idsByName,
  ) {
    if (raw is String) {
      final name = raw.trim();
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
      return;
    }

    if (raw is! Map) return;

    final map = Map<String, dynamic>.from(raw as Map);
    final name = (map['name'] ??
            map['document_type'] ??
            map['type'] ??
            map['label'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) return;

    if (!names.contains(name)) {
      names.add(name);
    }

    final idRaw = map['id'] ?? map['document_type_id'] ?? map['type_id'];
    final id = int.tryParse((idRaw ?? '').toString());
    if (id != null) {
      idsByName[name] = id;
    }
  }

  Future<void> _loadDocumentTypes() async {
    if (_isLoadingTypes) return;
    if (mounted) {
      setState(() => _isLoadingTypes = true);
    }

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return;

      final url = Uri.parse('${UrlUtil.baseUrl}document_types');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'family_only': _familyOnly,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return;
      }

      final names = <String>[];
      final idsByName = <String, int>{};
      final data = result['data'];

      if (data is List) {
        for (final item in data) {
          _addDocumentTypeFromRaw(item, names, idsByName);
        }
      } else if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value;

          if (value is Map || value is String) {
            _addDocumentTypeFromRaw(value, names, idsByName);
            continue;
          }

          final keyAsId = int.tryParse(key);
          final valueText = (value ?? '').toString().trim();
          final valueAsId = int.tryParse(valueText);

          if (keyAsId != null && valueText.isNotEmpty) {
            if (!names.contains(valueText)) {
              names.add(valueText);
            }
            idsByName[valueText] = keyAsId;
            continue;
          }

          if (valueAsId != null && key.isNotEmpty) {
            if (!names.contains(key)) {
              names.add(key);
            }
            idsByName[key] = valueAsId;
          }
        }
      }

      if (!mounted || names.isEmpty) return;
      setState(() {
        if (!_hasFixedDocumentType) {
          _types
            ..clear()
            ..addAll(names);
        }
        _documentTypeIds
          ..clear()
          ..addAll(idsByName);

        if (_hasFixedDocumentType) {
          _selectedType = _fixedDocumentType;
        } else if (_selectedType == null || !_types.contains(_selectedType)) {
          _selectedType = _types.first;
        }
      });
    } catch (e) {
      debugPrint('Failed to load document types: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTypes = false;
          if (_hasFixedDocumentType) {
            _selectedType = _fixedDocumentType;
            if (_types.isEmpty) {
              _types.add(_fixedDocumentType);
            }
            return;
          }
          if (_types.isEmpty) {
            _types.addAll(_fallbackTypes);
          }
          if (_selectedType == null && _types.isNotEmpty) {
            _selectedType = _types.first;
          } else if (_selectedType != null &&
              _types.isNotEmpty &&
              !_types.contains(_selectedType)) {
            _selectedType = _types.first;
          }
        });
      }
    }
  }

  int? _findDocumentTypeIdLocally(String selectedType) {
    if (selectedType.trim().isEmpty) return null;

    final direct = _documentTypeIds[selectedType];
    if (direct != null) return direct;

    final selectedToken = _normalizeToken(selectedType);
    for (final entry in _documentTypeIds.entries) {
      if (_normalizeToken(entry.key) == selectedToken) {
        return entry.value;
      }
    }

    // Fallback when dropdown is available but ids map is temporarily empty.
    final known = _knownTypeIdsByNormalizedName[selectedToken];
    if (known != null) return known;

    return null;
  }

  Future<int?> _resolveDocumentTypeId(String selectedType) async {
    var id = _findDocumentTypeIdLocally(selectedType);
    if (id != null) return id;

    // Try refreshing types once in case dropdown data arrived without ids.
    await _loadDocumentTypes();
    id = _findDocumentTypeIdLocally(selectedType);
    if (id != null) return id;

    // Final fallback: query API directly and resolve by normalized name.
    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return null;

      final url = Uri.parse('${UrlUtil.baseUrl}document_types');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'family_only': _familyOnly,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return null;
      }

      final names = <String>[];
      final idsByName = <String, int>{};
      final data = result['data'];

      if (data is List) {
        for (final item in data) {
          _addDocumentTypeFromRaw(item, names, idsByName);
        }
      } else if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value;

          if (value is Map || value is String) {
            _addDocumentTypeFromRaw(value, names, idsByName);
            continue;
          }

          final keyAsId = int.tryParse(key);
          final valueText = (value ?? '').toString().trim();
          final valueAsId = int.tryParse(valueText);

          if (keyAsId != null && valueText.isNotEmpty) {
            if (!names.contains(valueText)) {
              names.add(valueText);
            }
            idsByName[valueText] = keyAsId;
            continue;
          }

          if (valueAsId != null && key.isNotEmpty) {
            if (!names.contains(key)) {
              names.add(key);
            }
            idsByName[key] = valueAsId;
          }
        }
      }

      if (idsByName.isNotEmpty && mounted) {
        setState(() {
          _documentTypeIds
            ..clear()
            ..addAll(idsByName);
          if (names.isNotEmpty) {
            _types
              ..clear()
              ..addAll(names);
            if (_selectedType == null || !_types.contains(_selectedType)) {
              _selectedType = _types.first;
            }
          }
        });
      }

      return _findDocumentTypeIdLocally(selectedType);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 50)),
      lastDate: DateTime(now.year + 50),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.blueGrey, // header background
            onPrimary: Colors.white, // header text
            onSurface: Colors.black, // body text
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFileName = result.files.single.name;
          _attachedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isUploadSuccess(dynamic decodedBody) {
    if (decodedBody is! Map) return false;

    final result = decodedBody['result'];
    if (result is! Map) return false;

    final statusRaw = result['status'];
    final successRaw = result['success'];

    final statusToken = _normalizeToken(statusRaw);
    if (statusToken == 'success' ||
        statusToken == 'ok' ||
        statusToken == 'true') {
      return true;
    }

    if (successRaw is bool) return successRaw;
    final successToken = _normalizeToken(successRaw);
    return successToken == '1' ||
        successToken == 'true' ||
        successToken == 'success';
  }

  String _safeAttachmentFilename({
    required String selectedType,
    String? pickedName,
    String? pickedPath,
  }) {
    final direct = (pickedName ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final path = (pickedPath ?? '').trim();
    final fileNameFromPath =
        path.isNotEmpty ? path.split(Platform.pathSeparator).last : '';
    if (fileNameFromPath.isNotEmpty) return fileNameFromPath;

    final normalizedType = selectedType.trim().isEmpty
        ? 'document'
        : selectedType.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    return '$normalizedType.pdf';
  }

  String _extractUploadMessage(dynamic decodedBody) {
    if (decodedBody is! Map) return 'Upload failed';

    final result = decodedBody['result'];
    if (result is Map) {
      final message = result['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    final error = decodedBody['error'];
    if (error is Map) {
      final errorData = error['data'];
      if (errorData is Map) {
        final dataMessage = errorData['message']?.toString();
        if (dataMessage != null && dataMessage.trim().isNotEmpty) {
          return dataMessage.trim();
        }

        final debugText = errorData['debug']?.toString() ?? '';
        final parsedDebugMessage =
            _extractValidationMessageFromDebug(debugText);
        if (parsedDebugMessage.isNotEmpty) {
          return parsedDebugMessage;
        }
      }

      final errorMessage = error['message']?.toString();
      if (errorMessage != null && errorMessage.trim().isNotEmpty) {
        return errorMessage.trim();
      }
    }

    return 'Upload failed';
  }

  String _extractValidationMessageFromDebug(String debugText) {
    final text = debugText.trim();
    if (text.isEmpty) return '';

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (final line in lines.reversed) {
      if (line.startsWith('ValidationError:')) {
        return line.replaceFirst('ValidationError:', '').trim();
      }
      if (line.startsWith('Exception:')) {
        return line.replaceFirst('Exception:', '').trim();
      }
    }

    return '';
  }

  int? _extractUploadedDocumentId(dynamic decodedBody) {
    if (decodedBody is! Map) return null;
    final result = decodedBody['result'];
    if (result is! Map) return null;

    final raw = result['document_id'] ?? result['id'] ?? result['record_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _targetCollectionLabel() {
    switch (widget.type) {
      case DocumentDialogType.family:
        return 'Family Documents';
      case DocumentDialogType.company:
        return 'Company Documents';
      case DocumentDialogType.my:
      default:
        return 'My Documents';
    }
  }

  List<Map<String, dynamic>> _extractDocumentMaps(List<dynamic> rawGroups) {
    final docs = <Map<String, dynamic>>[];

    for (final groupRaw in rawGroups) {
      if (groupRaw is! Map) continue;
      final group = Map<String, dynamic>.from(groupRaw);

      final nested = group['documents'];
      if (nested is List && nested.isNotEmpty) {
        for (final item in nested) {
          if (item is Map) {
            docs.add(Map<String, dynamic>.from(item));
          }
        }
      } else {
        docs.add(group);
      }
    }

    return docs;
  }

  String _attachmentSignature(dynamic attachmentIds) {
    if (attachmentIds is List && attachmentIds.isNotEmpty) {
      final values = attachmentIds
          .map((e) {
            if (e is Map) {
              return (e['attachment_id'] ?? e['id'] ?? e['attachmentId'])
                  .toString();
            }
            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false)
        ..sort();
      return values.join(',');
    }

    if (attachmentIds is Map) {
      return (attachmentIds['attachment_id'] ??
              attachmentIds['id'] ??
              attachmentIds['attachmentId'] ??
              '')
          .toString();
    }

    return (attachmentIds ?? '').toString();
  }

  Set<String> _buildDocumentFingerprints(List<dynamic> rawGroups) {
    final docs = _extractDocumentMaps(rawGroups);
    final fingerprints = <String>{};

    for (final doc in docs) {
      final id = (doc['id'] ?? '').toString();
      final type = _normalizeToken(doc['document_type'] ?? doc['type']);
      final name = _normalizeToken(doc['name']);
      final idNumber = _normalizeToken(doc['id_number']);
      final attachment = _normalizeToken(
        _attachmentSignature(doc['attachment_ids']) +
            (doc['attachment_name'] ?? doc['attachment_filename'] ?? '')
                .toString(),
      );
      final updatedAt = _normalizeToken(
        doc['write_date'] ?? doc['updated_at'] ?? doc['create_date'],
      );

      fingerprints.add('$id|$type|$name|$idNumber|$attachment|$updatedAt');
    }

    return fingerprints;
  }

  Future<Set<String>?> _snapshotDocumentsBeforeUpload({
    required String token,
  }) async {
    final url = Uri.parse('${UrlUtil.baseUrl}get_employee_documents');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final familyOnly = widget.type == DocumentDialogType.family;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'family_only': familyOnly,
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final statusToken = _normalizeToken(result['status']);
      if (!(statusToken == 'success' ||
          statusToken == 'ok' ||
          statusToken == 'true')) {
        return null;
      }

      final dataList = result['data'];
      if (dataList is! List) return null;

      return _buildDocumentFingerprints(dataList);
    } catch (_) {
      return null;
    }
  }

  bool _containsUploadedDocument(
    List<dynamic> rawGroups, {
    required String selectedType,
    required String idNumber,
    required String attachmentFileName,
    int? uploadedDocumentId,
  }) {
    final selectedTypeToken = _normalizeToken(selectedType);
    final idNumberToken = _normalizeToken(idNumber);
    final attachmentToken = _normalizeToken(attachmentFileName);

    for (final groupRaw in rawGroups) {
      if (groupRaw is! Map) continue;
      final group = Map<String, dynamic>.from(groupRaw);

      final dynamic nested = group['documents'];
      final docs = <Map<String, dynamic>>[];
      if (nested is List && nested.isNotEmpty) {
        for (final item in nested) {
          if (item is Map) {
            docs.add(Map<String, dynamic>.from(item));
          }
        }
      } else {
        docs.add(group);
      }

      for (final doc in docs) {
        final docId = int.tryParse((doc['id'] ?? '').toString());
        if (uploadedDocumentId != null && docId == uploadedDocumentId) {
          return true;
        }

        final typeToken = _normalizeToken(doc['document_type'] ?? doc['type']);
        final nameToken = _normalizeToken(doc['name']);
        final idToken = _normalizeToken(doc['id_number']);
        final attachmentNameToken = _normalizeToken(
          doc['attachment_name'] ??
              doc['attachment_filename'] ??
              doc['file_name'],
        );

        final typeMatch = selectedTypeToken.isEmpty
            ? true
            : (typeToken == selectedTypeToken ||
                typeToken.contains(selectedTypeToken) ||
                selectedTypeToken.contains(typeToken));

        final idMatch = idNumberToken.isEmpty
            ? true
            : (idToken == idNumberToken || nameToken == idNumberToken);

        final attachmentMatch = attachmentToken.isEmpty
            ? false
            : (attachmentNameToken == attachmentToken ||
                attachmentNameToken.contains(attachmentToken));

        if ((typeMatch && idMatch) || attachmentMatch) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> _verifyDocumentAdded({
    required String token,
    required String selectedType,
    required String idNumber,
    required String attachmentFileName,
    int? uploadedDocumentId,
    Set<String>? beforeFingerprints,
  }) async {
    final url = Uri.parse('${UrlUtil.baseUrl}get_employee_documents');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final bool familyOnly = widget.type == DocumentDialogType.family;
    final scopesToCheck = <bool>[familyOnly];

    for (var attempt = 0; attempt < 3; attempt++) {
      for (final scope in scopesToCheck) {
        final body = jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'family_only': scope,
          },
        });

        try {
          final response = await http.post(url, headers: headers, body: body);
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is! Map) continue;

            final result = (decoded['result'] is Map)
                ? Map<String, dynamic>.from(decoded['result'] as Map)
                : (decoded['status'] != null)
                    ? Map<String, dynamic>.from(decoded)
                    : <String, dynamic>{};
            final statusToken = _normalizeToken(result['status']);
            final statusOk = statusToken == 'success' ||
                statusToken == 'ok' ||
                statusToken == 'true';
            final dataList = result['data'];
            if (statusOk && dataList is List) {
              final afterFingerprints = _buildDocumentFingerprints(dataList);
              if (beforeFingerprints != null && beforeFingerprints.isNotEmpty) {
                final hasDelta = afterFingerprints.any(
                    (fingerprint) => !beforeFingerprints.contains(fingerprint));
                if (hasDelta) {
                  return true;
                }
              }

              final found = _containsUploadedDocument(
                dataList,
                selectedType: selectedType,
                idNumber: idNumber,
                attachmentFileName: attachmentFileName,
                uploadedDocumentId: uploadedDocumentId,
              );
              if (found) {
                return true;
              }
            }
          }
        } catch (_) {
          // Retry a couple of times to allow backend processing delay.
        }
      }

      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }

    return false;
  }

  Future<void> _submit() async {
    // Validate required fields
    final id = _idController.text.trim();
    final selectedType = (_selectedType ?? '').trim();
    if (selectedType.isEmpty) {
      debugPrint('⛔ Upload stopped: selectedType is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please select document type.');
      return;
    }
    if (_showIdAndExpiry && id.isEmpty) {
      debugPrint('⛔ Upload stopped: ID number is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please fill in ID number.');
      return;
    }
    if ((_attachedFilePath ?? '').isEmpty) {
      debugPrint('⛔ Upload stopped: attachment path is empty');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please attach a file.');
      return;
    }
    if (_showIdAndExpiry && _isUpdate && _expiryDate == null) {
      debugPrint('⛔ Update stopped: expiry date missing');
      _sliderKey.currentState?.resetSlider();
      _showErrorDialog('Please select a new expiry date.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      final url =
          Uri.parse('${UrlUtil.baseUrl}upload_employee_document');

      // Debug: Check values before sending
      print('🔍 Debug - selectedType: "$selectedType"');
      print('🔍 Debug - id: "$id"');

      if (token.isEmpty) {
        print('❌ Error: auth token is empty!');
        debugPrint('⛔ Upload stopped: auth token is empty');
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog('Session expired. Please login again.');
        return;
      }

      final beforeFingerprints =
          await _snapshotDocumentsBeforeUpload(token: token);

      if (selectedType.isEmpty) {
        print('❌ Error: selectedType is null or empty!');
        debugPrint('⛔ Upload stopped: selectedType became empty unexpectedly');
        return;
      }

      final documentTypeId = await _resolveDocumentTypeId(selectedType);
      debugPrint(
          '🔎 Resolved documentTypeId for "$selectedType": $documentTypeId');
      debugPrint(
          '🔎 Current document type map size: ${_documentTypeIds.length}');
      if (documentTypeId == null) {
        debugPrint('⛔ Upload stopped: could not resolve document_type_id');
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog(
          'document_type_id is missing for "$selectedType". Please refresh document types and try again.',
        );
        return;
      }

      // Read file and convert to base64
      final file = File(_attachedFilePath!);
      debugPrint('📎 Upload file path: ${file.path}');
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      debugPrint('📎 Upload file size bytes: ${bytes.length}');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final attachmentFilename = _safeAttachmentFilename(
        selectedType: selectedType,
        pickedName: _attachedFileName,
        pickedPath: _attachedFilePath,
      );
      debugPrint('📎 attachment_filename used: $attachmentFilename');

      final params = <String, dynamic>{
        'name': selectedType,
        'description': 'Uploaded from mobile app',
        'attachment': base64File,
        'attachment_filename': attachmentFilename,
        'family_only': _familyOnly,
      };

      params['document_type_id'] = documentTypeId;

      final existingDocumentId = widget.documentId;
      if (existingDocumentId != null && existingDocumentId > 0) {
        params['document_id'] = existingDocumentId;
      }

      final selectedDate = _expiryDate?.toIso8601String().split('T')[0];
      if (selectedDate != null && selectedDate.isNotEmpty) {
        // Expiry only — previously both issue_date and expiry_date were set to
        // the same value, which corrupted issue dates and confused status.
        params['expiry_date'] = selectedDate;
      }

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'params': params,
      });

      print('📤 Uploading document...');
      final safeDebugParams = Map<String, dynamic>.from(params);
      if (safeDebugParams.containsKey('attachment')) {
        final len = safeDebugParams['attachment']?.toString().length ?? 0;
        safeDebugParams['attachment'] = '[base64 omitted, length=$len]';
      }
      print('📦 Request params: ${jsonEncode(safeDebugParams)}');
      debugPrint('🚀 Upload HTTP POST started: ${url.toString()}');
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      print('📥 Upload response: ${response.body}');

      final isSuccess = response.statusCode == 200 && _isUploadSuccess(data);
      if (!isSuccess) {
        final errorMessage = _extractUploadMessage(data);
        if (mounted) {
          _sliderKey.currentState?.resetSlider();
          _showErrorDialog(errorMessage);
        }
        return;
      }

      final uploadedDocumentId = _extractUploadedDocumentId(data);
      if (widget.type == DocumentDialogType.family &&
          uploadedDocumentId != null) {
        await _tagDocumentAsFamily(uploadedDocumentId);
      }

      final appearsInList = await _verifyDocumentAdded(
        token: token,
        selectedType: selectedType,
        idNumber: id,
        attachmentFileName: _attachedFileName ?? '',
        uploadedDocumentId: uploadedDocumentId,
        beforeFingerprints: beforeFingerprints,
      );

      if (!appearsInList) {
        if (mounted) {
          _sliderKey.currentState?.resetSlider();
          _showErrorDialog(
            'Upload response was successful, but the document did not appear in ${_targetCollectionLabel()}. Please try again.',
          );
        }
        return;
      }

      print('✅ Document uploaded and verified in list!');
      if (mounted) {
        _showSuccessDialog(message: _extractUploadMessage(data));
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        _sliderKey.currentState?.resetSlider();
        _showErrorDialog('An error occurred while uploading the document.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSuccessDialog({String? message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Document uploaded successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context)
                  .pop(true); // Close DocumentDialog and refresh
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    // Keep the current dialog open; show an error dialog over it.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  final GlobalKey<CustomSliderButtonState> _sliderKey = GlobalKey();
  Future<void> _submitExpense() async {
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final expiryText = _expiryDate == null
        ? 'Expiry date'
        : DateFormat.yMMMd().format(_expiryDate!);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18.tw, vertical: 18.th),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.tr),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF717171),
                const Color(0xFF1B1F26).withOpacity(0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30.th,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        _dialogTitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.tsp,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6.tw,
                      top: -4.th,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: BorderRadius.circular(18.tr),
                        child: Container(
                          width: 30.tw,
                          height: 30.tw,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: const Color(0xFF1B1F26),
                            size: 22.tsp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _hasFixedDocumentType ? 6.th : (_showIdAndExpiry ? 14.th : 28.th)),

              // Document type dropdown (hidden when a fixed type is pre-selected).
              if (!_hasFixedDocumentType)
                _buildPillField(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          value: _selectedType,
                          isExpanded: true,
                          hint: Center(
                            child: Text(
                              _isLoadingTypes && _types.isEmpty
                                  ? 'Loading document types...'
                                  : 'document type',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          items: _types
                              .map(
                                (t) => DropdownMenuItem<String>(
                                  value: t,
                                  child: Center(
                                    child: Text(
                                      t,
                                      overflow: TextOverflow.visible,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontSize: 12.tsp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoadingTypes && _types.isEmpty
                              ? null
                              : (v) => setState(() => _selectedType = v),
                          // Keep the pill container as the button background.
                          buttonStyleData: ButtonStyleData(
                            height: 30.th,
                            padding: EdgeInsets.symmetric(horizontal: 4.tw),
                            decoration:
                                const BoxDecoration(color: Colors.transparent),
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(Icons.keyboard_arrow_down_rounded),
                            iconSize: 20,
                            iconEnabledColor: Colors.grey,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            maxHeight: 260.th,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.tr),
                              color: Colors.white,
                            ),
                            offset: const Offset(0, -4),
                            scrollbarTheme: ScrollbarThemeData(
                              radius: const Radius.circular(40),
                              thickness: WidgetStateProperty.all(6),
                              thumbVisibility: WidgetStateProperty.all(true),
                            ),
                          ),
                          menuItemStyleData: MenuItemStyleData(
                            height: 44.th,
                            padding: EdgeInsets.symmetric(horizontal: 12.tw),
                          ),
                        ),
                      ),
                    ),
              SizedBox(height: _hasFixedDocumentType ? 0 : (_showIdAndExpiry ? 14.th : 40.th)),

              if (_showIdAndExpiry) ...[
                SizedBox(height: 10.th),
                _buildPillField(
                  child: TextField(
                    controller: _idController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      color: Colors.black87,
                    ),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'ID Number',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ),
                SizedBox(height: 10.th),
                GestureDetector(
                  onTap: _pickDate,
                  child: _buildPillField(
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              expiryText,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                color: _expiryDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 14.th),

              InkWell(
                onTap: _pickFile,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _attachedFileName == null
                              ? 'Attach  Files'
                              : _attachedFileName!,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.tsp,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.th),
                    Container(
                      height: 1.2,
                      width: 120.tw,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.th),

              CustomSliderButton(
                key: _sliderKey,
                onSlideComplete: _submitExpense,
                loginResponseModel: SharedPref.getLoginData(),
                enableProgressColor: false,
                idleGradient: const LinearGradient(
                  colors: [Color(0xFFF2F2F2), Color(0xFFE6E6E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                completedGradient: const LinearGradient(
                  colors: [Color(0xFFBDBDBD), Color(0xFFB0B0B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                idleBorderColor: Color(0x00000000),
                completedBorderColor: Color(0x00000000),
                idleLabelColor: Color(0xFF8A8A8A),
                completedLabelColor: Color(0xFF4A4A4A),
                idleHandleColor: Color(0xFF4A4A4A),
                completedHandleColor: Color(0xFF4A4A4A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillField({required Widget child}) {
    return Container(
      height: 30.th,
      padding: EdgeInsets.symmetric(horizontal: 14.tw),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.tr),
      ),
      child: Center(child: child),
    );
  }
}



class _DocumentsListViewPage extends StatelessWidget {
  const _DocumentsListViewPage({
    required this.title,
    required this.emptyMessage,
    required this.documents,
    required this.onOpenDocument,
  });

  final String title;
  final String emptyMessage;
  final List<Map<String, dynamic>> documents;
  final void Function(Map<String, dynamic> document) onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return MyDocumentsSilkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ProductivityGlassHeader(
              title: title,
              showBack: true,
              transparentGlassBar: true,
              scrimTopOpacity: 0.08,
            ),
            Expanded(
              child: documents.isEmpty
                  ? Center(
                      child: Text(
                        emptyMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF7B8290),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: documents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = documents[index];
                        final typeLabel = DocumentDisplay.typeLabel(item);
                        final isFamily = item['_isFamily'] == true;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onOpenDocument(item),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFD9D9D9)),
                              ),
                              child: Row(
                                children: [
                                  Image.asset(
                                    (item['icon'] ??
                                            'assets/png/other-documetns-icon.png')
                                        .toString(),
                                    width: 28,
                                    height: 28,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.insert_drive_file_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          typeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isFamily ? 'Family' : 'Personal',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(0xFF7B8290),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DocumentExpiryTrailing(document: item),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocsFetchBundle {
  const _DocsFetchBundle({
    required this.docs,
    required this.stats,
  });

  final List<Map<String, dynamic>> docs;
  final Map<String, String> stats;
}
