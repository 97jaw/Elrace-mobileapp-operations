import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_background.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_glass_header.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReportsAiReportScreen extends StatelessWidget {
  const MyReportsAiReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MyReportsBackground(
      gradient: MyReportsTheme.aiHubGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const MyReportsGlassHeader(
              title: 'Elrace AI Report',
              onDarkBackground: false,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: MyReportsTheme.glassCard(radius: 20.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: MyReportsTheme.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18.sp,
                                color: MyReportsTheme.textPrimary,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'AI Report Builder',
                                style: GoogleFonts.poppins(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: MyReportsTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'Prepare final report with AI summary, anomalies, and recommendations.',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: MyReportsTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        ...const [
                          _AiStep(label: 'Collect source report data'),
                          _AiStep(label: 'Generate narrative summary'),
                          _AiStep(label: 'Highlight risks and blockers'),
                          _AiStep(label: 'Draft final management report'),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  SizedBox(
                    height: 48.h,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showProductivityComingSoonSnackBar(
                          context,
                          featureLabel: 'Elrace AI report generation',
                        );
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        'Generate AI Report',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
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

class _AiStep extends StatelessWidget {
  const _AiStep({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16.sp, color: MyReportsTheme.accent),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: MyReportsTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
