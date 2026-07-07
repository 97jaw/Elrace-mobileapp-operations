import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/presentation/screens/report_photos/report_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Provides [ReportProvider] for the legacy capture / gallery screen.
class TmSiteReportPhotosPage extends StatelessWidget {
  const TmSiteReportPhotosPage({
    super.key,
    required this.reportProvider,
    required this.report,
    required this.folderName,
    required this.folderId,
    this.createReportOnFirstImage = false,
    this.onReportUpdated,
  });

  final ReportProvider reportProvider;
  final ReportModel report;
  final String folderName;
  final String folderId;
  final bool createReportOnFirstImage;
  final VoidCallback? onReportUpdated;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportProvider>.value(
      value: reportProvider,
      child: ReportPhotosScreen(
        report: report,
        folderName: folderName,
        folderId: folderId,
        createReportOnFirstImage: createReportOnFirstImage,
        onReportUpdated: onReportUpdated,
      ),
    );
  }
}
