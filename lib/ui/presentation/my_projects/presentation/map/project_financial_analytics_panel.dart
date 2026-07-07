import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_dashboard_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Light-themed analytics block (KPI row + chart + period strip) for the Financial tab.
class FinancialAnalyticsPanel extends StatefulWidget {
  const FinancialAnalyticsPanel({
    super.key,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.netProfit,
    required this.marginPercent,
    required this.expenseDashboard,
    this.onAnalyze,
    this.onFilter,
  });

  final double incomeTotal;
  final double expenseTotal;
  final double netProfit;
  final double marginPercent;
  final ProjectExpenseDashboardModel? expenseDashboard;
  final VoidCallback? onAnalyze;
  final VoidCallback? onFilter;

  @override
  State<FinancialAnalyticsPanel> createState() => _FinancialAnalyticsPanelState();
}

class _Light {
  static const bg = Color(0xB8F0F5FA);
  static const card = Color(0xC8FFFFFF);
  static const border = Color(0x55FFFFFF);
  static const blue = Color(0xFF1E40AF);
  static const blueSoft = Color(0xFF3B82F6);
  static const maroon = Color(0xFF800020);
  static const maroonSoft = Color(0xFFA52A2A);
  static const expenseGrey = Color(0xFF64748B);
  static const netGreen = Color(0xFF059669);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const grid = Color(0x331E40AF);
}

class _FinancialAnalyticsPanelState extends State<FinancialAnalyticsPanel> {
  int _chartSeries = 0;
  int _selectedPeriod = 0;

  List<ProjectExpenseDashboardTrend> _effectiveTrend() {
    final raw = widget.expenseDashboard?.weeklyTrend ?? [];
    if (raw.length >= 3) return raw;
    final n = 5;
    final base = (widget.expenseTotal / n).abs().clamp(1000.0, double.infinity);
    return List.generate(
      n,
      (i) => ProjectExpenseDashboardTrend(
        week: '${DateTime.now().year}-${(i + 1).toString().padLeft(2, '0')}-01',
        amount: base * (0.88 + 0.04 * i),
      ),
    );
  }

  List<String> _monthLabels(int n) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return List.generate(n, (i) => m[i % 12]);
  }

  String _compactAed(double amount) {
    final negative = amount < 0;
    var v = amount.abs();
    String suffix = '';
    if (v >= 1e9) {
      v = v / 1e9;
      suffix = 'B';
    } else if (v >= 1e6) {
      v = v / 1e6;
      suffix = 'M';
    } else if (v >= 1e3) {
      v = v / 1e3;
      suffix = 'K';
    }
    final decimals = suffix.isEmpty
        ? 0
        : v >= 100
            ? 0
            : v >= 10
                ? 1
                : 2;
    final text =
        suffix.isEmpty ? '${amount.abs().toStringAsFixed(0)}' : '${v.toStringAsFixed(decimals)}$suffix';
    return negative ? '-$text' : text;
  }

  @override
  Widget build(BuildContext context) {
    final trend = _effectiveTrend();
    final n = trend.length;
    final period = n == 0 ? 0 : _selectedPeriod.clamp(0, n - 1);

    final expenseVals = trend.map((e) => e.amount.abs()).toList();
    final incomeVals = List<double>.generate(
      n,
      (i) => (widget.incomeTotal / math.max(n, 1)) * (0.92 + 0.03 * math.sin(i * 0.8)),
    );
    final netVals = List<double>.generate(n, (i) => incomeVals[i] - expenseVals[i]);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _Light.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _Light.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statement trend',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: _Light.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: _Light.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onFilter != null)
                Material(
                  color: _Light.bg,
                  borderRadius: BorderRadius.circular(12.r),
                  child: InkWell(
                    onTap: widget.onFilter,
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: _Light.border),
                      ),
                      child: Icon(Icons.tune_rounded, color: _Light.blue, size: 22.sp),
                    ),
                  ),
                ),
              if (widget.onAnalyze != null) ...[
                SizedBox(width: 8.w),
                Material(
                  color: _Light.maroon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                  child: IconButton(
                    onPressed: widget.onAnalyze,
                    icon: Icon(Icons.auto_awesome_rounded, color: _Light.maroon, size: 20.sp),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          _SeriesLegendRowLight(
            selected: _chartSeries,
            onSelect: (i) => setState(() => _chartSeries = i),
          ),
          SizedBox(height: 12.h),
          _KpiGlassRowLight(
            incomeCompact: '${_compactAed(widget.incomeTotal)} AED',
            expenseCompact: '${_compactAed(widget.expenseTotal)} AED',
            netCompact: '${_compactAed(widget.netProfit)} AED',
            expenseVals: expenseVals,
            incomeVals: incomeVals,
            netVals: netVals,
          ),
          SizedBox(height: 14.h),
          _MainComboChartLight(
            incomeVals: incomeVals,
            expenseVals: expenseVals,
            netVals: netVals,
            seriesMode: _chartSeries,
            selectedIndex: period,
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _monthLabels(n).length; i++) ...[
                  if (i > 0) SizedBox(width: 4.w),
                  InkWell(
                    onTap: () => setState(() => _selectedPeriod = i),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      child: Text(
                        _monthLabels(n)[i],
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: i == period ? FontWeight.w900 : FontWeight.w600,
                          color: i == period ? _Light.maroon : _Light.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesLegendRowLight extends StatelessWidget {
  const _SeriesLegendRowLight({
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, int idx, Color active, IconData icon) {
      final on = selected == idx;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(idx),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
            decoration: BoxDecoration(
              color: on ? active.withValues(alpha: 0.22) : active.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: on ? active : _Light.border,
                width: on ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.sp, color: on ? active : active.withValues(alpha: 0.85)),
                SizedBox(width: 5.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: on ? _Light.text : _Light.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('Income', 0, _Light.maroonSoft, Icons.trending_up_rounded),
        SizedBox(width: 8.w),
        item('Expense', 1, _Light.expenseGrey, Icons.trending_down_rounded),
        SizedBox(width: 8.w),
        item('Net profit', 2, _Light.netGreen, Icons.savings_outlined),
      ],
    );
  }
}

class _KpiGlassRowLight extends StatelessWidget {
  const _KpiGlassRowLight({
    required this.incomeCompact,
    required this.expenseCompact,
    required this.netCompact,
    required this.expenseVals,
    required this.incomeVals,
    required this.netVals,
  });

  final String incomeCompact;
  final String expenseCompact;
  final String netCompact;
  final List<double> expenseVals;
  final List<double> incomeVals;
  final List<double> netVals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiMiniCardLight(
            label: 'Income',
            value: incomeCompact,
            sparklineColor: _Light.maroonSoft,
            values: incomeVals,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _KpiMiniCardLight(
            label: 'Expense',
            value: expenseCompact,
            sparklineColor: _Light.expenseGrey,
            values: expenseVals,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _KpiMiniCardLight(
            label: 'Net profits',
            value: netCompact,
            sparklineColor: _Light.netGreen,
            values: netVals,
          ),
        ),
      ],
    );
  }
}

class _KpiMiniCardLight extends StatelessWidget {
  const _KpiMiniCardLight({
    required this.label,
    required this.value,
    required this.sparklineColor,
    required this.values,
  });

  final String label;
  final String value;
  final Color sparklineColor;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 10.h, 8.w, 8.h),
      decoration: BoxDecoration(
        color: sparklineColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: sparklineColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    color: _Light.text,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: sparklineColor.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(Icons.north_east_rounded, size: 13.sp, color: sparklineColor),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: _Light.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 20.h,
            child: _MicroSparklineLight(values: values, color: sparklineColor),
          ),
        ],
      ),
    );
  }
}

class _MicroSparklineLight extends StatelessWidget {
  const _MicroSparklineLight({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = values.fold<double>(0, (a, b) => math.max(a, b.abs()));
    if (m < 1e-6) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) SizedBox(width: 2.w),
          Expanded(
            child: Container(
              height: (16.h * (values[i].abs() / m).clamp(0.15, 1.0)).clamp(3.0, 16.h),
              decoration: BoxDecoration(
                color: i == values.length - 1 ? color : color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.vertical(top: Radius.circular(2.r)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MainComboChartLight extends StatelessWidget {
  const _MainComboChartLight({
    required this.incomeVals,
    required this.expenseVals,
    required this.netVals,
    required this.seriesMode,
    required this.selectedIndex,
  });

  final List<double> incomeVals;
  final List<double> expenseVals;
  final List<double> netVals;
  final int seriesMode;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _Light.bg,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _Light.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: CustomPaint(
            painter: _ComboChartPainterLight(
              income: incomeVals,
              expense: expenseVals,
              net: netVals,
              seriesMode: seriesMode,
              selectedIndex: selectedIndex,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ComboChartPainterLight extends CustomPainter {
  _ComboChartPainterLight({
    required this.income,
    required this.expense,
    required this.net,
    required this.seriesMode,
    required this.selectedIndex,
  });

  final List<double> income;
  final List<double> expense;
  final List<double> net;
  final int seriesMode;
  final int selectedIndex;

  String _axisAed(double v) {
    final a = v.abs();
    if (a >= 1e6) return 'AED ${(v / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e3) return 'AED ${(v / 1e3).toStringAsFixed(1)}K';
    return 'AED ${v.toStringAsFixed(0)}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(income.length, 1);
    const padL = 52.0;
    const padR = 10.0;
    const padT = 10.0;
    const padB = 8.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    double maxV = 1;
    for (var i = 0; i < n; i++) {
      maxV = math.max(maxV, income[i % income.length]);
      maxV = math.max(maxV, expense[i % expense.length]);
      maxV = math.max(maxV, net[i % net.length].abs());
    }
    maxV *= 1.12;
    final minV = -maxV * 0.3;
    final span = maxV - minV;

    double yScale(double v) => padT + chartH * (1 - (v - minV) / span);

    final gridPaint = Paint()..color = _Light.grid;
    for (var g = 0; g <= 5; g++) {
      final y = padT + chartH * g / 5;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
    }

    final tp = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    void drawYLabel(String s, double y) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(
          color: _Light.muted.withValues(alpha: 0.85),
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      );
      tp.layout(maxWidth: padL - 4);
      tp.paint(canvas, Offset(padL - tp.width - 2, y - tp.height / 2));
    }

    drawYLabel(_axisAed(maxV), yScale(maxV));
    drawYLabel(_axisAed((maxV + minV) / 2), yScale((maxV + minV) / 2));
    drawYLabel(_axisAed(minV), yScale(minV));

    final bucketW = chartW / n;
    final avgPrimary = seriesMode == 0
        ? income.fold<double>(0, (a, b) => a + b) / n
        : seriesMode == 1
            ? expense.fold<double>(0, (a, b) => a + b) / n
            : net.fold<double>(0, (a, b) => a + b) / n;

    final dashPath = Path();
    final ay = yScale(avgPrimary);
    for (double x = padL; x < size.width - padR; x += 7) {
      dashPath.moveTo(x, ay);
      dashPath.lineTo(x + 4, ay);
    }
    canvas.drawPath(
      dashPath,
      Paint()
        ..color = _Light.blue.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    void drawVBar(double cx, double val, Color c, double widthFactor) {
      final bw = bucketW * widthFactor;
      final x = cx - bw / 2;
      final top = yScale(val.clamp(minV, maxV));
      final bottom = yScale(0.0.clamp(minV, maxV));
      final h = (bottom - top).abs().clamp(2.0, chartH);
      final y = math.min(top, bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, h), const Radius.circular(3)),
        Paint()..color = c,
      );
    }

    for (var i = 0; i < n; i++) {
      final cx = padL + i * bucketW + bucketW / 2;
      final hInc = income[i % income.length];
      final hExp = expense[i % expense.length];
      final hNet = net[i % net.length];
      final lastZone = i >= n - 2;

      if (seriesMode == 0) {
        drawVBar(cx - bucketW * 0.12, hExp, _Light.expenseGrey.withValues(alpha: 0.35), 0.22);
        drawVBar(
          cx + bucketW * 0.12,
          hInc,
          lastZone ? _Light.maroon : _Light.maroonSoft.withValues(alpha: 0.75),
          0.22,
        );
      } else if (seriesMode == 1) {
        drawVBar(cx - bucketW * 0.1, hInc, _Light.maroonSoft.withValues(alpha: 0.22), 0.18);
        drawVBar(
          cx + bucketW * 0.1,
          hExp,
          lastZone ? _Light.blueSoft : _Light.expenseGrey.withValues(alpha: 0.65),
          0.22,
        );
      } else {
        drawVBar(
          cx,
          hNet.clamp(minV, maxV),
          lastZone ? _Light.netGreen : _Light.netGreen.withValues(alpha: 0.45),
          0.32,
        );
      }

      if (i == selectedIndex) {
        final markerV = seriesMode == 1 ? hExp : seriesMode == 2 ? hNet : hInc;
        canvas.drawCircle(
          Offset(cx, yScale(markerV.clamp(minV, maxV)) - 5),
          4.5,
          Paint()..color = _Light.maroonSoft,
        );
      }
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = seriesMode == 2 ? net[i % net.length] : income[i % income.length] - expense[i % expense.length];
      final cx = padL + i * bucketW + bucketW / 2;
      final cy = yScale(v.clamp(minV, maxV));
      if (i == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }
    final grad = ui.Gradient.linear(
      Offset(0, yScale(maxV)),
      Offset(0, size.height - padB),
      [_Light.blue.withValues(alpha: 0.12), Colors.transparent],
    );
    final fillPath = Path.from(path)
      ..lineTo(padL + chartW, size.height - padB)
      ..lineTo(padL, size.height - padB)
      ..close();
    canvas.drawPath(fillPath, Paint()..shader = grad);

    canvas.drawPath(
      path,
      Paint()
        ..color = _Light.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ComboChartPainterLight oldDelegate) {
    return oldDelegate.seriesMode != seriesMode ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.income.length != income.length;
  }
}
