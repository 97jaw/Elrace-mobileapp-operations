import 'dart:math' as math;

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_reports/data/my_reports_catalog.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_ai_report_screen.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_category_screen.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_background.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_glass_header.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_reports_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReportsHubScreen extends StatelessWidget {
  const MyReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gridCategories = MyReportsCatalog.categories
        .where((e) => e.type != MyReportCategoryType.management)
        .toList(growable: false);

    return MyReportsBackground(
      gradient: MyReportsTheme.aiHubGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const MyReportsGlassHeader(
              title: 'My Reports',
              onDarkBackground: false,
              transparentTopBar: true,
            ),
            Expanded(
              child: TabletContentFrame(
                child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.tw, 10.th, 16.tw, 10.th),
                    sliver: SliverToBoxAdapter(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isTab =
                              ResponsiveBreakpoints.useTabletLayout(context);
                          // Wider cards need more height so they don't look flat.
                          final featuredH = isTab
                              ? math.max(200.0, constraints.maxWidth * 0.22)
                              : 172.th;
                          return SizedBox(
                            height: featuredH,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _HubReportCard(
                                    title: 'Elrace AI Report',
                                    subtitle: 'Generate smart report drafts',
                                    icon: Icons.auto_awesome_rounded,
                                    countLabel: '41',
                                    liveCount: '12',
                                    aiCount: '41',
                                    gradient: MyReportsTheme.featuredCardGradient,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MyReportsAiReportScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 10.tw),
                                Expanded(
                                  child: _HubReportCard(
                                    title: 'Management',
                                    subtitle: 'Executive level analytics',
                                    icon: Icons.insights_rounded,
                                    countLabel: '4',
                                    liveCount: '8',
                                    aiCount: '4',
                                    gradient:
                                        MyReportsTheme.managementCardGradient,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MyReportsCategoryScreen(
                                            category: MyReportsCatalog.byType(
                                              MyReportCategoryType.management,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 16.th),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            ResponsiveBreakpoints.useTabletLayout(context)
                                ? 3
                                : 2,
                        crossAxisSpacing: 10.tw,
                        mainAxisSpacing: 10.th,
                        // Slightly taller cells on tablet (lower ratio = taller).
                        childAspectRatio:
                            ResponsiveBreakpoints.useTabletLayout(context)
                                ? 0.85
                                : 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          // First grid card: live Site Report entry (not catalog demo).
                          if (i == 0) {
                            return _HubReportCard(
                              title: 'Site Report',
                              subtitle: 'Create and view site reports',
                              icon: Icons.photo_camera_back_rounded,
                              countLabel: '—',
                              liveCount: 'Live',
                              aiCount: '—',
                              gradient: MyReportsTheme.siteReportCardGradient,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TmSiteReportsListScreen(),
                                  ),
                                );
                              },
                            );
                          }
                          final category = gridCategories[i - 1];
                          return _HubReportCard(
                            title: category.title,
                            subtitle: category.subtitle,
                            icon: category.icon,
                            countLabel: '${category.types.length}',
                            liveCount: '${category.types.length * 2}',
                            aiCount: '${category.types.length}',
                            gradient:
                                MyReportsTheme.gradientForCategory(category),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MyReportsCategoryScreen(
                                    category: category,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: gridCategories.length + 1,
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubReportCard extends StatelessWidget {
  const _HubReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.countLabel,
    required this.liveCount,
    required this.aiCount,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String countLabel;
  final String liveCount;
  final String aiCount;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(12.tw),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20.tr),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: MyReportsTheme.deepNavy.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34.tw,
                  height: 34.tw,
                  alignment: Alignment.center,
                  decoration: MyReportsTheme.iconBadge(),
                  child: Icon(
                    icon,
                    size: 18.tsp,
                    color: MyReportsTheme.royalBlue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
                  decoration: MyReportsTheme.counterBadge(),
                  child: Text(
                    countLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10.tsp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.th),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.labelOnGradient,
                height: 1.15,
              ),
            ),
            SizedBox(height: 4.th),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w600,
                    color: MyReportsTheme.bodyOnGradient,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.th),
            Row(
              children: [
                _CounterChip(label: 'Live', value: liveCount),
                SizedBox(width: 6.tw),
                _CounterChip(label: 'AI', value: aiCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 5.th),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10.tr),
          border: Border.all(
            color: MyReportsTheme.frostBlue.withValues(alpha: 0.95),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 10.tsp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.textPrimary,
              ),
            ),
            SizedBox(width: 4.tw),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 8.tsp,
                  fontWeight: FontWeight.w600,
                  color: MyReportsTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
