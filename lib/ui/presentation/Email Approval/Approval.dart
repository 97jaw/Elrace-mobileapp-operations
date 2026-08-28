import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/data/delayed_approvals_repository.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/models/delayed_approval_model.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/all_approvals_overview.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/hr_and_pettycash_card.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/invoice_and_rfq_card.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/ui/navigation/home_navigation.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  static final _countCache = _ApprovalsCountCache();
  static const List<_HrManagementTestCase> _hrManagementTestCases = [
    _HrManagementTestCase(id: 35849, title: 'Sick'),
    _HrManagementTestCase(id: 35651, title: 'Short'),
    _HrManagementTestCase(id: 35847, title: 'Job Mission'),
    _HrManagementTestCase(id: 35564, title: 'Temporary Permission'),
    _HrManagementTestCase(id: 35841, title: 'Clearance'),
    _HrManagementTestCase(id: 35837, title: 'Effective Date'),
    _HrManagementTestCase(id: 34068, title: 'Certificate Request'),
    _HrManagementTestCase(id: 32938, title: 'Loan'),
    _HrManagementTestCase(id: 33800, title: 'Salary Increment'),
    _HrManagementTestCase(id: 18915, title: 'Parental'),
    _HrManagementTestCase(id: 31615, title: 'Resign'),
    _HrManagementTestCase(id: 25165, title: 'Termination'),
    _HrManagementTestCase(id: 31875, title: 'Transfer'),
    _HrManagementTestCase(id: 30388, title: 'Passport'),
    _HrManagementTestCase(id: 35803, title: 'Leave Encashment'),
    _HrManagementTestCase(id: 33244, title: 'Car Rent'),
    _HrManagementTestCase(id: 24602, title: 'Maternity'),
    _HrManagementTestCase(id: 35842, title: 'Annual'),
    _HrManagementTestCase(id: 32312, title: 'Promotion'),
  ];

  String selectedCategoryKey = _CategoryKeys.all;
  TextEditingController searchController = TextEditingController();
  List<dynamic> hrItems = [];
  List<dynamic> rfqItems = [];
  List<dynamic> invoiceItems = [];
  List<dynamic> pettyCashItems = [];
  List<dynamic> allItems = [];
  List<dynamic> approvalItems = [];
  String error = '';

  // Per-category loading/loaded/error state — no full-screen blocking loader
  final Map<String, bool> _categoryLoading = {};
  final Map<String, bool> _categoryLoaded = {};
  Map<String, String> categoryErrors = {};

  // Delayed requests count from API
  int delayedCount = 0;
  DelayedCountersResponse? _delayedCounters;
  DelayedRorResponse? _rorData;
  bool _rorLoading = false;
  late int _rorMonth;
  late int _rorYear;
  final DelayedApprovalsRepository _delayedRepo = DelayedApprovalsRepository();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rorMonth = now.month;
    _rorYear = now.year;
    selectedCategoryKey = categoryKeys.first;
    searchController.addListener(_onSearchChanged);
    // Show the screen immediately — load all categories in background in parallel.
    // Delayed count is also fired in background.
    _loadAllCategoriesInBackground();
    _fetchDelayedCount();
    _fetchRorData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      approvalItems = _getFilteredItems();
    });
  }

  List<dynamic> _getFilteredItems() {
    final allFiltered = _getApprovalListForSelectedCategory();
    if (searchController.text.isEmpty) {
      return allFiltered;
    }

    final searchLower = searchController.text.toLowerCase();
    return allFiltered.where((item) {
      final name = item["name"]?.toString().toLowerCase() ?? "";
      final requestNo = item["request_no"]?.toString().toLowerCase() ?? "";
      final reqNo = item["req_no"]?.toString().toLowerCase() ?? "";
      final title = item["title"]?.toString().toLowerCase() ?? "";
      final employeeName =
          item["employee_name"]?.toString().toLowerCase() ?? "";
      final vendor = item["vendor"]?.toString().toLowerCase() ?? "";

      return name.contains(searchLower) ||
          requestNo.contains(searchLower) ||
          reqNo.contains(searchLower) ||
          title.contains(searchLower) ||
          employeeName.contains(searchLower) ||
          vendor.contains(searchLower);
    }).toList();
  }

  String _pickCommentValue(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['comment'],
      item['comments'],
      item['note'],
      item['description'],
      item['approval_comment'],
      item['reject_reason'],
      item['rejection_reason'],
      item['manager_comment'],
    ];

    for (final value in candidates) {
      if (value == null || value == false || value == true) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final normalized = text.toLowerCase();
      if (normalized == 'null' ||
          normalized == 'false' ||
          normalized == 'true') {
        continue;
      }
      return text;
    }

    return '';
  }

  List<Map<String, dynamic>> _normalizeCategoryItems(
    List<dynamic> rawItems, {
    required String categoryLabel,
  }) {
    return rawItems.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final typeValue = map['type']?.toString().trim();
      map['category'] = categoryLabel;
      map['type'] = (typeValue != null && typeValue.isNotEmpty)
          ? typeValue
          : categoryLabel;

      final existingComment = map['comment'];
      final hasMeaningfulComment = existingComment != null &&
          existingComment != false &&
          existingComment != true &&
          existingComment.toString().trim().isNotEmpty &&
          existingComment.toString().toLowerCase() != 'null' &&
          existingComment.toString().toLowerCase() != 'false' &&
          existingComment.toString().toLowerCase() != 'true';

      if (!hasMeaningfulComment) {
        map['comment'] = _pickCommentValue(map);
      }

      if (categoryLabel == 'INVOICE') {
        _enrichInvoiceListItem(map);
      } else if (categoryLabel == 'RFQ') {
        _enrichRfqListItem(map);
      } else if (categoryLabel == 'PETTY CASH') {
        _enrichPettyCashListItem(map);
      } else if (categoryLabel == 'HR') {
        _enrichHrListItem(map);
      }

      return map;
    }).toList(growable: false);
  }

  void _enrichHrListItem(Map<String, dynamic> map) {
    final existing = ApprovalDisplayHelpers.pickImageUrl(
      map,
      ApprovalAvatarKind.employee,
      allowIdFallback: false,
    );
    if (existing.isNotEmpty &&
        !ApprovalDisplayHelpers.isSyntheticEmployeePublicUrl(existing)) {
      map['emp_image_url'] =
          ApprovalDisplayHelpers.normalizeImageUrl(existing);
      return;
    }

    // Prefer hr.employee DB id (list used to omit this; emp_id is the code).
    // Provisional only — list avatar still lazy-loads form_view photo.
    final raw = map['employee_id'] ?? map['requester_id'];
    int? parsed;
    if (raw is int) {
      parsed = raw;
    } else if (raw is num) {
      parsed = raw.toInt();
    } else if (raw is List && raw.isNotEmpty) {
      parsed = int.tryParse(raw.first.toString());
    } else {
      parsed = int.tryParse(raw?.toString() ?? '');
    }
    if (parsed != null && parsed > 0) {
      map['emp_image_url'] =
          ApprovalDisplayHelpers.employeePublicImageUrl(parsed);
      return;
    }

    // Legacy list payloads only had /public/user/image/{userId} — keep as
    // provisional so avatar still fetches get_hr_request_details.
    if (existing.isNotEmpty) {
      map['emp_image_url'] =
          ApprovalDisplayHelpers.normalizeImageUrl(existing);
    }
  }

  void _enrichInvoiceListItem(Map<String, dynamic> map) {
    _enrichVendorPhotoListItem(map);
  }

  void _enrichRfqListItem(Map<String, dynamic> map) {
    _enrichVendorPhotoListItem(map);
  }

  void _enrichVendorPhotoListItem(Map<String, dynamic> map) {
    final resolved = ApprovalDisplayHelpers.normalizeImageUrl(
      ApprovalDisplayHelpers.pickImageUrl(map, ApprovalAvatarKind.vendor),
    );
    if (resolved.isNotEmpty) {
      map['client_photo_url'] = resolved;
      return;
    }

    final partnerPhoto =
        ApprovalDisplayHelpers.partnerImageFromRecord(map);
    if (partnerPhoto.isNotEmpty) {
      map['client_photo_url'] = partnerPhoto;
    }
  }

  void _enrichPettyCashListItem(Map<String, dynamic> map) {
    final employeeId = map['employee_id'] ?? map['emp_id'] ?? map['requester_id'];
    if (employeeId != null &&
        (map['emp_image_url'] == null || map['emp_image_url'] == false)) {
      final parsed = int.tryParse(employeeId.toString());
      if (parsed != null && parsed > 0) {
        map['emp_image_url'] =
            'https://erp.elrace.com/public/employee/image/$parsed';
      }
    }
  }

  Future<List<dynamic>> _fetchCategoryData(String groupType) async {
    final token = SharedPref.getLoginData().result?.token;

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("https://erp.elrace.com/api/my_approvals_grouped");

    final params = <String, dynamic>{"group_type": groupType};
    if (groupType == 'rfq' || groupType == 'invoice') {
      params['comment'] = '';
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    if (groupType == 'rfq' || groupType == 'invoice') {
      final escapedBody = body.replaceAll("'", r"'\\''");
      debugPrint('🧪 [MyApproval][$groupType] cURL:');
      debugPrint(
        "curl -X GET '$url' -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Authorization: Bearer $token' --data '$escapedBody'",
      );
    }

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('[$groupType] status=${response.statusCode}');

    if (groupType == 'petty_cash' ||
        groupType == 'rfq' ||
        groupType == 'invoice') {
      debugPrint('🧾 [MyApproval][$groupType] Raw response start');
      const chunkSize = 800;
      final raw = response.body;
      for (var i = 0; i < raw.length; i += chunkSize) {
        final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
        debugPrint(raw.substring(i, end));
      }
      debugPrint('🧾 [MyApproval][$groupType] Raw response end');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      const Map<String, String> responseKeys = {
        "hr": "human_resources",
        "rfq": "rfq",
        "invoice": "invoices",
        "petty_cash": "petty_cash",
      };
      final actualKey = responseKeys[groupType] ?? groupType;
      final items = data['result']['data'][actualKey] ?? [];

      if (groupType == 'petty_cash') {
        debugPrint(
          '🧾 [MyApproval][petty_cash] Parsed items count=${items.length}',
        );
      }

      return items;
    } else {
      throw Exception("Failed to fetch $groupType: ${response.statusCode}");
    }
  }

  /// Loads a single category in the background and updates state when done.
  Future<void> _loadCategory(String categoryKey, {bool force = false}) async {
    // Never skip a forced refresh while a previous load is in flight — that
    // caused employee-request (and other) lists to stay stale after approve/reject.
    if (!force && _categoryLoading[categoryKey] == true) {
      debugPrint(
          '⏳ [ApprovalsScreen] Skip loading $categoryKey (already loading)');
      return;
    }
    if (!force && _categoryLoaded[categoryKey] == true) {
      debugPrint(
          '✅ [ApprovalsScreen] Skip loading $categoryKey (already loaded)');
      return;
    }

    debugPrint(
        '🔄 [ApprovalsScreen] Loading category=$categoryKey force=$force');
    setState(() {
      _categoryLoading[categoryKey] = true;
      if (force) {
        _categoryLoaded[categoryKey] = false;
        categoryErrors.remove(categoryKey);
      }
    });

    try {
      final items = await _fetchCategoryData(categoryKey);
      if (!mounted) return;
      setState(() {
        switch (categoryKey) {
          case 'hr':
            var normalizedHr =
                _normalizeCategoryItems(items, categoryLabel: 'HR');
            if (kDebugMode) {
              normalizedHr = _ensureDebugWaitingHrRequests(normalizedHr);
            }
            hrItems = normalizedHr;
            _countCache.hr = hrItems.length;
          case 'rfq':
            rfqItems = _normalizeCategoryItems(items, categoryLabel: 'RFQ');
            _countCache.rfq = rfqItems.length;
          case 'invoice':
            var normalizedInvoices =
                _normalizeCategoryItems(items, categoryLabel: 'INVOICE');
            if (kDebugMode) {
              // Ensure at least one row so Print / Supporting Document can be tested.
              normalizedInvoices =
                  _ensureDebugWaitingInvoice(normalizedInvoices);
            }
            invoiceItems = normalizedInvoices;
            _countCache.invoice = invoiceItems.length;
          case 'petty_cash':
            pettyCashItems =
                _normalizeCategoryItems(items, categoryLabel: 'PETTY CASH');
            _countCache.pettyCash = pettyCashItems.length;
        }
        allItems = [
          ...hrItems,
          ...rfqItems,
          ...invoiceItems,
          ...pettyCashItems
        ];
        approvalItems = _getFilteredItems();
        _categoryLoading[categoryKey] = false;
        _categoryLoaded[categoryKey] = true;
      });
      debugPrint(
        '✅ [ApprovalsScreen] Loaded $categoryKey with ${items.length} items',
      );
      _syncApprovalBadgeCountIfReady();
      _warmCategoryPhotos(categoryKey, items);
      if (kDebugMode && categoryKey == 'invoice') {
        _upgradeDebugWaitingInvoiceIfNeeded();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        categoryErrors[categoryKey] = e.toString();
        _categoryLoading[categoryKey] = false;
      });
      debugPrint('❌ [ApprovalsScreen] Failed loading $categoryKey: $e');
    }
  }

  /// Keep home/waiting header badge in sync as lists load.
  void _publishApprovalBadgeCount() {
    final anyLoaded = _categoryLoaded.values.any((v) => v == true);
    final cacheTotal = _countCache.hr +
        _countCache.rfq +
        _countCache.invoice +
        _countCache.pettyCash;
    // Don't stomp a warm home badge with zeros before the first category lands.
    if (!anyLoaded && cacheTotal <= 0) return;

    final hr =
        _categoryLoaded['hr'] == true ? hrItems.length : _countCache.hr;
    final rfq =
        _categoryLoaded['rfq'] == true ? rfqItems.length : _countCache.rfq;
    final invoice = _categoryLoaded['invoice'] == true
        ? invoiceItems.length
        : _countCache.invoice;
    final petty = _categoryLoaded['petty_cash'] == true
        ? pettyCashItems.length
        : _countCache.pettyCash;
    ApprovalCountService.updateCachedCount(hr + rfq + invoice + petty);
  }

  void _syncApprovalBadgeCountIfReady() {
    _publishApprovalBadgeCount();
  }

  /// Invoice is fetched first; other categories follow immediately after.
  Future<void> _loadAllCategoriesInBackground({bool force = false}) {
    debugPrint('🚀 [ApprovalsScreen] Loading all categories (force=$force)');
    return Future.wait([
      _loadCategory('invoice', force: force),
      _loadCategory('hr', force: force),
      _loadCategory('rfq', force: force),
      _loadCategory('petty_cash', force: force),
    ]);
  }

  int _displayCategoryCount(String categoryKey, List<dynamic> items) {
    if (_categoryLoaded[categoryKey] == true) return items.length;
    if (_categoryLoading[categoryKey] == true) {
      return _countCache.forKey(categoryKey);
    }
    return items.length;
  }

  List<dynamic> _getApprovalListForSelectedCategory() {
    switch (selectedCategoryKey) {
      case _CategoryKeys.hr:
        return hrItems;
      case _CategoryKeys.rfq:
        return rfqItems;
      case _CategoryKeys.invoice:
        return invoiceItems;
      case _CategoryKeys.pettyCash:
        return pettyCashItems;
      case _CategoryKeys.all:
      default:
        return allItems;
    }
  }

  Future<void> _fetchDelayedCount() async {
    try {
      final counters = await _delayedRepo.fetchCounters();
      if (!mounted) return;
      setState(() {
        _delayedCounters = counters;
        delayedCount = counters.totalCount;
        _countCache.delayedTotal = counters.totalCount;
        _countCache.delayedHr = counters.hrCount;
        _countCache.delayedRfq = counters.rfqCount;
        _countCache.delayedInvoice = counters.invoiceCount;
        _countCache.delayedPettyCash = counters.pettyCashCount;
      });
    } catch (e) {
      debugPrint('Failed to fetch delayed count: $e');
    }
  }

  Future<void> _fetchRorData({int? month, int? year}) async {
    final targetMonth = month ?? _rorMonth;
    final targetYear = year ?? _rorYear;
    if (!mounted) return;
    setState(() => _rorLoading = true);
    try {
      final ror = await _delayedRepo.fetchRor(
        month: targetMonth,
        year: targetYear,
      );
      final hasBreakdownCounts = (ror.hrCount ?? 0) > 0 ||
          (ror.rfqCount ?? 0) > 0 ||
          (ror.pettyCashCount ?? 0) > 0 ||
          (ror.invoiceCount ?? 0) > 0;
      debugPrint(
        '🟣 [ROR SOURCE] API (${hasBreakdownCounts ? 'score+counts' : 'score-only'}) => ror=${ror.rorPercentage}% month=$targetMonth year=$targetYear',
      );
      if (!mounted) return;
      setState(() {
        _rorData = ror;
        _rorMonth = targetMonth;
        _rorYear = targetYear;
        _rorLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch delayed ROR: $e');
      debugPrint(
          '🟡 [ROR SOURCE] Fallback => local tab counts + local formula');
      if (mounted) {
        setState(() => _rorLoading = false);
      }
    }
  }

  void _onRorPeriodChanged(int month, int year) {
    if (month == _rorMonth && year == _rorYear) return;
    _fetchRorData(month: month, year: year);
  }

  Future<void> _refreshApprovalsAfterAction() async {
    debugPrint('🔁 [ApprovalsScreen] Refresh requested after approve/reject');
    // Clear badge cache immediately so headers refetch in parallel.
    ApprovalCountService.invalidateCache();
    ApprovalCountService.notifyListeners();
    await _loadAllCategoriesInBackground(force: true);
    if (!mounted) return;
    _syncApprovalBadgeCountIfReady();
    _fetchDelayedCount();
    _fetchRorData();
  }

  void _openHrManagementTestCases() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _HrManagementTestCasesScreen(),
      ),
    );
  }

  /// Debug-only: open one waiting-invoice form to test Print / Supporting Document.
  Future<void> _openInvoicePrintTest() async {
    if (!kDebugMode) return;

    Map<String, dynamic>? item;
    if (invoiceItems.isNotEmpty && invoiceItems.first is Map) {
      item = Map<String, dynamic>.from(invoiceItems.first as Map);
    } else {
      final seed = await _fetchDebugWaitingInvoiceSeed();
      item = seed;
      if (seed != null && mounted) {
        setState(() {
          invoiceItems = [seed, ...invoiceItems];
          _countCache.invoice = invoiceItems.length;
          allItems = [
            ...hrItems,
            ...rfqItems,
            ...invoiceItems,
            ...pettyCashItems,
          ];
          approvalItems = _getFilteredItems();
          _categoryLoaded['invoice'] = true;
        });
      }
    }

    if (!mounted) return;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No invoice found for debug print test. Open Invoice tab after login.',
          ),
        ),
      );
      return;
    }

    await _openCategoryRecordFromSheet(
      context,
      item,
      _CategoryKeys.invoice,
    );
  }

  /// When waiting invoices are empty in debug, seed one sample form row.
  List<Map<String, dynamic>> _ensureDebugWaitingInvoice(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isNotEmpty) return items;
    return [_debugLocalFakeInvoiceItem()];
  }

  /// Debug-only: prepend one local fake waiting HR card per request type.
  List<Map<String, dynamic>> _ensureDebugWaitingHrRequests(
    List<Map<String, dynamic>> items,
  ) {
    final dummies = _debugLocalFakeHrItems();
    final existingIds = items.map((e) => e['id']?.toString()).toSet();
    final toAdd = dummies
        .where((d) => !existingIds.contains(d['id']?.toString()))
        .toList(growable: false);
    if (toAdd.isEmpty) return items;
    return [...toAdd, ...items];
  }

  List<Map<String, dynamic>> _debugLocalFakeHrItems() {
    const cases = <(String, String)>[
      ('annual', 'Annual Leave'),
      ('sick', 'Sick Leave'),
      ('short', 'Short Leave'),
      ('maternity', 'Maternity Leave'),
      ('parental', 'Parental'),
      ('death', 'Death Leave'),
      ('compensation', 'Compensation Leave'),
      ('emergency', 'Emergency Leave'),
      ('unpaid', 'Unpaid Leave'),
      ('job_mission', 'Job Mission'),
      ('temporary_permission', 'Temporary Permission'),
      ('clearance', 'Clearance'),
      ('effective_date', 'Effective Date'),
      ('salary_certificate', 'Salary Certificate'),
      ('loan', 'Loan Request'),
      ('increment', 'Salary Increment'),
      ('promotion', 'Promotion'),
      ('resignation', 'Resignation'),
      ('termination', 'Termination'),
      ('transfer', 'Transfer Request'),
      ('passport', 'Passport'),
      ('leave_encashment', 'Leave Encashment'),
      ('car_rent', 'Car Rent Request'),
      ('sim', 'Sim Card Request'),
    ];

    return [
      for (final entry in cases)
        {
          'id': 'LOCAL_FAKE_HR_${entry.$1}',
          'name': '[DEBUG] ${entry.$2}',
          'request_no': 'REQ/DEBUG/${entry.$1.toUpperCase()}',
          'request_name': entry.$2,
          'request_type': entry.$2,
          'request_type_code': entry.$1,
          'type': 'HR',
          'category': 'HR',
          'employee_name': 'Adil Rasheed',
          'emp_id': '524',
          'comment': 'Debug review form — ${entry.$2}',
        },
    ];
  }

  Map<String, dynamic> _debugLocalFakeInvoiceItem() => {
        'id': InvoiceDetailsScreen.localFakeInvoiceRequestId,
        'name': '[DEBUG] Waiting Invoice (Print Test)',
        'request_no': 'INV/DEBUG/PRINT',
        'vendor': 'Debug Vendor — tap for form + print menu',
        'type': 'INVOICE',
        'category': 'INVOICE',
        'amount': '1000000',
        'total_amount': '1000000',
        'invoice_date': '2026-08-13',
      };

  /// Prefer a live account.move id so Print / Supporting Document hit real APIs.
  Future<void> _upgradeDebugWaitingInvoiceIfNeeded() async {
    if (!kDebugMode || !mounted) return;
    final onlyFake = invoiceItems.length == 1 &&
        invoiceItems.first['id']?.toString() ==
            InvoiceDetailsScreen.localFakeInvoiceRequestId;
    if (!onlyFake) return;

    final seed = await _fetchDebugWaitingInvoiceSeed();
    if (!mounted || seed == null) return;
    if (seed['id']?.toString() ==
        InvoiceDetailsScreen.localFakeInvoiceRequestId) {
      return;
    }

    setState(() {
      invoiceItems = [seed];
      _countCache.invoice = invoiceItems.length;
      allItems = [
        ...hrItems,
        ...rfqItems,
        ...invoiceItems,
        ...pettyCashItems,
      ];
      approvalItems = _getFilteredItems();
    });
    _syncApprovalBadgeCountIfReady();
  }

  Future<Map<String, dynamic>?> _fetchDebugWaitingInvoiceSeed() async {
    try {
      final preview = await PurchaseRepository().fetchInvoicesPreview(
        limit: 1,
        refresh: true,
      );
      if (preview.items.isNotEmpty) {
        final first = preview.items.first;
        return {
          'id': first.id,
          'name': '[DEBUG] ${first.vendor}',
          'request_no': first.invoiceId.isNotEmpty
              ? first.invoiceId
              : 'INV/${first.id}',
          'vendor': first.vendor,
          'type': 'INVOICE',
          'category': 'INVOICE',
          'amount': first.amount,
          'total_amount': first.amount,
          'formatted_amount': first.formattedAmount,
          'invoice_date': first.invoiceDate,
          'invoice_id': first.id,
        };
      }
    } catch (e) {
      debugPrint('debug invoice seed failed: $e');
    }
    return _debugLocalFakeInvoiceItem();
  }

  void _returnToOverview() {
    setState(() {
      selectedCategoryKey = _CategoryKeys.all;
      approvalItems = _getFilteredItems();
    });
  }

  List<Map<String, dynamic>> _castItemMaps(List<dynamic> raw) {
    final out = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        out.add(entry);
      } else if (entry is Map) {
        out.add(Map<String, dynamic>.from(entry));
      }
    }
    return out;
  }

  /// Canonical approval API type for approve/reject routing (not HR subtypes like Annual/Sick).
  String _approvalApiType(String categoryKey, Map<String, dynamic> item) {
    switch (categoryKey) {
      case _CategoryKeys.hr:
        return 'HR';
      case _CategoryKeys.pettyCash:
        return 'PETTY CASH';
      case _CategoryKeys.rfq:
        return 'RFQ';
      case _CategoryKeys.invoice:
        return 'INVOICE';
      default:
        return item['category']?.toString() ??
            item['type']?.toString() ??
            categoryKey;
    }
  }

  void _warmCategoryPhotos(String categoryKey, List<dynamic> items) {
    final photoCategory = ApprovalPhotoCache.fromCategoryKey(categoryKey);
    if (photoCategory == null) return;

    final maps = items
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);

    ApprovalPhotoCache.warmList(photoCategory, maps).then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _openCategoryRecordFromSheet(
    BuildContext navigatorContext,
    Map<String, dynamic> item,
    String categoryKey,
  ) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final type = _approvalApiType(categoryKey, item);
    dynamic result;

    switch (categoryKey) {
      case _CategoryKeys.hr:
        result = await Navigator.push(
          navigatorContext,
          MaterialPageRoute(
            builder: (_) => HrDetailsScreen(requestId: id, type: type),
          ),
        );
      case _CategoryKeys.pettyCash:
        result = await Navigator.push(
          navigatorContext,
          MaterialPageRoute(
            builder: (_) => PettyCashDetailsScreen(requestId: id, type: type),
          ),
        );
      case _CategoryKeys.rfq:
        result = await Navigator.push(
          navigatorContext,
          MaterialPageRoute(
            builder: (_) => RfqDetailsScreen(requestId: id, type: type),
          ),
        );
      case _CategoryKeys.invoice:
        result = await Navigator.push(
          navigatorContext,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(requestId: id, type: type),
          ),
        );
      default:
        result = await showDialog<bool>(
          context: navigatorContext,
          builder: (_) => ApprovalConfirmationScreen(
            requestId: id,
            type: type,
          ),
        );
    }

    if (result == true) {
      await _refreshApprovalsAfterAction();
    }
  }

  Future<void> _openDelayedRecordFromSheet(
    BuildContext navigatorContext,
    Map<String, dynamic> item,
  ) async {
    final type =
        (item['requestType'] ?? item['type'] ?? '').toString().toLowerCase();
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (type.contains('hr') || type.contains('employee')) {
      await _openCategoryRecordFromSheet(
        navigatorContext,
        item,
        _CategoryKeys.hr,
      );
    } else if (type.contains('rfq')) {
      await _openCategoryRecordFromSheet(
        navigatorContext,
        item,
        _CategoryKeys.rfq,
      );
    } else if (type.contains('invoice')) {
      await _openCategoryRecordFromSheet(
        navigatorContext,
        item,
        _CategoryKeys.invoice,
      );
    } else if (type.contains('petty') || type.contains('cash')) {
      await _openCategoryRecordFromSheet(
        navigatorContext,
        item,
        _CategoryKeys.pettyCash,
      );
    }
  }

  String _categoryTitle(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.hr:
        return 'HR Approvals';
      case _CategoryKeys.rfq:
        return 'RFQ Approvals';
      case _CategoryKeys.invoice:
        return 'Invoice Approvals';
      case _CategoryKeys.pettyCash:
        return 'Petty Cash Approvals';
      default:
        return 'Approvals';
    }
  }

  final List<String> categoryKeys = const [
    _CategoryKeys.all,
    _CategoryKeys.hr,
    _CategoryKeys.rfq,
    _CategoryKeys.pettyCash,
    _CategoryKeys.invoice,
  ];
  bool isSearch = false;

  @override
  Widget build(BuildContext context) {
    final isOverview = selectedCategoryKey == _CategoryKeys.all;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!isOverview) {
          _returnToOverview();
          return;
        }
        HomeNavigation.handleSystemBack(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: ApprovalsOverviewTheme.overlay,
        child: Scaffold(
          backgroundColor: ApprovalsOverviewTheme.screenBase,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: ApprovalsOverviewTheme.screenGradient,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContextualGlassChromeHeader(
                    title: isOverview ? null : _categoryTitle(selectedCategoryKey),
                    showBack: !isOverview,
                    onBack: _returnToOverview,
                    onLightSurface: true,
                    transparentGlassBar: false,
                    scrimTopOpacity: 0,
                  ),
                  Expanded(child: body()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  body() {
    // ALL tab: show instantly with live-updating counts as categories load in background
    if (selectedCategoryKey == _CategoryKeys.all) {
      return AllApprovalsOverview(
        invoiceCount: _displayCategoryCount('invoice', invoiceItems),
        pettyCashCount: _displayCategoryCount('petty_cash', pettyCashItems),
        rfqCount: _displayCategoryCount('rfq', rfqItems),
        hrCount: _displayCategoryCount('hr', hrItems),
        hrItems: _castItemMaps(hrItems),
        rfqItems: _castItemMaps(rfqItems),
        invoiceItems: _castItemMaps(invoiceItems),
        pettyCashItems: _castItemMaps(pettyCashItems),
        categoryLoading: Map<String, bool>.from(_categoryLoading),
        categoryLoaded: Map<String, bool>.from(_categoryLoaded),
        categoryErrors: Map<String, String>.from(categoryErrors),
        onCategoryRetry: (key) => _loadCategory(key, force: true),
        delayedCount: _delayedCounters != null
            ? delayedCount
            : _countCache.delayedTotal,
        delayedHrCount: _delayedCounters?.hrCount ?? _countCache.delayedHr,
        delayedRfqCount: _delayedCounters?.rfqCount ?? _countCache.delayedRfq,
        delayedInvoiceCount:
            _delayedCounters?.invoiceCount ?? _countCache.delayedInvoice,
        delayedPettyCashCount:
            _delayedCounters?.pettyCashCount ?? _countCache.delayedPettyCash,
        rorPercentage: _rorData?.rorPercentage,
        rorHrRor: _rorData?.hrRor,
        rorRfqRor: _rorData?.rfqRor,
        rorInvoiceRor: _rorData?.invoiceRor,
        rorPettyCashRor: _rorData?.pettyCashRor,
        rorMonth: _rorMonth,
        rorYear: _rorYear,
        rorLoading: _rorLoading,
        onRorPeriodChanged: _onRorPeriodChanged,
        onCategoryRecordTap: _openCategoryRecordFromSheet,
        onDelayedRecordTap: _openDelayedRecordFromSheet,
        onHrManagementTestCasesTap:
            kDebugMode ? _openHrManagementTestCases : null,
        onInvoicePrintTestTap: kDebugMode ? _openInvoicePrintTest : null,
      );
    }

    // For specific category tabs: show spinner only while that category is loading
    final apiKey = _categoryApiKey(selectedCategoryKey);
    final isLoadingCategory = _categoryLoading[apiKey] == true;
    final hasError = categoryErrors.containsKey(apiKey);

    if (isLoadingCategory) {
      return _categoryListShell(
        const Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return _categoryListShell(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(categoryErrors[apiKey]!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadCategory(apiKey),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final categoryItems = _getFilteredItems();

    if (selectedCategoryKey == _CategoryKeys.hr ||
        selectedCategoryKey == _CategoryKeys.pettyCash) {
      return _categoryListShell(
        HrAndPettycashCard(
          approvalItems: categoryItems,
          onRefresh: _refreshApprovalsAfterAction,
        ),
      );
    } else if (selectedCategoryKey == _CategoryKeys.rfq ||
        selectedCategoryKey == _CategoryKeys.invoice) {
      return _categoryListShell(
        InvoiceAndRfqCard(
          approvalItems: categoryItems,
          onRefresh: _refreshApprovalsAfterAction,
          categoryType: selectedCategoryKey,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _categoryListShell(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26.tr)),
      child: ColoredBox(
        color: Colors.white,
        child: child,
      ),
    );
  }

  /// Maps a category UI key to the API group_type string.
  String _categoryApiKey(String categoryKey) {
    switch (categoryKey) {
      case _CategoryKeys.hr:
        return 'hr';
      case _CategoryKeys.rfq:
        return 'rfq';
      case _CategoryKeys.invoice:
        return 'invoice';
      case _CategoryKeys.pettyCash:
        return 'petty_cash';
      default:
        return categoryKey;
    }
  }
}

class _CategoryKeys {
  static const String all = 'all';
  static const String hr = 'hr';
  static const String rfq = 'rfq';
  static const String invoice = 'invoice';
  static const String pettyCash = 'petty_cash';
}

class _ApprovalsCountCache {
  int hr = 0;
  int rfq = 0;
  int invoice = 0;
  int pettyCash = 0;
  int delayedTotal = 0;
  int delayedHr = 0;
  int delayedRfq = 0;
  int delayedInvoice = 0;
  int delayedPettyCash = 0;

  int forKey(String categoryKey) {
    switch (categoryKey) {
      case 'hr':
        return hr;
      case 'rfq':
        return rfq;
      case 'invoice':
        return invoice;
      case 'petty_cash':
        return pettyCash;
      default:
        return 0;
    }
  }
}

class _HrManagementTestCase {
  final int id;
  final String title;

  const _HrManagementTestCase({required this.id, required this.title});
}

class _HrManagementTestCasesScreen extends StatelessWidget {
  const _HrManagementTestCasesScreen();

  static const List<_HrManagementTestCase> _cases =
      _ApprovalsScreenState._hrManagementTestCases;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: Text(
          'HR Management Test Cases',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(14.tw, 14.tw, 14.tw, 24.tw),
        itemCount: _cases.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.tw),
        itemBuilder: (context, index) {
          final testCase = _cases[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.tr),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.tr),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HrDetailsScreen(
                      requestId: testCase.id.toString(),
                      type: 'hr',
                    ),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 14.tw),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.tr),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34.tw,
                      height: 34.tw,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FA),
                        borderRadius: BorderRadius.circular(10.tr),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF20345B),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.tw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            testCase.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14.tsp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF151B2C),
                            ),
                          ),
                          SizedBox(height: 2.tw),
                          Text(
                            'request_id: ${testCase.id}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.tsp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6A7388),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.tsp,
                      color: const Color(0xFF7B869F),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
