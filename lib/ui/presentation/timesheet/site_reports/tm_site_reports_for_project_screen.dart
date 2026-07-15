import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_project_site_reports_tab.dart';
import 'package:flutter/material.dart';

/// Standalone shell for [TmProjectSiteReportsTab] (e.g. My Reports entry).
class TmSiteReportsForProjectScreen extends StatefulWidget {
  const TmSiteReportsForProjectScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<TmSiteReportsForProjectScreen> createState() =>
      _TmSiteReportsForProjectScreenState();
}

class _TmSiteReportsForProjectScreenState
    extends State<TmSiteReportsForProjectScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await CompanyRepository().getCompany();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.projectName.isNotEmpty
        ? widget.projectName
        : 'Site reports';

    return TmSiteReportGlassShell(
      title: title,
      body: !_ready
          ? const TimesheetLoadingState(
              style: TimesheetLoadingStyle.folders,
              itemCount: 3,
            )
          : TmProjectSiteReportsTab(
              projectId: widget.projectId,
              projectName: widget.projectName,
            ),
    );
  }
}
