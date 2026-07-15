import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_actions.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_gallery_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_view_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

class _ProjectSiteReportItem {
  const _ProjectSiteReportItem({
    required this.report,
    required this.folder,
  });

  final ReportModel report;
  final FolderModel folder;
}

/// Project Analytics tab: flat list of site reports for this project.
/// Open PDF / Gallery uses the same Site Report flow as timesheet / My Reports.
class ProjectAnalyticsSiteReportTab extends StatefulWidget {
  const ProjectAnalyticsSiteReportTab({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<ProjectAnalyticsSiteReportTab> createState() =>
      _ProjectAnalyticsSiteReportTabState();
}

class _ProjectAnalyticsSiteReportTabState
    extends State<ProjectAnalyticsSiteReportTab> {
  final ReportProvider _reportProvider = ReportProvider();
  bool _loading = true;
  String? _error;
  String _search = '';
  List<_ProjectSiteReportItem> _items = const [];
  String? _busyReportId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reportProvider.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CompanyRepository().getCompany();
      await _reportProvider.init(base: 'https://erp.elrace.com');
      final folders =
          await _reportProvider.fetchFoldersForProject(widget.projectId);

      final collected = <_ProjectSiteReportItem>[];
      for (final folder in folders) {
        await _reportProvider.fetchAllReports(
          folderID: folder.id,
          projectId: widget.projectId,
        );
        for (final report in _reportProvider.reports) {
          collected.add(
            _ProjectSiteReportItem(report: report, folder: folder),
          );
        }
      }

      collected.sort(
        (a, b) => b.report.updatedAt.compareTo(a.report.updatedAt),
      );

      if (!mounted) return;
      setState(() {
        _items = collected;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load site reports for this project.';
        _loading = false;
      });
    }
  }

  List<_ProjectSiteReportItem> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      final r = item.report;
      return r.name.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q) ||
          item.folder.name.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openPdf(_ProjectSiteReportItem item) async {
    final report = item.report;
    if (!report.hasGeneratedPdf && report.reportType == null) {
      final detail = await _reportProvider.fetchReportDetailFromApi(report.id);
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

    if (!mounted) return;
    setState(() => _busyReportId = report.id);
    try {
      if (!mounted) return;
      await TmSiteReportViewPdf.open(
        context,
        provider: _reportProvider,
        report: report,
        folder: item.folder,
        projectName: widget.projectName,
        projectId: widget.projectId,
      );
    } finally {
      if (mounted) setState(() => _busyReportId = null);
    }
  }

  Future<void> _openGallery(_ProjectSiteReportItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _reportProvider,
          child: TmSiteReportGalleryScreen(
            report: item.report,
            folder: item.folder,
            folderName: item.folder.name,
            projectName: widget.projectName,
            projectId: widget.projectId,
          ),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: ProjectsDashboardTheme.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(
                  foregroundColor: ProjectsDashboardTheme.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filtered;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
            decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Site reports',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: ProjectsDashboardTheme.maroonAccentGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_items.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.projectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: ProjectsDashboardTheme.greyPanel,
                  ),
                ),
                SizedBox(height: 10.h),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: ProjectsDashboardTheme.white,
                  ),
                  cursorColor: ProjectsDashboardTheme.white,
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, or folder',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: ProjectsDashboardTheme.greyPanel
                          .withValues(alpha: 0.75),
                    ),
                    prefixIcon: Icon(
                      PhosphorIcons.magnifyingGlass(),
                      color: ProjectsDashboardTheme.greyPanel,
                      size: 18.sp,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.glassHighlight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.glassHighlight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: ProjectsDashboardTheme.maroonSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: RefreshIndicator(
              color: ProjectsDashboardTheme.maroon,
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 48.h),
                        Icon(
                          PhosphorIcons.filePdf(),
                          size: 40.sp,
                          color: ProjectsDashboardTheme.greyPanel
                              .withValues(alpha: 0.7),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _items.isEmpty
                              ? 'No site reports for this project yet.'
                              : 'No reports match your search.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: ProjectsDashboardTheme.greyPanel,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final busy = _busyReportId == item.report.id;
                        return _ProjectsSiteReportCard(
                          item: item,
                          busy: busy,
                          onOpen: () => _openPdf(item),
                          onGallery: () => _openGallery(item),
                          onPdf: () => _openPdf(item),
                          onMore: () => TmSiteReportActions.showReportMenu(
                            context,
                            provider: _reportProvider,
                            report: item.report,
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

class _ProjectsSiteReportCard extends StatelessWidget {
  const _ProjectsSiteReportCard({
    required this.item,
    required this.busy,
    required this.onOpen,
    required this.onGallery,
    required this.onPdf,
    required this.onMore,
  });

  final _ProjectSiteReportItem item;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onGallery;
  final VoidCallback onPdf;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final report = item.report;
    final updated =
        DateFormat('dd MMM yyyy · HH:mm').format(report.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          padding: EdgeInsets.all(12.w),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: ProjectsDashboardTheme.maroonAccentGradient,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'ID ${report.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: 32.w,
                      minHeight: 32.w,
                    ),
                    onPressed: busy ? null : onMore,
                    icon: Icon(
                      PhosphorIcons.dotsThreeVertical(),
                      color: ProjectsDashboardTheme.greyPanel,
                      size: 18.sp,
                    ),
                  ),
                  if (!report.hasGeneratedPdf)
                    Icon(
                      PhosphorIcons.warningCircle(),
                      color: const Color(0xFFE6A700),
                      size: 18.sp,
                    )
                  else
                    Icon(
                      PhosphorIcons.checkCircle(),
                      color: const Color(0xFF3DDC84),
                      size: 18.sp,
                    ),
                  if (busy) ...[
                    SizedBox(width: 8.w),
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                report.name.isEmpty ? 'Untitled report' : report.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                item.folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                updated,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: ProjectsDashboardTheme.greyPanel
                      .withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _ActionChip(
                      label: 'Gallery',
                      icon: PhosphorIcons.images(),
                      onTap: busy ? null : onGallery,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _ActionChip(
                      label: 'PDF',
                      icon: PhosphorIcons.filePdf(),
                      emphasized: true,
                      onTap: busy ? null : onPdf,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            gradient: emphasized
                ? ProjectsDashboardTheme.maroonAccentGradient
                : null,
            color: emphasized
                ? null
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: ProjectsDashboardTheme.glassHighlight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: ProjectsDashboardTheme.white),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
