import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_summary_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color kAnalyticsFadedPanel = Color(0x38FFFFFF);
const Color kAnalyticsFadedPanelBorder = Color(0x55FFFFFF);
const Color kKpiWoGreen = Color(0xFF2A9D8F);
const Color kKpiExpenseRed = Color(0xFF9A031E);
const Color kKpiEstimationPurple = Color(0xFF7B2CBF);
const Color kKpiSpendBlue = Color(0xFF0077B6);
const Color kLegendSkyBlue = Color(0xFF38BDF8);
const Color _kChartNavy = Color(0xFF4A6FA5);
const Color _kChartMaroon = Color(0xFFC97A8A);

/// Brighter icon tint for contrast on faded dark panels.
Color kpiIconColor(Color accent) =>
    Color.lerp(accent, Colors.white, 0.42) ?? accent;

Color legendColorForExpense(String name, int index) {
  final lower = name.toLowerCase();
  if (lower.contains('electrical') || lower.contains('electric')) {
    return kLegendSkyBlue;
  }
  if (lower.contains('civil')) return kKpiWoGreen;
  if (lower.contains('mechanical') || lower.contains('mechnical')) {
    return kKpiSpendBlue;
  }
  if (lower.contains('ict') || lower.contains(' it')) {
    return kKpiEstimationPurple;
  }
  if (lower.contains('hse')) return const Color(0xFFE9C46A);
  const palette = [kKpiWoGreen, kKpiSpendBlue, kKpiExpenseRed, kLegendSkyBlue];
  return palette[index % palette.length];
}

enum _AnalyticsDetailView { graph, summary }

BoxDecoration analyticsGlassPanel({double radius = 14}) => BoxDecoration(
      color: kAnalyticsFadedPanel,
      borderRadius: BorderRadius.circular(radius.tr),
      border: Border.all(color: kAnalyticsFadedPanelBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );

BoxDecoration kpiFadedFill(Color accent) => BoxDecoration(
      color: accent.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14.tr),
      border: Border.all(color: accent.withValues(alpha: 0.38)),
    );

class ProjectExpenseSummaryPanel extends StatefulWidget {
  const ProjectExpenseSummaryPanel({super.key, required this.summary});

  final ProjectExpenseSummaryModel summary;

  @override
  State<ProjectExpenseSummaryPanel> createState() =>
      _ProjectExpenseSummaryPanelState();
}

class _ProjectExpenseSummaryPanelState extends State<ProjectExpenseSummaryPanel> {
  _AnalyticsDetailView _detailView = _AnalyticsDetailView.graph;

  static final _moneyFmt = NumberFormat('#,##0.00', 'en');

  String _formatMoney(double value) =>
      '${_moneyFmt.format(value)} ${widget.summary.currency}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(summary: widget.summary, formatMoney: _formatMoney),
        SizedBox(height: 10.th),
        _DetailViewToggle(
          selected: _detailView,
          onGraph: () => setState(() => _detailView = _AnalyticsDetailView.graph),
          onSummary: () =>
              setState(() => _detailView = _AnalyticsDetailView.summary),
        ),
        SizedBox(height: 10.th),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _detailView == _AnalyticsDetailView.graph
                ? _TopThreeExpenseChart(
                    key: const ValueKey('graph'),
                    summary: widget.summary,
                  )
                : _ExpenseSummaryTable(
                    key: const ValueKey('summary'),
                    summary: widget.summary,
                    formatMoney: _formatMoney,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DetailViewToggle extends StatelessWidget {
  const _DetailViewToggle({
    required this.selected,
    required this.onGraph,
    required this.onSummary,
  });

  final _AnalyticsDetailView selected;
  final VoidCallback onGraph;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleChip(
            label: 'Graph',
            icon: Icons.show_chart_rounded,
            selected: selected == _AnalyticsDetailView.graph,
            onTap: onGraph,
          ),
        ),
        SizedBox(width: 10.tw),
        Expanded(
          child: _ToggleChip(
            label: 'Summary',
            icon: Icons.table_rows_rounded,
            selected: selected == _AnalyticsDetailView.summary,
            onTap: onSummary,
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.tr),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 11.th),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14.tr),
                  gradient: LinearGradient(
                    colors: [
                      ProjectsDashboardTheme.navy.withValues(alpha: 0.88),
                      ProjectsDashboardTheme.maroon.withValues(alpha: 0.75),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                )
              : analyticsGlassPanel(radius: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.tsp,
                color: selected
                    ? ProjectsDashboardTheme.white
                    : ProjectsDashboardTheme.greyPanel,
              ),
              SizedBox(width: 8.tw),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? ProjectsDashboardTheme.white
                      : ProjectsDashboardTheme.greyPanel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.formatMoney});

  final ProjectExpenseSummaryModel summary;
  final String Function(double) formatMoney;

  static const _tiles = [
    (
      label: 'Total W.O amount',
      icon: Icons.account_balance_wallet_rounded,
      accent: kKpiWoGreen,
    ),
    (
      label: 'Total expenses',
      icon: Icons.payments_rounded,
      accent: kKpiExpenseRed,
    ),
    (
      label: 'Estimation',
      icon: Icons.calculate_rounded,
      accent: kKpiEstimationPurple,
    ),
    (
      label: 'Spend % of W.O',
      icon: Icons.percent_rounded,
      accent: kKpiSpendBlue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final values = [
      formatMoney(summary.totalWoAmount),
      formatMoney(summary.totalExpenses),
      formatMoney(summary.estimationAmount),
      '${summary.spendPercentOfWo.toStringAsFixed(1)}%',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _KpiTile(spec: _tiles[0], value: values[0])),
            SizedBox(width: 8.tw),
            Expanded(child: _KpiTile(spec: _tiles[1], value: values[1])),
          ],
        ),
        SizedBox(height: 8.th),
        Row(
          children: [
            Expanded(child: _KpiTile(spec: _tiles[2], value: values[2])),
            SizedBox(width: 8.tw),
            Expanded(child: _KpiTile(spec: _tiles[3], value: values[3])),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.spec, required this.value});

  final ({String label, IconData icon, Color accent}) spec;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 8.th),
      decoration: kpiFadedFill(spec.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, color: kpiIconColor(spec.accent), size: 18.tsp),
          SizedBox(height: 5.th),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.tw, vertical: 2.th),
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(6.tr),
            ),
            child: Text(
              spec.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9.tsp,
                fontWeight: FontWeight.w700,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w800,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopThreeExpenseChart extends StatelessWidget {
  const _TopThreeExpenseChart({super.key, required this.summary});

  final ProjectExpenseSummaryModel summary;

  /// X-axis labels: 3–5 chars to avoid overlap (e.g. "Civil", "Mecha", "Elect").
  String _shortName(String name) {
    const maxLen = 5;
    var n = name.trim();
    if (n.isEmpty) return '—';
    n = n.split(RegExp(r'\s+')).first;
    n = n.replaceAll(RegExp(r'expense$', caseSensitive: false), '').trim();
    if (n.isEmpty) return '—';
    if (n.length <= maxLen) return n;
    return n.substring(0, maxLen);
  }

  @override
  Widget build(BuildContext context) {
    final items = summary.topExpenses.take(3).toList();
    final leadPct =
        items.isNotEmpty ? items.first.percent : summary.spendPercentOfWo;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 8.th),
      decoration: analyticsGlassPanel(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 3 expenses',
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w700,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                    Text(
                      'Share of project spend',
                      style: GoogleFonts.poppins(
                        fontSize: 10.tsp,
                        color: ProjectsDashboardTheme.greyPanel,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${leadPct.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 22.tsp,
                  fontWeight: FontWeight.w800,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.th),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No top expense data',
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        color: ProjectsDashboardTheme.greyPanel,
                      ),
                    ),
                  )
                : _TopThreeSplineChart(items: items, shortName: _shortName),
          ),
          if (items.isNotEmpty)
            for (var i = 0; i < items.length; i++)
              _TopExpenseLegendRow(
                item: items[i],
                color: legendColorForExpense(items[i].name, i),
              ),
        ],
      ),
    );
  }
}

class _TopThreeSplineChart extends StatelessWidget {
  const _TopThreeSplineChart({
    required this.items,
    required this.shortName,
  });

  final List<ProjectExpenseTopItem> items;
  final String Function(String) shortName;

  @override
  Widget build(BuildContext context) {
    final maxY = items.fold<double>(0, (m, e) => e.percent > m ? e.percent : m);
    final chartMax = (maxY * 1.25).clamp(10.0, 100.0);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (items.length - 1).toDouble().clamp(0, 2),
        minY: 0,
        maxY: chartMax,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.12),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28.tw,
              interval: chartMax / 4,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > chartMax) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 9.tsp,
                    color: ProjectsDashboardTheme.greyPanel,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24.th,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= items.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.only(top: 4.th),
                  child: SizedBox(
                    width: 40.tw,
                    child: Text(
                      shortName(items[i].name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 8.tsp,
                        fontWeight: FontWeight.w600,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < items.length; i++)
                FlSpot(i.toDouble(), items[i].percent),
            ],
            isCurved: true,
            curveSmoothness: 0.38,
            color: _kChartNavy,
            barWidth: 2.8,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final dotColor = legendColorForExpense(
                  items[index].name,
                  index,
                );
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: ProjectsDashboardTheme.white,
                  strokeWidth: 2.5,
                  strokeColor: dotColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kChartNavy.withValues(alpha: 0.42),
                  _kChartMaroon.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

class _TopExpenseLegendRow extends StatelessWidget {
  const _TopExpenseLegendRow({required this.item, required this.color});

  final ProjectExpenseTopItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3.th),
      child: Row(
        children: [
          Container(
            width: 8.tw,
            height: 8.tw,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.tw),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w600,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          Text(
            '${item.percent.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w800,
              color: kpiIconColor(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseSummaryTable extends StatelessWidget {
  const _ExpenseSummaryTable({
    super.key,
    required this.summary,
    required this.formatMoney,
  });

  final ProjectExpenseSummaryModel summary;
  final String Function(double) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: analyticsGlassPanel(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 6.th),
            child: Text(
              'Expense summary',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w700,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          _SummaryTableHeader(),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                children: [
                  for (var i = 0; i < summary.expenseLines.length; i++)
                    _SummaryRow(
                      label: summary.expenseLines[i].label,
                      value: formatMoney(summary.expenseLines[i].amount),
                      emphasized: false,
                      shaded: i.isOdd,
                    ),
                  _SummaryRow(
                    label: 'Total expenses',
                    value: formatMoney(summary.totalExpenses),
                    emphasized: true,
                    shaded: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 9.th),
      decoration: BoxDecoration(
        color: ProjectsDashboardTheme.navy.withValues(alpha: 0.35),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Expense',
              style: GoogleFonts.poppins(
                fontSize: 10.tsp,
                fontWeight: FontWeight.w700,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          Text(
            'Amount (AED)',
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w700,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.emphasized,
    required this.shaded,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final rowBg = emphasized
        ? ProjectsDashboardTheme.maroon.withValues(alpha: 0.28)
        : shaded
            ? ProjectsDashboardTheme.navy.withValues(alpha: 0.14)
            : Colors.transparent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: emphasized ? 13.tsp : 12.tsp,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: emphasized ? 13.tsp : 12.tsp,
              fontWeight: FontWeight.w700,
              color: emphasized
                  ? ProjectsDashboardTheme.white
                  : ProjectsDashboardTheme.greyPanel,
            ),
          ),
        ],
      ),
    );
  }
}
