import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyReportsFilterStrip extends StatelessWidget {
  const MyReportsFilterStrip({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    required this.quickFilter,
    required this.onQuickFilterChanged,
  });

  final String period;
  final ValueChanged<String> onPeriodChanged;
  final String quickFilter;
  final ValueChanged<String> onQuickFilterChanged;

  static const periods = ['Today', 'Last 7 days', 'Last 30 days', 'All time'];
  static const quickFilters = ['All', 'Project A', 'Project B', 'Project C'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34.th,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final label = periods[i];
                final active = label == period;
                return GestureDetector(
                  onTap: () => onPeriodChanged(label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 7.th),
                    decoration: BoxDecoration(
                      color: active
                          ? MyReportsTheme.accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14.tr),
                      border: Border.all(
                        color: active
                            ? MyReportsTheme.accent.withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w600,
                        color: MyReportsTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => SizedBox(width: 8.tw),
              itemCount: periods.length,
            ),
          ),
          SizedBox(height: 8.th),
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 16.tsp, color: MyReportsTheme.textPrimary),
              SizedBox(width: 6.tw),
              Text(
                'Filter',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.tsp,
                  color: MyReportsTheme.textPrimary,
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.tw),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12.tr),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: quickFilter,
                      isExpanded: true,
                      items: quickFilters
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onQuickFilterChanged(v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
