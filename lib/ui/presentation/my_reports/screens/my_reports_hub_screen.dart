import 'package:el_race/ui/presentation/my_reports/data/my_reports_catalog.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_ai_report_screen.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_category_screen.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_site_report_project_picker_screen.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_background.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_glass_header.dart';
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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(
                        height: 172.h,
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
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _HubReportCard(
                              title: 'Management',
                              subtitle: 'Executive level analytics',
                              icon: Icons.insights_rounded,
                              countLabel: '4',
                              liveCount: '8',
                              aiCount: '4',
                              gradient: MyReportsTheme.managementCardGradient,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MyReportsCategoryScreen(
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
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10.w,
                        mainAxisSpacing: 10.h,
                        childAspectRatio: 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          // First grid card: live Site Report entry (not catalog demo).
                          if (i == 0) {
                            return _HubReportCard(
                              title: 'Site Report',
                              subtitle: 'Create and view project site reports',
                              icon: Icons.photo_camera_back_rounded,
                              countLabel: '—',
                              liveCount: 'Live',
                              aiCount: '—',
                              gradient: MyReportsTheme.siteReportCardGradient,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyReportsSiteReportProjectPickerScreen(),
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
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20.r),
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
                  width: 34.w,
                  height: 34.w,
                  alignment: Alignment.center,
                  decoration: MyReportsTheme.iconBadge(),
                  child: Icon(
                    icon,
                    size: 18.sp,
                    color: MyReportsTheme.royalBlue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: MyReportsTheme.counterBadge(),
                  child: Text(
                    countLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.labelOnGradient,
                height: 1.15,
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              height: 28.h,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: MyReportsTheme.bodyOnGradient,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _CounterChip(label: 'Live', value: liveCount),
                SizedBox(width: 6.w),
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
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10.r),
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
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.textPrimary,
              ),
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 8.sp,
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
