import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_scurve_model.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_common.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum _ScurveGranularity { week, month }

class _DisplayPoint {
  const _DisplayPoint({
    required this.label,
    required this.planned,
    required this.actual,
  });
  final String label;
  final double planned;
  final double actual;
}

/// Info-tab progress block: overall progress bar + month/week filter + the
/// animated S-curve (planned vs actual) rendered in the warm theme.
class SmProgressSection extends StatefulWidget {
  const SmProgressSection({super.key, required this.data});

  final ProjectScurveData data;

  @override
  State<SmProgressSection> createState() => _SmProgressSectionState();
}

class _SmProgressSectionState extends State<SmProgressSection> {
  _ScurveGranularity _granularity = _ScurveGranularity.week;

  double get _progressPercent {
    final actual = widget.data.kpis.actual;
    if (actual > 0) return actual.clamp(0, 100);
    if (widget.data.series.isEmpty) return 0;
    return widget.data.series.last.actual.clamp(0, 100);
  }

  List<_DisplayPoint> get _points {
    final series = widget.data.series;
    if (series.isEmpty) return const [];
    if (_granularity == _ScurveGranularity.week) {
      return [
        for (final p in series)
          _DisplayPoint(
            label: 'W${p.week}',
            planned: p.planned,
            actual: p.actual,
          ),
      ];
    }
    // Month = group weeks into 4-week buckets, take the last (cumulative) point.
    final buckets = <int, ProjectScurvePoint>{};
    for (final p in series) {
      final month = ((p.week - 1) ~/ 4);
      final existing = buckets[month];
      if (existing == null || p.week >= existing.week) {
        buckets[month] = p;
      }
    }
    final months = buckets.keys.toList()..sort();
    return [
      for (final m in months)
        _DisplayPoint(
          label: 'M${m + 1}',
          planned: buckets[m]!.planned,
          actual: buckets[m]!.actual,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: smGlassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          _buildFilterRow(),
          const SizedBox(height: 20),
          SizedBox(height: 220, child: _buildChart()),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _progressPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Project Progress',
                style: TimesheetModuleTypography.h2().copyWith(
                  color: TimesheetModuleColors.ink,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%',
              style: TimesheetModuleTypography.statValue().copyWith(
                color: TimesheetModuleColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    height: 12,
                    width: c.maxWidth * (pct / 100).clamp(0.0, 1.0),
                    decoration: const BoxDecoration(
                      gradient: TimesheetModuleColors.warmButtonGradient,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Row(
        children: [
          _filterTab('Month', _ScurveGranularity.month),
          _filterTab('Week', _ScurveGranularity.week),
        ],
      ),
    );
  }

  Widget _filterTab(String label, _ScurveGranularity value) {
    final selected = _granularity == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _granularity = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? TimesheetModuleColors.warmButtonGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TimesheetModuleTypography.body().copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : TimesheetModuleColors.warmMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final points = _points;
    if (points.length < 2) {
      return Center(
        child: Text(
          'Not enough data to plot progress yet.',
          style: TimesheetModuleTypography.caption(),
        ),
      );
    }

    final maxX = (points.length - 1).toDouble();
    final labelStep = (points.length / 6).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: TimesheetModuleColors.glassBorder.withValues(alpha: 0.7),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}%',
                  style: TimesheetModuleTypography.caption().copyWith(
                    fontSize: 10,
                    color: TimesheetModuleColors.warmMuted,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelStep != 0 && i != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: TimesheetModuleTypography.caption().copyWith(
                      fontSize: 10,
                      color: TimesheetModuleColors.warmMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          // Planned (dashed, muted).
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].planned.clamp(0, 100)),
            ],
            isCurved: true,
            curveSmoothness: 0.3,
            color: TimesheetModuleColors.warmMuted,
            barWidth: 2,
            dashArray: const [6, 4],
            dotData: const FlDotData(show: false),
          ),
          // Actual (accent, filled area).
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].actual.clamp(0, 100)),
            ],
            isCurved: true,
            curveSmoothness: 0.3,
            color: TimesheetModuleColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TimesheetModuleColors.accent.withValues(alpha: 0.32),
                  TimesheetModuleColors.accent.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(TimesheetModuleColors.accent, 'Actual', dashed: false),
        const SizedBox(width: 18),
        _legendDot(TimesheetModuleColors.warmMuted, 'Planned', dashed: true),
      ],
    );
  }

  Widget _legendDot(Color color, String label, {required bool dashed}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TimesheetModuleTypography.caption().copyWith(
            color: TimesheetModuleColors.warmMuted,
          ),
        ),
      ],
    );
  }
}
