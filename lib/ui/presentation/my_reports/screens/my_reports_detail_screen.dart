import 'package:el_race/ui/presentation/my_reports/data/my_reports_demo_data.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_type.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_view_mode.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_background.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_glass_header.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_preview_views.dart';
import 'package:el_race/ui/presentation/my_reports/widgets/my_reports_view_bar.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_coming_soon.dart';
import 'package:flutter/material.dart';

class MyReportsDetailScreen extends StatefulWidget {
  const MyReportsDetailScreen({
    super.key,
    required this.category,
    required this.reportType,
    required this.period,
    required this.quickFilter,
  });

  final MyReportCategory category;
  final MyReportType reportType;
  final String period;
  final String quickFilter;

  @override
  State<MyReportsDetailScreen> createState() => _MyReportsDetailScreenState();
}

class _MyReportsDetailScreenState extends State<MyReportsDetailScreen> {
  late MyReportViewMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = MyReportViewMode.standard;
  }

  @override
  Widget build(BuildContext context) {
    final data = MyReportsDemoData.forType(widget.reportType, period: widget.period);
    return MyReportsBackground(
      gradient: MyReportsTheme.gradientForCategory(widget.category),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
              children: [
                MyReportsGlassHeader(
                  title: widget.reportType.title,
                  trailing: const [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: MyReportsTheme.textPrimary,
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: MyReportsViewBar.scrollBottomPadding(context),
                    ),
                    children: [
                      if (_mode == MyReportViewMode.standard) MyReportsStandardView(data: data),
                      if (_mode == MyReportViewMode.analytics) MyReportsAnalyticsView(data: data),
                      if (_mode == MyReportViewMode.ai) MyReportsAiView(data: data),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showProductivityComingSoonSnackBar(
                              context,
                              featureLabel: 'AI final report generation',
                            );
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate AI Final Report'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MyReportsViewBar(
                mode: _mode,
                onModeChanged: (v) => setState(() => _mode = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
