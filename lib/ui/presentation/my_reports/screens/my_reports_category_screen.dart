import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_detail_screen.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_background.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_filter_strip.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_glass_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReportsCategoryScreen extends StatefulWidget {
  const MyReportsCategoryScreen({super.key, required this.category});

  final MyReportCategory category;

  @override
  State<MyReportsCategoryScreen> createState() => _MyReportsCategoryScreenState();
}

class _MyReportsCategoryScreenState extends State<MyReportsCategoryScreen> {
  String _period = MyReportsFilterStrip.periods.first;
  String _quickFilter = MyReportsFilterStrip.quickFilters.first;

  @override
  Widget build(BuildContext context) {
    return MyReportsBackground(
      gradient: MyReportsTheme.gradientForCategory(widget.category),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MyReportsGlassHeader(title: widget.category.title),
            MyReportsFilterStrip(
              period: _period,
              onPeriodChanged: (v) => setState(() => _period = v),
              quickFilter: _quickFilter,
              onQuickFilterChanged: (v) => setState(() => _quickFilter = v),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: MyReportsTheme.glassCard(radius: 18.r),
                    child: Row(
                      children: [
                        Icon(widget.category.icon, size: 20.sp, color: MyReportsTheme.textPrimary),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            widget.category.subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: MyReportsTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: MyReportsTheme.glassCard(radius: 16.r),
                    child: Row(
                      children: [
                        _StatPill(label: 'Reports', value: '${widget.category.types.length * 3}'),
                        SizedBox(width: 8.w),
                        _StatPill(label: 'AI Ready', value: '${widget.category.types.length}'),
                        SizedBox(width: 8.w),
                        _StatPill(label: 'Trend', value: '+12%'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ...widget.category.types.map(
                      (type) => GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MyReportsDetailScreen(
                                category: widget.category,
                                reportType: type,
                                period: _period,
                                quickFilter: _quickFilter,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          decoration: MyReportsTheme.glassCard(radius: 18.r),
                          child: Row(
                            children: [
                              Container(
                                width: 28.w,
                                height: 28.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  widget.category.icon,
                                  size: 15.sp,
                                  color: MyReportsTheme.textPrimary,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: MyReportsTheme.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      type.subtitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.sp,
                                        color: MyReportsTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: MyReportsTheme.textPrimary),
                            ],
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

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 8.sp,
                color: MyReportsTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
