import 'package:el_race/ui/presentation/my_reports/data/my_reports_demo_data.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReportsStandardView extends StatelessWidget {
  const MyReportsStandardView({super.key, required this.data});

  final ReportPreviewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryCard(label: 'Current snapshot', value: data.summaryValue),
        SizedBox(height: 10.h),
        ...data.rows.map(
          (row) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: MyReportsTheme.glassCard(radius: 14.r),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: MyReportsTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  row.value,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: MyReportsTheme.textPrimary,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  row.status,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: MyReportsTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MyReportsAnalyticsView extends StatelessWidget {
  const MyReportsAnalyticsView({super.key, required this.data});

  final ReportPreviewData data;

  @override
  Widget build(BuildContext context) {
    final hasHeatmap = data.heatmap.isNotEmpty;
    return Column(
      children: [
        _SummaryCard(label: 'Analytics', value: data.summaryValue),
        SizedBox(height: 10.h),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(14.w),
          decoration: MyReportsTheme.glassCard(radius: 16.r),
          child: Column(
            children: [
              SizedBox(
                height: 120.h,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.chart
                      .map(
                        (e) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: e.y.h,
                                  decoration: BoxDecoration(
                                    color: MyReportsTheme.accent.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(e.x, style: TextStyle(fontSize: 9.sp)),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        if (hasHeatmap) ...[
          SizedBox(height: 10.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(12.w),
            decoration: MyReportsTheme.glassCard(radius: 16.r),
            child: Column(
              children: data.heatmap
                  .map(
                    (r) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      child: Row(
                        children: [
                          SizedBox(width: 30.w, child: Text(r.label)),
                          ...r.values.map(
                            (v) => Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 2.w),
                                padding: EdgeInsets.symmetric(vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Color.lerp(
                                    MyReportsTheme.frostBlue,
                                    MyReportsTheme.royalBlue,
                                    (v / 100).clamp(0.0, 1.0),
                                  ),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '$v%',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9.sp),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class MyReportsAiView extends StatelessWidget {
  const MyReportsAiView({super.key, required this.data});

  final ReportPreviewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryCard(label: 'AI Report Copilot', value: data.summaryValue),
        SizedBox(height: 10.h),
        ...data.insights.asMap().entries.map(
          (entry) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: MyReportsTheme.glassCard(radius: 14.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12.r,
                  backgroundColor: MyReportsTheme.accent.withValues(alpha: 0.2),
                  child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11.sp)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.title,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: MyReportsTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        entry.value.body,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: MyReportsTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: MyReportsTheme.glassCard(radius: 16.r),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: MyReportsTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              color: MyReportsTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
