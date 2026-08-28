import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/data/vendors_dashboard_repository.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vendors tab — charcoal shell + filters + metallic KPIs + purchases trend.
class VendorsScreen extends StatelessWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VendorsTheme.deepLight,
                  VendorsTheme.deepMid,
                  VendorsTheme.deepDark,
                ],
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.55),
                  radius: 0.9,
                  colors: [
                    VendorsTheme.glowBright,
                    VendorsTheme.glowMid,
                    VendorsTheme.glowSoft,
                    VendorsTheme.glowEdge,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 1.0],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 1.3,
                  colors: [Colors.transparent, VendorsTheme.vignette],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: Opacity(
              opacity: 0.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.35, 0.6, 0.9],
                  ),
                ),
              ),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContextualGlassChromeHeader(
                showBack: false,
                onLightSurface: false,
                transparentGlassBar: true,
                logoOpacity: 0.7,
              ),
              Expanded(child: _VendorsDashboardBody()),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorsDashboardBody extends StatefulWidget {
  const _VendorsDashboardBody();

  @override
  State<_VendorsDashboardBody> createState() => _VendorsDashboardBodyState();
}

class _VendorsDashboardBodyState extends State<_VendorsDashboardBody> {
  final _repo = VendorsDashboardRepository();

  late int _year;
  int? _month;
  int? _partnerId;
  String _vendorLabel = 'All Vendors';
  VendorsDashboardData? _data;
  bool _loading = true;
  String? _error;
  int _sectionTab = 0;
  VendorsAgreementsSummary? _agreementsSummary;
  bool _agreementsLoading = false;

  static const _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _kmOnly(String formatted) =>
      formatted.replaceFirst(RegExp(r'^AED\s*', caseSensitive: false), '');

  static String _fmtMom(double pct) {
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  void _openBills(String scope) {
    final partnerName =
        _partnerId != null && _vendorLabel != 'All Vendors' ? _vendorLabel : null;
    Navigator.of(context).pushNamed(
      ClientsVendorsRouteNames.vendorBills,
      arguments: VendorBillsArgs(
        scope: scope,
        year: scope == 'outstanding' ||
                scope == 'overdue' ||
                scope == 'due_soon'
            ? null
            : _year,
        month: scope == 'outstanding' ||
                scope == 'overdue' ||
                scope == 'due_soon'
            ? null
            : _month,
        partnerId: _partnerId,
        partnerName: partnerName,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _load();
  }

  Future<void> _loadAgreementsSummary() async {
    setState(() => _agreementsLoading = true);
    try {
      final summary = await _repo.fetchAgreementsSummary(partnerId: _partnerId);
      if (!mounted) return;
      setState(() {
        _agreementsSummary = summary;
        _agreementsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _agreementsLoading = false;
        _agreementsSummary ??= VendorsAgreementsSummary.empty();
      });
    }
  }

  void _onSectionTabChanged(int index) {
    if (index == _sectionTab) return;
    setState(() => _sectionTab = index);
    if (index == 1 && _agreementsSummary == null && !_agreementsLoading) {
      _loadAgreementsSummary();
    }
  }

  Future<void> _openAgreementsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AgreementsSheet(
        partnerId: _partnerId,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchDashboard(
        year: _year,
        partnerId: _partnerId,
        month: _month,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data.years.isNotEmpty && !data.years.contains(_year)) {
          _year = data.year;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load vendor KPIs.';
        _data ??= VendorsDashboardData.empty(year: _year, month: _month);
      });
    }
  }

  void _onYearChanged(int? year) {
    if (year == null || year == _year) return;
    setState(() => _year = year);
    _load();
  }

  void _onMonthChanged(int? month) {
    // null sentinel via 0 from dropdown "All"
    final next = (month == null || month == 0) ? null : month;
    if (next == _month) return;
    setState(() => _month = next);
    _load();
  }

  Future<void> _openVendorPicker() async {
    final result = await showModalBottomSheet<_VendorPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VendorPickerSheet(
        selectedPartnerId: _partnerId,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _partnerId = result.partnerId;
      _vendorLabel = result.label;
      _agreementsSummary = null;
    });
    _load();
    if (_sectionTab == 1) {
      unawaited(_loadAgreementsSummary());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? VendorsDashboardData.empty(year: _year, month: _month);
    final years = data.years.isNotEmpty
        ? data.years
        : <int>[_year - 2, _year - 1, _year];
    final months = data.months.isNotEmpty
        ? data.months
        : VendorsDashboardMonthPoint.emptySeries();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersRow(
            year: _year,
            years: years,
            month: _month,
            vendorLabel: _vendorLabel,
            onYearChanged: _onYearChanged,
            onMonthChanged: _onMonthChanged,
            onVendorTap: _openVendorPicker,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          SizedBox(
            height: 210,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PressableScale(
                        onTap: () => _openBills('purchases'),
                        child: _VendorsKpiCard(
                          titleLine1: 'Total',
                          titleLine2: 'Purchases',
                          value: _kmOnly(data.totalPurchasesFormatted),
                          footer: _month == null
                              ? 'YTD'
                              : _monthNames[_month! - 1],
                          footerAccent: _fmtMom(data.purchasesMomPct),
                          footerAccentColor: data.purchasesMomPct >= 0
                              ? VendorsTheme.iconPaid
                              : const Color(0xFFE53E3E),
                          icon: Icons.bar_chart_rounded,
                          borderColor: VendorsTheme.iconPurchases,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressableScale(
                        onTap: () => _openBills('paid'),
                        child: _VendorsKpiCard(
                          titleLine1: 'Total Paid',
                          titleLine2: 'to Vendors',
                          value: _kmOnly(data.totalPaidFormatted),
                          footer: data.paidInvoiceCount == 1
                              ? '1 invoice'
                              : '${data.paidInvoiceCount} invoices',
                          icon: Icons.check_box_rounded,
                          borderColor: VendorsTheme.iconPaid,
                          midText:
                              '${data.paidPct.toStringAsFixed(data.paidPct % 1 == 0 ? 0 : 1)}% Paid',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressableScale(
                        onTap: () => _openBills('outstanding'),
                        child: _VendorsKpiCard(
                          titleLine1: 'Outstanding',
                          titleLine2: 'Payables',
                          value: _kmOnly(data.outstandingPayablesFormatted),
                          footer: 'All open',
                          icon: Icons.account_balance_wallet_rounded,
                          borderColor: VendorsTheme.iconPayables,
                          midText: data.overdueCount > 0 ||
                                  data.overduePayables > 0.009
                              ? 'Overdue · ${data.overdueCount}'
                              : null,
                          midSubValue: data.overduePayables > 0.009
                              ? _kmOnly(data.overduePayablesFormatted)
                              : null,
                          midOnTap: () => _openBills('overdue'),
                          secondaryMidText: data.dueSoonCount > 0 ||
                                  data.dueSoonAmount > 0.009
                              ? 'Due soon · ${data.dueSoonCount}'
                              : null,
                          secondaryMidSubValue: data.dueSoonAmount > 0.009
                              ? _kmOnly(data.dueSoonAmountFormatted)
                              : null,
                          secondaryMidOnTap: () => _openBills('due_soon'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_loading)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _VendorsSectionTabs(
            selectedIndex: _sectionTab,
            onChanged: _onSectionTabChanged,
          ),
          const SizedBox(height: 14),
          if (_sectionTab == 0) ...[
            _PurchasesTrendCard(
              months: months,
              year: _year,
              highlightMonth: _month,
              peakAnnotation: data.peakAnnotation,
              loading: _loading,
            ),
            const SizedBox(height: 18),
            _AgingBreakdownCard(
              buckets: data.aging.isNotEmpty
                  ? data.aging
                  : VendorsDashboardAgingBucket.empty(),
              loading: _loading,
            ),
          ] else
            _ContractSummaryCard(
              summary: _agreementsSummary ?? VendorsAgreementsSummary.empty(),
              loading: _agreementsLoading && _agreementsSummary == null,
              onViewAll: _openAgreementsSheet,
            ),
        ],
      ),
    );
  }
}

class _VendorPickResult {
  const _VendorPickResult({required this.label, this.partnerId});

  final int? partnerId;
  final String label;
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.year,
    required this.years,
    required this.month,
    required this.vendorLabel,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onVendorTap,
  });

  final int year;
  final List<int> years;
  final int? month;
  final String vendorLabel;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final VoidCallback onVendorTap;

  static const _monthItems = <(int, String)>[
    (0, 'All'),
    (1, 'Jan'),
    (2, 'Feb'),
    (3, 'Mar'),
    (4, 'Apr'),
    (5, 'May'),
    (6, 'Jun'),
    (7, 'Jul'),
    (8, 'Aug'),
    (9, 'Sep'),
    (10, 'Oct'),
    (11, 'Nov'),
    (12, 'Dec'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _GlassDropdown<int>(
            value: year,
            hint: 'Year',
            items: [
              for (final y in years)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: onYearChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _GlassDropdown<int>(
            value: month ?? 0,
            hint: 'Month',
            items: [
              for (final item in _monthItems)
                DropdownMenuItem(value: item.$1, child: Text(item.$2)),
            ],
            onChanged: onMonthChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onVendorTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        vendorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassDropdown<T> extends StatelessWidget {
  const _GlassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.any((e) => e.value == value) ? value : null,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          dropdownColor: const Color(0xFF464648),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _VendorsSectionTabs extends StatelessWidget {
  const _VendorsSectionTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VendorsSectionTab(
              label: 'Bills Overview',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _VendorsSectionTab(
              label: 'Agreements',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorsSectionTab extends StatelessWidget {
  const _VendorsSectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? VendorsTheme.kpiGradientTop.withValues(alpha: 0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? VendorsTheme.electricBorder.withValues(alpha: 0.85)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? VendorsTheme.iconPaid : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractSummaryCard extends StatelessWidget {
  const _ContractSummaryCard({
    required this.summary,
    required this.loading,
    required this.onViewAll,
  });

  final VendorsAgreementsSummary summary;
  final bool loading;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VendorsTheme.kpiGradientTop,
            VendorsTheme.kpiGradientBottom,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Contract Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: VendorsTheme.kpiTitle,
                  ),
                ),
                const SizedBox(height: 8),
                _ContractSummaryRow(
                  icon: Icons.view_in_ar_rounded,
                  iconColor: VendorsTheme.iconContracts,
                  label: 'Total Contracts',
                  value: '${summary.totalCount}',
                ),
                _ContractSummaryRow(
                  icon: Icons.check_circle_rounded,
                  iconColor: VendorsTheme.iconActive,
                  label: 'Active Contracts',
                  value: '${summary.activeCount}',
                  valueColor: VendorsTheme.iconActive,
                ),
                _ContractSummaryRow(
                  icon: Icons.schedule_rounded,
                  iconColor: VendorsTheme.iconExpiring,
                  label: 'Contracts Expiring in 90 Days',
                  value: '${summary.expiring90Count}',
                  valueColor: VendorsTheme.iconExpiring,
                ),
                _ContractSummaryRow(
                  icon: Icons.assignment_rounded,
                  iconColor: const Color(0xFF6B5B95),
                  label: 'Total Contract Value',
                  value:
                      '${_VendorsDashboardBodyState._kmOnly(summary.totalValueFormatted)} AED',
                  stackedValue: true,
                  showDivider: false,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: onViewAll,
                    child: Text(
                      'View all contracts',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: VendorsTheme.iconPaid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VendorsTheme.kpiTitle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContractSummaryRow extends StatelessWidget {
  const _ContractSummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.stackedValue = false,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool stackedValue;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final valueStyle = GoogleFonts.poppins(
      fontSize: stackedValue ? 16 : 15,
      fontWeight: FontWeight.w700,
      color: valueColor ?? VendorsTheme.kpiValue,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: stackedValue
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: stackedValue
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: VendorsTheme.kpiTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(value, style: valueStyle),
                        ],
                      )
                    : Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: VendorsTheme.kpiTitle,
                        ),
                      ),
              ),
              if (!stackedValue) Text(value, style: valueStyle),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: VendorsTheme.kpiTitle.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

class _AgreementsSheet extends StatefulWidget {
  const _AgreementsSheet({this.partnerId});

  final int? partnerId;

  @override
  State<_AgreementsSheet> createState() => _AgreementsSheetState();
}

class _AgreementsSheetState extends State<_AgreementsSheet> {
  static const _pageSize = 40;

  final _repo = VendorsDashboardRepository();
  final _search = TextEditingController();
  Timer? _debounce;

  List<VendorsAgreementRow> _items = const [];
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _query = value;
      _load(reset: true);
    });
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.pixels < n.metrics.maxScrollExtent - 120) return false;
    if (_loading || _loadingMore || !_hasMore) return false;
    _load(reset: false);
    return false;
  }

  Future<void> _load({required bool reset}) async {
    final gen = ++_requestGen;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final offset = reset ? 0 : _items.length;
    try {
      final page = await _repo.fetchAgreements(
        partnerId: widget.partnerId,
        keyword: _query,
        offset: offset,
        limit: _pageSize,
      );
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _items = const [];
          _error = 'Could not load contracts.';
        }
      });
    }
  }

  String _fmtDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '—' : raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Future<void> _openAttachmentsSheet(VendorsAgreementRow row) async {
    final title = row.number.isEmpty ? 'Contract #${row.id}' : row.number;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AgreementAttachmentsSheet(
        agreementId: row.id,
        agreementTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final showEmpty = !_loading && _items.isEmpty;
    final showFooter = _loadingMore || (_hasMore && _items.isNotEmpty);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                VendorsTheme.deepLight,
                VendorsTheme.deepDark,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Contracts',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      cursorColor: VendorsTheme.glowBright,
                      decoration: InputDecoration(
                        hintText: 'Search code, project code, vendor…',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.10),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: VendorsTheme.glowBright,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading && _items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2.5,
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: _items.length +
                              (showEmpty ? 1 : 0) +
                              (showFooter ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _items.length) {
                              final row = _items[index];
                              return _AgreementListTile(
                                number: row.number.isEmpty
                                    ? 'Contract #${row.id}'
                                    : row.number,
                                start: _fmtDate(row.startDate),
                                end: _fmtDate(row.endDate),
                                value:
                                    '${_VendorsDashboardBodyState._kmOnly(row.valueFormatted)} AED',
                                onTap: () => _openAttachmentsSheet(row),
                              );
                            }
                            if (showEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error ??
                                      (q.isEmpty
                                          ? 'No contracts found.'
                                          : 'No contracts match your search.'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgreementAttachmentsSheet extends StatefulWidget {
  const _AgreementAttachmentsSheet({
    required this.agreementId,
    required this.agreementTitle,
  });

  final int agreementId;
  final String agreementTitle;

  @override
  State<_AgreementAttachmentsSheet> createState() =>
      _AgreementAttachmentsSheetState();
}

class _AgreementAttachmentsSheetState extends State<_AgreementAttachmentsSheet> {
  final _repo = VendorsDashboardRepository();
  bool _loading = true;
  String? _error;
  List<VendorsAgreementAttachmentRow> _items = const [];
  String _headerTitle = '';

  @override
  void initState() {
    super.initState();
    _headerTitle = widget.agreementTitle;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchAgreementAttachments(
        agreementId: widget.agreementId,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        if (page.agreementName.trim().isNotEmpty) {
          _headerTitle = page.agreementName.trim();
        }
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = const [];
        _error = 'Could not load files.';
      });
    }
  }

  Future<void> _viewFile(VendorsAgreementAttachmentRow file) async {
    await DocumentAttachmentOpener.openById(
      context,
      attachmentId: file.id,
      hintName: file.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.40,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                VendorsTheme.deepLight,
                VendorsTheme.deepDark,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      tooltip: 'Back to contracts',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Files',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _items.isEmpty
                        ? ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(24),
                            children: [
                              Text(
                                _error ?? 'No files attached to this contract.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final file = _items[index];
                              return _AgreementAttachmentTile(
                                name: file.name,
                                typeLabel: file.attachmentTypeLabel,
                                onView: () => _viewFile(file),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgreementAttachmentTile extends StatelessWidget {
  const _AgreementAttachmentTile({
    required this.name,
    required this.typeLabel,
    required this.onView,
  });

  final String name;
  final String typeLabel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (typeLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: VendorsTheme.glowBright,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'View',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementListTile extends StatelessWidget {
  const _AgreementListTile({
    required this.number,
    required this.start,
    required this.end,
    required this.value,
    required this.onTap,
  });

  final String number;
  final String start;
  final String end;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Start  $start',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'End  $end',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VendorsTheme.glowBright,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorPickerSheet extends StatefulWidget {
  const _VendorPickerSheet({
    required this.selectedPartnerId,
  });

  final int? selectedPartnerId;

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  static const _pageSize = 40;

  final _repo = VendorsDashboardRepository();
  final _search = TextEditingController();
  Timer? _debounce;

  List<VendorsDashboardVendorOption> _items = const [];
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _query = value;
      _load(reset: true);
    });
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.pixels < n.metrics.maxScrollExtent - 120) return false;
    if (_loading || _loadingMore || !_hasMore) return false;
    _load(reset: false);
    return false;
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final offset = reset ? 0 : _items.length;
    try {
      final page = await _repo.fetchPartners(
        keyword: _query,
        offset: offset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _items = const [];
          _error = 'Could not load vendors.';
        }
      });
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'supplier':
        return 'Supplier';
      case 'subcontractor':
        return 'Subcontractor';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final showAllTile = q.isEmpty;
    final showEmpty = !_loading && _items.isEmpty;
    final showFooter = _loadingMore || (_hasMore && _items.isNotEmpty);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                VendorsTheme.deepLight,
                VendorsTheme.deepDark,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select Vendor',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      cursorColor: VendorsTheme.glowBright,
                      decoration: InputDecoration(
                        hintText: 'Search vendors…',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.10),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: VendorsTheme.glowBright,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading && _items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2.5,
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: (showAllTile ? 1 : 0) +
                              _items.length +
                              (showEmpty ? 1 : 0) +
                              (showFooter ? 1 : 0),
                          itemBuilder: (context, index) {
                            var i = index;
                            if (showAllTile) {
                              if (i == 0) {
                                return _VendorPickTile(
                                  title: 'All Vendors',
                                  selected: widget.selectedPartnerId == null,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_rounded,
                                      color: VendorsTheme.glowBright,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(
                                    context,
                                    const _VendorPickResult(
                                      label: 'All Vendors',
                                    ),
                                  ),
                                );
                              }
                              i -= 1;
                            }

                            if (i < _items.length) {
                              final v = _items[i];
                              final typeLabel = _typeLabel(v.customerType);
                              return _VendorPickTile(
                                title: typeLabel.isEmpty
                                    ? v.name
                                    : '${v.name} · $typeLabel',
                                selected: widget.selectedPartnerId == v.id,
                                leading: ClientsPartnerAvatar(
                                  imageUrl: v.imageUrl,
                                  name: v.name,
                                  size: 40,
                                ),
                                onTap: () => Navigator.pop(
                                  context,
                                  _VendorPickResult(
                                    partnerId: v.id,
                                    label: v.name,
                                  ),
                                ),
                              );
                            }
                            i -= _items.length;

                            if (showEmpty && i == 0) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error ??
                                      (q.isEmpty
                                          ? 'No vendors found.'
                                          : 'No vendors match your search.'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _loadingMore
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VendorPickTile extends StatelessWidget {
  const _VendorPickTile({
    required this.title,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? VendorsTheme.glowBright.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: VendorsTheme.glowBright,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Light metallic 3D KPI card — icon → title → number / AED → meta → footer.
class _VendorsKpiCard extends StatelessWidget {
  const _VendorsKpiCard({
    required this.titleLine1,
    required this.titleLine2,
    required this.value,
    required this.footer,
    required this.icon,
    required this.borderColor,
    this.midText,
    this.midSubValue,
    this.midOnTap,
    this.secondaryMidText,
    this.secondaryMidSubValue,
    this.secondaryMidOnTap,
    this.footerAccent,
    this.footerAccentColor,
  });

  final String titleLine1;
  final String titleLine2;
  final String value;
  final String footer;
  final IconData icon;
  final Color borderColor;
  final String? midText;
  final String? midSubValue;
  final VoidCallback? midOnTap;
  final String? secondaryMidText;
  final String? secondaryMidSubValue;
  final VoidCallback? secondaryMidOnTap;
  final String? footerAccent;
  final Color? footerAccentColor;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.04),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              VendorsTheme.kpiGradientTop,
              VendorsTheme.kpiGradientBottom,
            ],
          ),
          border: Border.all(color: borderColor, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: borderColor.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Same teal→blue icon gradient on every KPI card (ref).
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  VendorsTheme.iconPurchases,
                  VendorsTheme.iconPaid,
                  VendorsTheme.iconPayables,
                ],
              ).createShader(bounds),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              titleLine1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VendorsTheme.kpiTitle,
                height: 1.1,
              ),
            ),
            Text(
              titleLine2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VendorsTheme.kpiTitle,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: VendorsTheme.kpiValue,
                height: 1.05,
              ),
            ),
            Text(
              'AED',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: VendorsTheme.kpiMuted,
                height: 1.1,
              ),
            ),
            if (midText != null) ...[
              const SizedBox(height: 4),
              _KpiMidBlock(
                label: midText!,
                value: midSubValue,
                onTap: midOnTap,
              ),
            ],
            if (secondaryMidText != null) ...[
              const SizedBox(height: 2),
              _KpiMidBlock(
                label: secondaryMidText!,
                value: secondaryMidSubValue,
                onTap: secondaryMidOnTap,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    footer,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: VendorsTheme.kpiMuted,
                    ),
                  ),
                ),
                if (footerAccent != null) ...[
                  Text(
                    ' · ',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: VendorsTheme.kpiMuted,
                    ),
                  ),
                  Text(
                    footerAccent!,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: footerAccentColor ?? VendorsTheme.iconPurchases,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMidBlock extends StatelessWidget {
  const _KpiMidBlock({
    required this.label,
    this.value,
    this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: VendorsTheme.kpiMuted,
            height: 1.1,
          ),
        ),
        if (value != null) ...[
          const SizedBox(height: 1),
          Text(
            value!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: VendorsTheme.kpiValue,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// Section 3 — 3D metallic shell + dark TradingView-style purchases trend.
class _PurchasesTrendCard extends StatefulWidget {
  const _PurchasesTrendCard({
    required this.months,
    required this.year,
    required this.peakAnnotation,
    required this.highlightMonth,
    required this.loading,
  });

  final List<VendorsDashboardMonthPoint> months;
  final int year;
  final String peakAnnotation;
  final int? highlightMonth;
  final bool loading;

  @override
  State<_PurchasesTrendCard> createState() => _PurchasesTrendCardState();
}

class _PurchasesTrendCardState extends State<_PurchasesTrendCard> {
  int? _touchedIndex;

  static const _fullMonthNames = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  int? get _effectiveHighlightMonth {
    if (_touchedIndex != null) return _touchedIndex! + 1;
    return widget.highlightMonth;
  }

  void _updateTouch(Offset local, Size size) {
    const leftPad = 36.0;
    const rightPad = 8.0;
    final chartW = size.width - leftPad - rightPad;
    if (chartW <= 0) return;
    final x = local.dx - leftPad;
    if (x < 0 || x > chartW) {
      if (_touchedIndex != null) setState(() => _touchedIndex = null);
      return;
    }
    final idx = (x / (chartW / 12)).floor().clamp(0, 11);
    if (idx != _touchedIndex) setState(() => _touchedIndex = idx);
  }

  void _clearTouch() {
    if (_touchedIndex != null) setState(() => _touchedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.03),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              VendorsTheme.kpiGradientTop,
              VendorsTheme.kpiGradientBottom,
            ],
          ),
          border: Border.all(color: VendorsTheme.chartHighlight, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: VendorsTheme.deepDark.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: VendorsTheme.chartHighlight.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Purchases Trend (Monthly)',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: VendorsTheme.chartTitle,
                    ),
                  ),
                ),
                if (widget.peakAnnotation.isNotEmpty)
                  Text(
                    widget.peakAnnotation,
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: VendorsTheme.chartPeak,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: VendorsTheme.chartBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: VendorsTheme.chartHighlight.withValues(alpha: 0.55),
                        width: 0.6,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 10, 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) => _updateTouch(e.localPosition, size),
                            onPointerMove: (e) => _updateTouch(e.localPosition, size),
                            onPointerUp: (_) => _clearTouch(),
                            onPointerCancel: (_) => _clearTouch(),
                            child: CustomPaint(
                              painter: _TradingViewPurchasesPainter(
                                months: widget.months,
                                highlightMonth: _effectiveHighlightMonth,
                                touchedIndex: _touchedIndex,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_touchedIndex != null &&
                      _touchedIndex! >= 0 &&
                      _touchedIndex! < widget.months.length)
                    _ChartTooltip(
                      point: widget.months[_touchedIndex!],
                      year: widget.year,
                      monthName: _fullMonthNames[_touchedIndex!],
                    ),
                  if (widget.loading)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: VendorsTheme.deepDark.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VendorsTheme.glowBright,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.point,
    required this.year,
    required this.monthName,
  });

  final VendorsDashboardMonthPoint point;
  final int year;
  final String monthName;

  @override
  Widget build(BuildContext context) {
    final inv = point.invoiceCount == 1
        ? '1 Invoice'
        : '${point.invoiceCount} Invoices';

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VendorsTheme.deepDark.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: VendorsTheme.chartHighlight.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.amountFull,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VendorsTheme.kpiGradientTop,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$monthName $year · $inv',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: VendorsTheme.chartAxis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimalist step / slash line chart (TradingView terminal look).
class _TradingViewPurchasesPainter extends CustomPainter {
  _TradingViewPurchasesPainter({
    required this.months,
    required this.highlightMonth,
    this.touchedIndex,
  });

  final List<VendorsDashboardMonthPoint> months;
  final int? highlightMonth;
  final int? touchedIndex;

  static const _xLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (var i = 0; i < 12; i++)
        i < months.length ? months[i].amount : 0.0,
    ];
    final maxRaw = values.fold<double>(0, (m, v) => math.max(m, v));
    final maxY = _niceMax(maxRaw);
    const tickCount = 5;
    final tickStep = maxY / tickCount;

    const leftPad = 36.0;
    const rightPad = 8.0;
    const topPad = 18.0;
    const bottomPad = 22.0;

    final chart = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    final axisPaint = Paint()
      ..color = VendorsTheme.chartAxis.withValues(alpha: 0.85)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = VendorsTheme.chartAxis.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = VendorsTheme.chartLine
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;

    final highlightPaint = Paint()
      ..color = VendorsTheme.chartHighlight.withValues(alpha: 0.75)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Axes
    canvas.drawLine(
      Offset(chart.left, chart.top),
      Offset(chart.left, chart.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );

    final labelStyle = GoogleFonts.robotoMono(
      fontSize: 9,
      fontWeight: FontWeight.w500,
      color: VendorsTheme.chartAxis,
    );

    // Y label "AED" + ticks
    final aedTp = TextPainter(
      text: TextSpan(text: 'AED', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    aedTp.paint(canvas, Offset(4, chart.top - aedTp.height - 2));

    for (var i = 0; i <= tickCount; i++) {
      final v = tickStep * i;
      final y = chart.bottom - (v / maxY) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.left + 5, y), tickPaint);
      final tp = TextPainter(
        text: TextSpan(text: _fmtAxis(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chart.left - tp.width - 4, y - tp.height / 2));
    }

    // X ticks + labels
    final slot = chart.width / 12;
    for (var i = 0; i < 12; i++) {
      final x = chart.left + slot * (i + 0.5);
      canvas.drawLine(
        Offset(x, chart.bottom),
        Offset(x, chart.bottom - 4),
        tickPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: _xLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 4));
    }

    // Highlight selected month (trading-view ruler)
    if (highlightMonth != null && highlightMonth! >= 1 && highlightMonth! <= 12) {
      final x = chart.left + slot * (highlightMonth! - 0.5);
      final dash = highlightPaint
        ..color = VendorsTheme.chartHighlight.withValues(alpha: 0.55);
      _drawDashedLine(
        canvas,
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        dash,
      );
    }

    // Step / slash series: horizontal plateau + diagonal connector
    final path = Path();
    var started = false;
    for (var i = 0; i < 12; i++) {
      final y = chart.bottom - (values[i] / maxY) * chart.height;
      final x0 = chart.left + slot * i;
      final x1 = chart.left + slot * (i + 1);
      // plateaus span most of the month slot; leave a gap for the slash
      final plateauEnd = x0 + slot * 0.72;
      if (!started) {
        path.moveTo(x0 + 2, y);
        started = true;
      } else {
        // diagonal from previous plateau end to this month start
        path.lineTo(x0 + 2, y);
      }
      path.lineTo(plateauEnd, y);
      if (i < 11) {
        final nextY = chart.bottom - (values[i + 1] / maxY) * chart.height;
        path.lineTo(x1 - 2, nextY);
      }
    }
    canvas.drawPath(path, linePaint);

    if (touchedIndex != null &&
        touchedIndex! >= 0 &&
        touchedIndex! < 12) {
      final y = chart.bottom - (values[touchedIndex!] / maxY) * chart.height;
      final x = chart.left + slot * (touchedIndex! + 0.5);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = VendorsTheme.chartHighlight,
      );
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = VendorsTheme.kpiGradientTop,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * math.min(drawn + dash, total);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  static double _niceMax(double raw) {
    if (raw <= 0) return 1000;
    final padded = raw * 1.08;
    final exp = (math.log(padded) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final n = padded / base;
    final nice = n <= 1
        ? 1.0
        : n <= 2
            ? 2.0
            : n <= 5
                ? 5.0
                : 10.0;
    return nice * base;
  }

  static String _fmtAxis(double value) {
    if (value >= 1000000) {
      final t = (value / 1000000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '${t}M';
    }
    if (value >= 1000) {
      final t = (value / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '${t}K';
    }
    if (value == 0) return '0K';
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _TradingViewPurchasesPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.highlightMonth != highlightMonth ||
        oldDelegate.touchedIndex != touchedIndex;
  }
}

/// Section 4 — Aging Breakdown (Payables) in the metallic 3D shell.
class _AgingBreakdownCard extends StatelessWidget {
  const _AgingBreakdownCard({
    required this.buckets,
    required this.loading,
  });

  final List<VendorsDashboardAgingBucket> buckets;
  final bool loading;

  static const _barIconColors = [
    VendorsTheme.iconPurchases,
    VendorsTheme.iconPaid,
    VendorsTheme.glowBright,
    VendorsTheme.iconPayables,
  ];

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.03),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              VendorsTheme.kpiGradientTop,
              VendorsTheme.kpiGradientBottom,
            ],
          ),
          border: Border.all(color: VendorsTheme.chartHighlight, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: VendorsTheme.deepDark.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: VendorsTheme.chartHighlight.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aging Breakdown (Payables)',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VendorsTheme.chartTitle,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < buckets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _AgingRow(
                    bucket: buckets[i],
                    barColor: VendorsTheme.lightBar(
                      _barIconColors[i % _barIconColors.length],
                    ),
                    iconColor: _barIconColors[i % _barIconColors.length],
                  ),
                ],
              ],
            ),
            if (loading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VendorsTheme.deepDark.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VendorsTheme.glowBright,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({
    required this.bucket,
    required this.barColor,
    required this.iconColor,
  });

  final VendorsDashboardAgingBucket bucket;
  final Color barColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final pct = bucket.percent.clamp(0, 100) / 100.0;
    final pctLabel =
        '${bucket.percent.toStringAsFixed(bucket.percent % 1 == 0 ? 0 : 1)}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Coming soon',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  bucket.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: VendorsTheme.iconPayables,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  bucket.amountFormatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: VendorsTheme.chartTitle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 12,
                  child: CustomPaint(
                    painter: _AgingBarPainter(
                      fraction: pct.toDouble(),
                      fillColor: barColor,
                      trackColor: VendorsTheme.deepMid,
                      dotColor: VendorsTheme.glowBright,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  pctLabel,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgingBarPainter extends CustomPainter {
  _AgingBarPainter({
    required this.fraction,
    required this.fillColor,
    required this.trackColor,
    required this.dotColor,
  });

  final double fraction;
  final Color fillColor;
  final Color trackColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(r, Paint()..color = trackColor);

    // Dotted remainder (wireframe texture).
    final dotPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 4.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height * 0.5),
        Offset(math.min(x + 1.5, size.width), size.height * 0.5),
        dotPaint,
      );
    }

    final fillW = (size.width * fraction.clamp(0.0, 1.0)).toDouble();
    if (fillW > 0) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillW, size.height),
        const Radius.circular(2),
      );
      canvas.drawRRect(fill, Paint()..color = fillColor);
    }
  }

  @override
  bool shouldRepaint(covariant _AgingBarPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.dotColor != dotColor;
  }
}
