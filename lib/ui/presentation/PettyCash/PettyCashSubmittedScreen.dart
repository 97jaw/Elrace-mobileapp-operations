import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:el_race/ui/presentation/PettyCash/utils/petty_cash_holder_utils.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_glass_header.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PettyCashSubmittedScreen extends StatefulWidget {
  const PettyCashSubmittedScreen({super.key});

  @override
  State<PettyCashSubmittedScreen> createState() =>
      _PettyCashSubmittedScreenState();
}

class _PettyCashSubmittedScreenState extends State<PettyCashSubmittedScreen> {
  static const int _limit = 20;

  bool _isLoading = true;
  bool _isPageLoading = false;
  String _error = '';

  List<Map<String, dynamic>> _submittedSheets = [];
  int _currentPage = 1;
  int _total = 0;
  bool _hasMore = false;

  final NumberFormat _amountFormat = NumberFormat('#,##0.##');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int get _totalPages {
    if (_total <= 0) return 1;
    return (_total / _limit).ceil();
  }

  @override
  void initState() {
    super.initState();
    _fetchSubmittedData(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _resolveHolderId() {
    final loginData = SharedPref.getLoginData();
    final modeledHolderId = loginData.result?.data?.holder_id;
    if (modeledHolderId != null) {
      return modeledHolderId;
    }

    final loginJson = SharedPref.sharedPreferences.getString('loginResponse') ??
        SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
    if (loginJson == null || loginJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic>) return null;

      final data = result['data'];
      if (data is! Map<String, dynamic>) return null;

      final rawHolderId = data['holder_id'];
      if (rawHolderId is int) return rawHolderId;
      if (rawHolderId is List &&
          rawHolderId.isNotEmpty &&
          rawHolderId.first is int) {
        return rawHolderId.first as int;
      }
      return int.tryParse(rawHolderId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchSubmittedData({required int page}) async {
    if (!mounted) return;

    setState(() {
      if (page == 1) {
        _isLoading = true;
      } else {
        _isPageLoading = true;
      }
      _error = '';
    });

    try {
      final loginData = SharedPref.getLoginData();
      final token = loginData.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      final holderId = _resolveHolderId();
      if (holderId == null) {
        throw Exception('Petty cash holder_id is missing from login data');
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final url =
          Uri.parse('https://erp.elrace.com/api/view_all_hr_expense_sheets');

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'page': page,
          'limit': _limit,
          'holder_id': holderId,
        },
      });

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load submitted data: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = (json['result'] is Map<String, dynamic>)
          ? json['result'] as Map<String, dynamic>
          : <String, dynamic>{};

      final dataNode = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      final rawSheets = dataNode['expense_sheets'];
      final fetchedSheets = (rawSheets is List)
          ? rawSheets
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final pagination = (result['pagination'] is Map<String, dynamic>)
          ? result['pagination'] as Map<String, dynamic>
          : <String, dynamic>{};

      final currentPage =
          int.tryParse(pagination['current_page']?.toString() ?? '') ?? page;
      final total = int.tryParse(pagination['total']?.toString() ?? '') ?? 0;
      final hasMore = pagination['has_more'] == true;

      if (!mounted) return;
      setState(() {
        _submittedSheets = fetchedSheets;
        _currentPage = currentPage;
        _total = total;
        _hasMore = hasMore;
        _isLoading = false;
        _isPageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isPageLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await _fetchSubmittedData(page: 1);
  }

  Future<void> _goToNextPage() async {
    if (_isPageLoading || !_hasMore) return;
    await _fetchSubmittedData(page: _currentPage + 1);
  }

  Future<void> _goToPrevPage() async {
    if (_isPageLoading || _currentPage <= 1) return;
    await _fetchSubmittedData(page: _currentPage - 1);
  }

  String _formatAmount(dynamic value) {
    final numVal = (value is num)
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
    return PettyCashHolderUtils.formatAmount(numVal);
  }

  String _formatSheetTitle(Map<String, dynamic> sheet) {
    final titleCandidates = [
      sheet['name'],
      sheet['reference'],
      sheet['display_name'],
      sheet['employee_name'],
      sheet['employee'],
    ];
    for (final c in titleCandidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'false') return s;
    }
    return 'Expense Sheet';
  }

  String _formatSheetDate(Map<String, dynamic> sheet) {
    final candidates = [
      sheet['last_update'],
      sheet['create_date'],
      sheet['datetime'],
      sheet['date']
    ];
    DateTime? parsed;
    for (final c in candidates) {
      final raw = (c ?? '').toString().trim();
      if (raw.isEmpty || raw.toLowerCase() == 'false') continue;
      parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed != null) break;
    }

    if (parsed == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final diffDays = today.difference(day).inDays;

    final time = DateFormat('HH:mm').format(parsed);
    if (diffDays == 0) return 'Today · $time';
    if (diffDays == 1) return 'Yesterday · $time';
    return '${DateFormat('dd/MM/yyyy').format(parsed)} · $time';
  }

  List<Map<String, dynamic>> get _visibleSheets {
    if (_searchQuery.trim().isEmpty) return _submittedSheets;
    final q = _searchQuery.trim().toLowerCase();
    return _submittedSheets.where((sheet) {
      final title = _formatSheetTitle(sheet).toLowerCase();
      final date = _formatSheetDate(sheet).toLowerCase();
      final ref = (sheet['reference'] ?? '').toString().toLowerCase();
      return title.contains(q) || date.contains(q) || ref.contains(q);
    }).toList(growable: false);
  }

  Color _statusDotColor(Map<String, dynamic> sheet) {
    final s = (sheet['state'] ?? '').toString().toLowerCase();
    if (s.contains('paid') || s.contains('approve') || s.contains('done')) {
      return const Color(0xFF18A558);
    }
    if (s.contains('submit') || s.contains('pending') || s.contains('draft')) {
      return const Color(0xFFF0B400);
    }
    if (s.contains('reject') || s.contains('cancel') || s.contains('refuse')) {
      return const Color(0xFFD1002C);
    }
    return const Color(0xFF18A558);
  }

  @override
  Widget build(BuildContext context) {
    return PettyCashScreenShell(
      header: const PettyCashGlassHeader(
        title: 'Submitted sheets',
        showBack: true,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PettyCashTheme.mint),
            )
          : _error.isNotEmpty
              ? _buildErrorState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: PettyCashTheme.glassFill,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: PettyCashTheme.glassBorder,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PettyCashTheme.white,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search sheets',
                            hintStyle: GoogleFonts.poppins(
                              color: PettyCashTheme.textMuted,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            prefixIcon: Icon(
                              Icons.search,
                              color: PettyCashTheme.textSecondary,
                              size: 23,
                            ),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 120 &&
                              _hasMore &&
                              !_isPageLoading) {
                            _goToNextPage();
                          }
                          return false;
                        },
                        child: RefreshIndicator(
                          onRefresh: _refresh,
                          child: _visibleSheets.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Text(
                                        'No record found.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: PettyCashTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 4, 20, 80),
                                  itemCount: _visibleSheets.length +
                                      (_isPageLoading ? 1 : 0),
                                  separatorBuilder: (_, __) => Divider(
                                    color: PettyCashTheme.glassBorder,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index >= _visibleSheets.length) {
                                      return const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 14),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    }
                                    final sheet = _visibleSheets[index];
                                    return _buildExpenseRow(sheet);
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load submitted sheets',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PettyCashTheme.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PettyCashTheme.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _fetchSubmittedData(page: 1),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRow(Map<String, dynamic> sheet) {
    final title = _formatSheetTitle(sheet);
    final dateText = _formatSheetDate(sheet);
    final amountText =
        _formatAmount(sheet['total_amount'] ?? sheet['amount'] ?? 0);
    final dotColor = _statusDotColor(sheet);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: PettyCashTheme.glassCard(radius: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PettyCashTheme.iconCircleBg,
              shape: BoxShape.circle,
              border: Border.all(color: PettyCashTheme.glassBorder),
            ),
            child: Center(
              child: Image.asset(
                'assets/png/Bill.png',
                width: 22,
                height: 22,
                color: PettyCashTheme.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PettyCashTheme.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateText,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PettyCashTheme.textMuted,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '-$amountText',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PettyCashTheme.expenseRed,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
