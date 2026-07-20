import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProjectsKpiBoxesGrid extends StatelessWidget {
  const ProjectsKpiBoxesGrid({
    super.key,
    required this.stats,
    this.labels,
  });

  final ProjectsDashboardBoxStats stats;
  final ProjectsKpiBoxLabels? labels;

  @override
  Widget build(BuildContext context) {
    final l = labels ?? const ProjectsKpiBoxLabels();
    final valueFmt = NumberFormat('#,##0.##', 'en');
    final aedFmt = NumberFormat.compactCurrency(
      locale: 'en',
      symbol: 'AED ',
      decimalDigits: 1,
    );

    final items = <_BoxItem>[
      _BoxItem(
        label: l.agreements,
        value: '${stats.agreementsCount}',
        fill: const Color(0xFF1E2365).withOpacity(0.10),
      ),
      _BoxItem(
        label: l.totalProjects,
        value: valueFmt.format(stats.totalProjects),
        fill: const Color(0xFF1565C0).withOpacity(0.12),
      ),
      _BoxItem(
        label: l.portfolioValue,
        value: aedFmt.format(stats.portfolioValueAed),
        fill: const Color(0xFF2E7D32).withOpacity(0.12),
      ),
      _BoxItem(
        label: l.delayed,
        value: valueFmt.format(stats.delayedProjects),
        fill: const Color(0xFFEF6C00).withOpacity(0.14),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10.th,
        crossAxisSpacing: 10.tw,
        childAspectRatio: 1.25,
        children: [
          for (final item in items) _KpiBox(item: item),
        ],
      ),
    );
  }
}

class ProjectsKpiBoxLabels {
  const ProjectsKpiBoxLabels({
    this.agreements = 'Agreements',
    this.totalProjects = 'Total projects',
    this.portfolioValue = 'Portfolio (AED)',
    this.delayed = 'Delayed',
  });

  final String agreements;
  final String totalProjects;
  final String portfolioValue;
  final String delayed;
}

class _BoxItem {
  const _BoxItem({
    required this.label,
    required this.value,
    required this.fill,
  });

  final String label;
  final String value;
  final Color fill;
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({required this.item});

  final _BoxItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      decoration: BoxDecoration(
        color: item.fill,
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.th),
          Text(
            item.value,
            style: GoogleFonts.koulen(
              fontSize: 20.tsp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E2365),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
