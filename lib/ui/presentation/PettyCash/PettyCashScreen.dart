import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashSubmittedScreen.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:el_race/ui/presentation/PettyCash/utils/petty_cash_holder_utils.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_add_expense_flow.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_balance_card_stack.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_expense_widgets.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_glass_header.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({super.key});

  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> {
  bool _isLoading = true;
  String _error = '';
  bool _isNotHolder = false;
  _PettyCashHomeData _home = const _PettyCashHomeData.empty();

  final NumberFormat _wholeAmountFormat = NumberFormat('#,##0.##');
  final NumberFormat _integerAmountFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _fetchPettyCashHome();
  }

  void _logLongMessage(String label, String message) {
    const chunkSize = 800;
    if (message.isEmpty) {
      debugPrint('$label: <empty>');
      return;
    }

    for (var index = 0; index < message.length; index += chunkSize) {
      final end = math.min(index + chunkSize, message.length);
      debugPrint(
          '$label ${index ~/ chunkSize + 1}: ${message.substring(index, end)}');
    }
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

  Future<void> _fetchPettyCashHome() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _isNotHolder = false;
    });

    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      final holderId = _resolveHolderId();
      if (holderId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isNotHolder = true;
          });
        }
        return;
      }

      final url = Uri.parse('https://erp.elrace.com/api/petty_cash_home');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'jsonrpc': '2.0',
          'params': <String, dynamic>{
            'holder_id': holderId,
          },
        });

      _logLongMessage(
        'PettyCashHome request body',
        jsonEncode({
          'jsonrpc': '2.0',
          'params': <String, dynamic>{
            'holder_id': holderId,
          },
        }),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('PettyCashHome statusCode: ${response.statusCode}');
      _logLongMessage('PettyCashHome raw response', response.body);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load petty cash home: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      _logLongMessage('PettyCashHome decoded', jsonEncode(decoded));

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        debugPrint(
            'PettyCashHome unexpected result type: ${result.runtimeType}');
        throw Exception('Invalid petty cash response');
      }

      final data = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      _logLongMessage('PettyCashHome result map', jsonEncode(result));
      _logLongMessage('PettyCashHome selected data', jsonEncode(data));

      final parsedHome = _PettyCashHomeData.fromJson(data);
      debugPrint(
        'PettyCashHome parsed values: '
        'batchId=${parsedHome.batchId}, '
        'totalLimit=${parsedHome.totalLimit}, '
        'draftAmount=${parsedHome.draftAmount}, '
        'submittedAmount=${parsedHome.submittedAmount}, '
        'paidAmount=${parsedHome.paidAmount}, '
        'balanceAmount=${parsedHome.balanceAmount}, '
        'recentSheets=${parsedHome.recentSheets.length}',
      );

      if (!mounted) return;
      setState(() {
        _home = parsedHome;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('PettyCashHome fetch error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatSheetAmount(num value) {
    return PettyCashHolderUtils.formatAmount(value.abs());
  }

  String _formatSheetDate(String rawDate) {
    final normalized = rawDate.trim();
    if (normalized.isEmpty) return '';

    final parsed = DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
    if (parsed == null) return normalized;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(targetDay).inDays;
    final time = DateFormat('HH:mm').format(parsed);

    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Yesterday · $time';
    return '${DateFormat('dd/MM/yyyy').format(parsed)} · $time';
  }

  Color _statusDotColor(String state) {
    final normalized = state.trim().toLowerCase();
    if (normalized.contains('done') ||
        normalized.contains('paid') ||
        normalized.contains('approved')) {
      return const Color(0xFF0AA15F);
    }
    if (normalized.contains('submit') ||
        normalized.contains('pending') ||
        normalized.contains('progress')) {
      return const Color(0xFFFF9300);
    }
    if (normalized.contains('draft') ||
        normalized.contains('reject') ||
        normalized.contains('cancel') ||
        normalized.contains('refuse')) {
      return const Color(0xFFC81F25);
    }
    return const Color(0xFF0AA15F);
  }

  @override
  Widget build(BuildContext context) {
    return PettyCashScreenShell(
      header: const PettyCashGlassHeader(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PettyCashTheme.mint),
      );
    }
    if (_isNotHolder) {
      return _buildNotHolder();
    }
    if (_error.isNotEmpty) {
      return _buildError();
    }
    return RefreshIndicator(
      color: PettyCashTheme.mint,
      onRefresh: _fetchPettyCashHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(0, 4.th, 0, 24.th),
        children: [
          PettyCashBalanceCardStack(
            balance: _home.balanceAmount,
            holderName: PettyCashHolderUtils.resolveHolderName(),
            batchLabel: _home.batchId != null
                ? 'Batch ${_home.batchId}'
                : 'Petty Cash',
            draftAmount: _home.draftAmount,
            notPaidAmount: _home.submittedAmount,
            onAddExpense: () => PettyCashAddExpenseFlow.showTypePicker(
              context,
              openAddForm: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.tw, 10.th, 16.tw, 0),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.th, horizontal: 6.tw),
              decoration: PettyCashTheme.surfaceCard(radius: 22),
              child: Row(
                children: [
                  PettyCashActionChip(
                    icon: Icons.local_gas_station_outlined,
                    label: 'Transport',
                    onTap: () => PettyCashAddExpenseFlow.openTransportation(
                      context,
                    ),
                  ),
                  PettyCashActionChip(
                    icon: Icons.receipt_long_rounded,
                    label: 'Misc',
                    onTap: () => PettyCashAddExpenseFlow.openMiscellaneous(
                      context,
                    ),
                  ),
                  PettyCashActionChip(
                    icon: Icons.description_outlined,
                    label: 'Submitted',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PettyCashSubmittedScreen(),
                        ),
                      );
                    },
                  ),
                  PettyCashActionChip(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Draft',
                    onTap: () {
                      if (_home.draftAmount > 0) {
                        PettyCashAddExpenseFlow.showTypePicker(context);
                      } else {
                        PettyCashAddExpenseFlow.showTypePicker(
                          context,
                          openAddForm: true,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.tw, 10.th, 16.tw, 0),
            child: Container(
              padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 6.th),
              decoration: PettyCashTheme.surfaceCard(radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Manage expenses',
                        style: PettyCashTheme.titleLg,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PettyCashSubmittedScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'View all',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w600,
                            color: PettyCashTheme.mintDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.th),
                  Row(
                    children: [
                      _metricChip('Limit', _home.totalLimit),
                      SizedBox(width: 8.tw),
                      _metricChip('Draft', _home.draftAmount),
                      SizedBox(width: 8.tw),
                      _metricChip('Paid', _home.paidAmount),
                    ],
                  ),
                  SizedBox(height: 8.th),
                  PettyCashExpenseTile(
                    title: 'Add expense',
                    subtitle: 'Transportation or miscellaneous',
                    amount: '+',
                    icon: Icons.add_circle_outline_rounded,
                    highlight: true,
                    amountColor: PettyCashTheme.mintDark,
                    onTap: () => PettyCashAddExpenseFlow.showTypePicker(
                      context,
                      openAddForm: true,
                    ),
                  ),
                  if (_home.recentSheets.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.th),
                      child: Center(
                        child: Text(
                          'No recent expense sheets',
                          style: GoogleFonts.poppins(
                            fontSize: 13.tsp,
                            color: PettyCashTheme.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._home.recentSheets.take(10).map(_buildRecentSheetRow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, num value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
        decoration: BoxDecoration(
          color: PettyCashTheme.glassFill,
          borderRadius: BorderRadius.circular(12.tr),
          border: Border.all(color: PettyCashTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PettyCashTheme.labelSm),
            Text(
              PettyCashHolderUtils.formatAmount(value),
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w700,
                color: PettyCashTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotHolder() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.tw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.tw,
              height: 72.tw,
              decoration: BoxDecoration(
                color: PettyCashTheme.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: PettyCashTheme.glassBorder),
                boxShadow: PettyCashTheme.softShadow,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 36.tsp,
                color: PettyCashTheme.textMuted,
              ),
            ),
            SizedBox(height: 16.th),
            Text(
              'Not a Petty Cash Holder',
              style: GoogleFonts.poppins(
                fontSize: 16.tsp,
                fontWeight: FontWeight.w700,
                color: PettyCashTheme.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.th),
            Text(
              'Your account is not assigned as a petty cash holder. Please contact your administrator.',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: PettyCashTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.tw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load petty cash',
              style: GoogleFonts.poppins(
                fontSize: 16.tsp,
                fontWeight: FontWeight.w700,
                color: PettyCashTheme.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.th),
            Text(
              _error,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: PettyCashTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.th),
            FilledButton(
              onPressed: _fetchPettyCashHome,
              style: FilledButton.styleFrom(
                backgroundColor: PettyCashTheme.black,
                foregroundColor: PettyCashTheme.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSheetRow(_PettyCashSheet sheet) {
    return PettyCashExpenseTile(
      title: sheet.name,
      subtitle: _formatSheetDate(sheet.lastUpdate),
      amount: '-${_formatSheetAmount(sheet.amount)}',
      amountColor: PettyCashTheme.expenseRed,
      trailing: Container(
        width: 8.tw,
        height: 8.tw,
        decoration: BoxDecoration(
          color: _statusDotColor(sheet.state),
          shape: BoxShape.circle,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PettyCashSubmittedScreen(),
          ),
        );
      },
    );
  }
}

class _PettyCashHomeData {
  final int? batchId;
  final double totalLimit;
  final double draftAmount;
  final double submittedAmount;
  final double paidAmount;
  final double balanceAmount;
  final List<_PettyCashSheet> recentSheets;

  const _PettyCashHomeData({
    required this.batchId,
    required this.totalLimit,
    required this.draftAmount,
    required this.submittedAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.recentSheets,
  });

  const _PettyCashHomeData.empty()
      : batchId = null,
        totalLimit = 0,
        draftAmount = 0,
        submittedAmount = 0,
        paidAmount = 0,
        balanceAmount = 0,
        recentSheets = const [];

  factory _PettyCashHomeData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _PettyCashHomeData(
      batchId: json['batch_id'] as int?,
      totalLimit: toDouble(json['total_limit'] ?? json['incoming']),
      draftAmount: toDouble(json['draft_amount'] ?? json['draft']),
      submittedAmount:
          toDouble(json['submitted_amount'] ?? json['not_paid_amount']),
      paidAmount: toDouble(json['paid_amount'] ?? json['paid']),
      balanceAmount: toDouble(json['balance_amount'] ?? json['balance']),
      recentSheets: (json['recent_sheets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _PettyCashSheet.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>)))
          .toList(growable: false),
    );
  }
}

class _PettyCashSheet {
  final String name;
  final String lastUpdate;
  final double amount;
  final String state;

  const _PettyCashSheet({
    required this.name,
    required this.lastUpdate,
    required this.amount,
    required this.state,
  });

  factory _PettyCashSheet.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _PettyCashSheet(
      name: (json['name'] ?? 'RCC PC 1').toString(),
      lastUpdate: (json['last_update'] ?? json['date'] ?? '').toString(),
      amount: toDouble(json['amount'] ?? json['total_amount']),
      state: (json['state'] ?? '').toString(),
    );
  }
}
