import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
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

/// Flat Site Reports list — no project picker, no folder drill-down.
class TmSiteReportsListScreen extends StatefulWidget {
  const TmSiteReportsListScreen({
    super.key,
    this.title = 'Site Reports',
    this.embedInParent = false,
    this.reportProvider,
  });

  final String title;

  /// When true, render only the list body (for PM/FM project detail tabs).
  final bool embedInParent;

  /// Optional shared provider (PM/FM tabs).
  final ReportProvider? reportProvider;

  @override
  State<TmSiteReportsListScreen> createState() =>
      _TmSiteReportsListScreenState();
}

class _TmSiteReportsListScreenState extends State<TmSiteReportsListScreen> {
  static const int _pageSize = 15;

  late final ReportProvider _provider;
  bool _ownsProvider = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  String _search = '';
  List<ReportModel> _reports = const [];
  String? _busyReportId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.reportProvider != null) {
      _provider = widget.reportProvider!;
    } else {
      _provider = ReportProvider();
      _ownsProvider = true;
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsProvider) {
      _provider.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await CompanyRepository().getCompany();
      await _provider.init(base: 'https://erp.elrace.com');
    } catch (_) {}
    await _load(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    if (_search.trim().isNotEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 280) return;
    _loadMore();
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = false;
      });
    }
    try {
      final result = await _provider.fetchSiteReports(
        offset: 0,
        limit: _pageSize,
        append: false,
      );
      if (!mounted) return;
      setState(() {
        _reports = result.reports;
        _total = result.total;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reports = const [];
        _total = 0;
        _hasMore = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _provider.fetchSiteReports(
        offset: _reports.length,
        limit: _pageSize,
        append: true,
      );
      if (!mounted) return;
      setState(() {
        _reports = result.reports;
        _total = result.total;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  FolderModel _folderFor(ReportModel report) {
    return FolderModel(
      id: report.folderId.isNotEmpty ? report.folderId : '0',
      name: 'Site Reports',
      description: '',
      companyId: int.tryParse(report.companyId) ?? 0,
      reportCount: 1,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
    );
  }

  Future<void> _openComposer({ReportModel? existing}) async {
    final result =
        await Navigator.of(context).push<TmSiteReportComposerResult>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _provider,
          child: TmSiteReportComposerScreen(
            folder: existing != null ? _folderFor(existing) : null,
            locationHint: '',
            useDefaultFolder: true,
            existingReport: existing,
          ),
        ),
      ),
    );
    await _load(reset: true);
    if (result != null && mounted && result.pdfUrl.trim().isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TmSiteReportPdfScreen(
            url: result.pdfUrl,
            title: result.pdfTitle,
            reportId: result.reportId,
            projectId: '',
            projectName: '',
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
            folder: _folderFor(report),
            folderName: 'Site Reports',
            projectName: '',
            projectId: '',
          ),
        ),
      ),
    );
    await _load(reset: true);
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
              'PDF not generated — open photos to add and generate',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _busyReportId = report.id);
    try {
      if (!mounted) return;
      await TmSiteReportViewPdf.open(
        context,
        provider: _provider,
        report: report,
        folder: _folderFor(report),
        projectName: '',
        projectId: '',
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

  Widget _buildBody() {
    final reports = _filtered;
    if (_loading) {
      return const TimesheetLoadingState(
        style: TimesheetLoadingStyle.list,
        itemCount: 5,
      );
    }
    return Column(
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
            _total > 0
                ? '${reports.length} of $_total report(s)'
                : '${reports.length} report(s)',
            style: TimesheetModuleTypography.caption().copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: TimesheetModuleColors.primary,
            onRefresh: () => _load(reset: true),
            child: reports.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: const [
                      TimesheetEmptyState(
                        message:
                            'No site reports yet.\nTap New report to create one directly.',
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      TimesheetModuleLayout.screenPaddingH,
                      0,
                      TimesheetModuleLayout.screenPaddingH,
                      88,
                    ),
                    itemCount: reports.length + (_loadingMore || _hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(
                      height: TimesheetModuleLayout.cardSpacing,
                    ),
                    itemBuilder: (context, index) {
                      if (index >= reports.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
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
                          onChanged: () => _load(reset: true),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
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
    );

    if (widget.embedInParent) {
      return Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          Positioned(
            right: 16,
            bottom: 16,
            child: fab,
          ),
        ],
      );
    }

    return TmSiteReportGlassShell(
      title: widget.title,
      floatingActionButton: fab,
      body: _buildBody(),
    );
  }
}
