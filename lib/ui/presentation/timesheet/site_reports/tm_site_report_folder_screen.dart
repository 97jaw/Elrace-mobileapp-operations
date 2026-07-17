import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/models/tm_site_report_composer_result.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_actions.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_composer_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_gallery_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_pdf_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_view_pdf.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_site_report_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

enum TmFolderEntryAction {
  none,
  openNewReport,
}

/// Reports inside one folder — list, gallery, PDF, composer.
class TmSiteReportFolderScreen extends StatefulWidget {
  const TmSiteReportFolderScreen({
    super.key,
    required this.folder,
    required this.projectId,
    required this.projectName,
    this.entryAction = TmFolderEntryAction.none,
  });

  final FolderModel folder;
  final String projectId;
  final String projectName;
  final TmFolderEntryAction entryAction;

  @override
  State<TmSiteReportFolderScreen> createState() =>
      _TmSiteReportFolderScreenState();
}

class _TmSiteReportFolderScreenState extends State<TmSiteReportFolderScreen> {
  bool _loading = true;
  String _search = '';
  List<ReportModel> _reports = const [];
  String? _busyReportId;
  bool _handledEntry = false;

  ReportProvider get _provider =>
      Provider.of<ReportProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _provider.fetchAllReports(
        folderID: widget.folder.id,
        projectId: widget.projectId,
      );
      _reports = List<ReportModel>.from(_provider.reports);
    } catch (_) {
      _reports = const [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
    await _handleEntry();
  }

  Future<void> _handleEntry() async {
    if (_handledEntry || !mounted) return;
    _handledEntry = true;
    if (widget.entryAction == TmFolderEntryAction.openNewReport) {
      await _openComposer();
    }
  }

  Future<void> _openComposer({ReportModel? existing}) async {
    final result =
        await Navigator.of(context).push<TmSiteReportComposerResult>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _provider,
          child: TmSiteReportComposerScreen(
            folder: widget.folder,
            projectName: widget.projectName,
            existingReport: existing,
          ),
        ),
      ),
    );
    await _load();
    if (result != null && mounted && result.pdfUrl.trim().isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TmSiteReportPdfScreen(
            url: result.pdfUrl,
            title: result.pdfTitle,
            reportId: result.reportId,
            projectId: widget.projectId,
            projectName: widget.projectName,
          ),
        ),
      );
    }
  }

  Future<void> _openGallery(ReportModel report) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _provider,
          child: TmSiteReportGalleryScreen(
            report: report,
            folder: widget.folder,
            folderName: widget.folder.name,
            projectName: widget.projectName,
            projectId: widget.projectId,
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _openPdf(ReportModel report) async {
    if (!report.hasGeneratedPdf && report.reportType == null) {
      final detail = await _provider.fetchReportDetailFromApi(report.id);
      final hasPhotos = (detail?.reportItems.length ?? 0) >= 3;
      if (!hasPhotos) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF not generated — open Gallery to add photos and generate',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _busyReportId = report.id);
    try {
      await TmSiteReportViewPdf.open(
        context,
        provider: _provider,
        report: report,
        folder: widget.folder,
        projectName: widget.projectName,
        projectId: widget.projectId,
      );
    } finally {
      if (mounted) setState(() => _busyReportId = null);
    }
  }

  List<ReportModel> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _reports;
    return _reports.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final reports = _filtered;

    return TmSiteReportGlassShell(
      title: widget.folder.name,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TimesheetModuleColors.primary,
        foregroundColor: TimesheetModuleColors.surface,
        icon: Icon(PhosphorIcons.plus()),
        label: Text(
          'New report',
          style: TimesheetModuleTypography.button(
            color: TimesheetModuleColors.surface,
          ),
        ),
        onPressed: () => _openComposer(),
      ),
      body: _loading
          ? const TimesheetLoadingState(
              style: TimesheetLoadingStyle.list,
              itemCount: 5,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    TimesheetModuleLayout.cardSpacing,
                    TimesheetModuleLayout.screenPaddingH,
                    0,
                  ),
                  child: TmSearchField(
                    hintText: 'Search by name or report ID',
                    onDebouncedChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    8,
                    TimesheetModuleLayout.screenPaddingH,
                    0,
                  ),
                  child: Text(
                    '${_reports.length} report(s) in this folder',
                    style: TimesheetModuleTypography.caption().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    color: TimesheetModuleColors.primary,
                    onRefresh: _load,
                    child: reports.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: const [
                              TimesheetEmptyState(
                                message:
                                    'No reports yet.\nTap New report to add photos and generate a PDF.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              TimesheetModuleLayout.screenPaddingH,
                              0,
                              TimesheetModuleLayout.screenPaddingH,
                              88,
                            ),
                            itemCount: reports.length,
                            separatorBuilder: (_, __) => const SizedBox(
                              height: TimesheetModuleLayout.cardSpacing,
                            ),
                            itemBuilder: (context, index) {
                              final report = reports[index];
                              return TmSiteReportRow(
                                report: report,
                                busy: _busyReportId == report.id,
                                onGallery: () => _openGallery(report),
                                onPdf: () => _openPdf(report),
                                onMore: () => TmSiteReportActions.showReportMenu(
                                  context,
                                  provider: _provider,
                                  report: report,
                                  onChanged: _load,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
