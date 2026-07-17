import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
            SizedBox(height: 10.th),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 16.th),
                children: [
                  Container(
                    padding: EdgeInsets.all(14.tw),
                    decoration: MyReportsTheme.glassCard(radius: 18.tr),
                    child: Row(
                      children: [
                        Icon(widget.category.icon, size: 20.tsp, color: MyReportsTheme.textPrimary),
                        SizedBox(width: 8.tw),
                        Expanded(
                          child: Text(
                            widget.category.subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 11.tsp,
                              color: MyReportsTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.th),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
                    decoration: MyReportsTheme.glassCard(radius: 16.tr),
                    child: Row(
                      children: [
                        _StatPill(label: 'Reports', value: '${widget.category.types.length * 3}'),
                        SizedBox(width: 8.tw),
                        _StatPill(label: 'AI Ready', value: '${widget.category.types.length}'),
                        SizedBox(width: 8.tw),
                        _StatPill(label: 'Trend', value: '+12%'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.th),
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
                          margin: EdgeInsets.only(bottom: 10.th),
                          padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 14.th),
                          decoration: MyReportsTheme.glassCard(radius: 18.tr),
                          child: Row(
                            children: [
                              Container(
                                width: 28.tw,
                                height: 28.tw,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10.tr),
                                ),
                                child: Icon(
                                  widget.category.icon,
                                  size: 15.tsp,
                                  color: MyReportsTheme.textPrimary,
                                ),
                              ),
                              SizedBox(width: 10.tw),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.tsp,
                                        fontWeight: FontWeight.w700,
                                        color: MyReportsTheme.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4.th),
                                    Text(
                                      type.subtitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.tsp,
                                        color: MyReportsTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14.tsp, color: MyReportsTheme.textPrimary),
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
        padding: EdgeInsets.symmetric(vertical: 6.th),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(12.tr),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w800,
                color: MyReportsTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 8.tsp,
                color: MyReportsTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
