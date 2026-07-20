import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/data/clients_dashboard_repository.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/clients_vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Filters + invoicing line chart + Amount Due / Amount Paid tiles.
class ClientsInvoicingSection extends StatefulWidget {
  const ClientsInvoicingSection({super.key});

  @override
  State<ClientsInvoicingSection> createState() =>
      _ClientsInvoicingSectionState();
}

class _ClientsInvoicingSectionState extends State<ClientsInvoicingSection> {
  final _repo = ClientsDashboardRepository();

  late int _year;
  String _scope = 'top3';
  int? _partnerId;
  String _clientLabel = 'Top 3';
  ClientsDashboardData? _data;
  bool _loading = true;
  String? _error;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchDashboard(
        year: _year,
        scope: _scope,
        partnerId: _partnerId,
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
        _error = 'Could not load invoicing data.';
        _data ??= ClientsDashboardData.empty(year: _year);
      });
    }
  }

  void _onYearChanged(int? year) {
    if (year == null || year == _year) return;
    setState(() => _year = year);
    _load();
  }

  Future<void> _openClientPicker() async {
    final data = _data ?? ClientsDashboardData.empty(year: _year);
    final result = await showModalBottomSheet<_ClientPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientPickerSheet(
        clients: data.clients,
        topClients: data.topClients,
        selectedScope: _scope,
        selectedPartnerId: _partnerId,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _scope = result.scope;
      _partnerId = result.partnerId;
      _clientLabel = result.label;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? ClientsDashboardData.empty(year: _year);
    final years = data.years.isNotEmpty
        ? data.years
        : <int>[_year - 2, _year - 1, _year];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FiltersRow(
          year: _year,
          years: years,
          clientLabel: _clientLabel,
          onYearChanged: _onYearChanged,
          onClientTap: _openClientPicker,
        ),
        const SizedBox(height: 14),
        if (_loading && _data == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
            ),
          )
        else ...[
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
          _TopKpiTile(
            totalInvoicedFormatted: data.totalInvoicedFormatted,
          ),
          const SizedBox(height: 14),
          _ChartCard(
            months: data.months,
            year: _year,
            touchedIndex: _touchedIndex,
            onTouched: (i) => setState(() => _touchedIndex = i),
            onMonthTap: (month) {
              Navigator.of(context).pushNamed(
                ClientsVendorsRouteNames.outstandingInvoices,
                arguments: OutstandingInvoicesArgs(
                  year: _year,
                  month: month,
                ),
              );
            },
            loading: _loading,
          ),
          const SizedBox(height: 14),
          _MetricsPill(
            amountDueFormatted: data.amountDueFormatted,
            amountDueIsOverdue: data.amountDueIsOverdue,
            amountPaidFormatted: data.amountPaidFormatted,
            onAmountDueTap: () {
              Navigator.of(context).pushNamed(
                ClientsVendorsRouteNames.accountsReceivable,
              );
            },
            onAmountPaidTap: () {
              Navigator.of(context).pushNamed(
                ClientsVendorsRouteNames.outstandingInvoices,
                arguments: OutstandingInvoicesArgs(year: _year),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ClientPickResult {
  const _ClientPickResult({
    required this.scope,
    required this.label,
    this.partnerId,
  });

  final String scope;
  final int? partnerId;
  final String label;
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.year,
    required this.years,
    required this.clientLabel,
    required this.onYearChanged,
    required this.onClientTap,
  });

  final int year;
  final List<int> years;
  final String clientLabel;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onClientTap;

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
                DropdownMenuItem(
                  value: y,
                  child: Text('$y'),
                ),
            ],
            onChanged: onYearChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClientTap,
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
                        clientLabel,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          dropdownColor: const Color(0xFF023F80),
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

/// Draggable bottom sheet: Top 3 + searchable client list with logo + name.
class _ClientPickerSheet extends StatefulWidget {
  const _ClientPickerSheet({
    required this.clients,
    required this.topClients,
    required this.selectedScope,
    required this.selectedPartnerId,
  });

  final List<ClientsDashboardClientOption> clients;
  final List<ClientsDashboardClientOption> topClients;
  final String selectedScope;
  final int? selectedPartnerId;

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.clients
        : widget.clients
            .where((c) => c.name.toLowerCase().contains(q))
            .toList();

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
                ClientsVendorsTheme.deepLight,
                ClientsVendorsTheme.deepDark,
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
                      'Select Client',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      cursorColor: ClientsVendorsTheme.iconAccent,
                      decoration: InputDecoration(
                        hintText: 'Search clients…',
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
                            color: ClientsVendorsTheme.iconAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    if (q.isEmpty) ...[
                      _ClientPickTile(
                        title: 'Top 3',
                        subtitle: widget.topClients.isEmpty
                            ? 'Highest outstanding receivables'
                            : widget.topClients.map((c) => c.name).join(' · '),
                        selected: widget.selectedScope == 'top3',
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: ClientsVendorsTheme.iconAccent,
                            size: 20,
                          ),
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          const _ClientPickResult(
                            scope: 'top3',
                            label: 'Top 3',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                        child: Text(
                          'All clients',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                    for (final c in filtered)
                      _ClientPickTile(
                        title: c.name,
                        selected: widget.selectedScope == 'client' &&
                            widget.selectedPartnerId == c.id,
                        leading: ClientsPartnerAvatar(
                          imageUrl: c.imageUrl,
                          name: c.name,
                          size: 40,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          _ClientPickResult(
                            scope: 'client',
                            partnerId: c.id,
                            label: c.name,
                          ),
                        ),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No clients match your search.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClientPickTile extends StatelessWidget {
  const _ClientPickTile({
    required this.title,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
                    ? ClientsVendorsTheme.iconAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: ClientsVendorsTheme.iconAccent,
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

class _TopKpiTile extends StatelessWidget {
  const _TopKpiTile({required this.totalInvoicedFormatted});

  final String totalInvoicedFormatted;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.035),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ClientsVendorsTheme.cardGradientTopAlt,
              ClientsVendorsTheme.cardGradientBottomAlt,
            ],
          ),
          // Uniform border color required when using borderRadius.
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: ClientsVendorsTheme.cardGradientBottomAlt
                  .withValues(alpha: 0.50),
              blurRadius: 22,
              offset: const Offset(0, 14),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: ClientsVendorsTheme.iconAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Invoiced',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalInvoicedFormatted,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.months,
    required this.year,
    required this.touchedIndex,
    required this.onTouched,
    required this.onMonthTap,
    required this.loading,
  });

  final List<ClientsDashboardMonthPoint> months;
  final int year;
  final int? touchedIndex;
  final ValueChanged<int?> onTouched;
  final ValueChanged<int> onMonthTap;
  final bool loading;

  static final _aed = NumberFormat.currency(
    locale: 'en_AE',
    symbol: 'AED ',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < months.length; i++)
        FlSpot(i.toDouble(), months[i].amount),
    ];
    final maxAmount =
        months.fold<double>(0, (m, e) => e.amount > m ? e.amount : m);
    final maxY = maxAmount <= 0 ? 1000.0 : maxAmount * 1.15;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.04)
        ..rotateY(-0.02),
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ClientsVendorsTheme.cardGradientTop,
              ClientsVendorsTheme.cardGradientBottom,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color:
                  ClientsVendorsTheme.cardGradientBottom.withValues(alpha: 0.50),
              blurRadius: 24,
              offset: const Offset(0, 16),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            LineChart(
              LineChartData(
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 28,
                  getTouchedSpotIndicator: (bar, indexes) {
                    return indexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.55),
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, i) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: Colors.white,
                              strokeWidth: 0,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => ClientsVendorsTheme.tooltipBg,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touched) {
                      return touched.map((t) {
                        final i = t.x.round().clamp(0, months.length - 1);
                        final m = months[i];
                        final monthName =
                            DateFormat.MMMM().format(DateTime(year, m.month));
                        final inv = m.invoiceCount == 1
                            ? '1 Invoice'
                            : '${m.invoiceCount} Invoices';
                        return LineTooltipItem(
                          '${_aed.format(m.amount)}\n',
                          GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: '$monthName $year: $inv',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions ||
                        response?.lineBarSpots == null ||
                        response!.lineBarSpots!.isEmpty) {
                      onTouched(null);
                      return;
                    }
                    final monthIndex = response.lineBarSpots!.first.x.round();
                    onTouched(monthIndex);
                    // Open invoice list only on a deliberate tap (not drag).
                    if (event is FlTapUpEvent) {
                      final month = monthIndex + 1;
                      if (month >= 1 && month <= 12) {
                        onMonthTap(month);
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _shortAxis(value),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: ClientsVendorsTheme.axisLabel,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= months.length || i % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[i].label,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: ClientsVendorsTheme.axisLabel,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (touchedIndex != null &&
                        touchedIndex! >= 0 &&
                        touchedIndex! < months.length)
                      HorizontalLine(
                        y: months[touchedIndex!].amount,
                        color: Colors.white.withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: ClientsVendorsTheme.chartLine,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
            if (loading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
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
    );
  }

  static String _shortAxis(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toInt().toString();
  }
}

class _MetricsPill extends StatelessWidget {
  const _MetricsPill({
    required this.amountDueFormatted,
    required this.amountDueIsOverdue,
    required this.amountPaidFormatted,
    required this.onAmountDueTap,
    required this.onAmountPaidTap,
  });

  final String amountDueFormatted;
  final bool amountDueIsOverdue;
  final String amountPaidFormatted;
  final VoidCallback onAmountDueTap;
  final VoidCallback onAmountPaidTap;

  @override
  Widget build(BuildContext context) {
    final dueColor = amountDueIsOverdue
        ? ClientsVendorsTheme.amountDueOverdue
        : ClientsVendorsTheme.amountDueOpen;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(0.03)
        ..rotateY(0.02),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: ClientsVendorsTheme.metricPill.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color:
                  ClientsVendorsTheme.cardGradientBottom.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 12),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAmountDueTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _MetricHalf(
                      label: 'Amount Due',
                      value: amountDueFormatted,
                      valueColor: dueColor,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAmountPaidTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _MetricHalf(
                      label: 'Amount Paid',
                      value: amountPaidFormatted,
                      valueColor: ClientsVendorsTheme.amountPaid,
                      alignEnd: true,
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

class _MetricHalf extends StatelessWidget {
  const _MetricHalf({
    required this.label,
    required this.value,
    required this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 12 : 0,
        right: alignEnd ? 0 : 12,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label,
            textAlign: textAlign,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
