import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/models/tm_site_report_composer_result.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_composer_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_pdf_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_image_viewer_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

/// Gallery for one report — view photos, edit/add/remove, regenerate PDF.
class TmSiteReportGalleryScreen extends StatefulWidget {
  const TmSiteReportGalleryScreen({
    super.key,
    required this.report,
    required this.folder,
    required this.folderName,
    required this.projectName,
    this.projectId,
  });

  final ReportModel report;
  final FolderModel folder;
  final String folderName;
  final String projectName;
  final String? projectId;

  @override
  State<TmSiteReportGalleryScreen> createState() =>
      _TmSiteReportGalleryScreenState();
}

class _TmSiteReportGalleryScreenState extends State<TmSiteReportGalleryScreen> {
  bool _loading = true;
  List<ReportItemModel> _items = const [];

  ReportProvider get _provider =>
      Provider.of<ReportProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail = await _provider.fetchReportDetailFromApi(widget.report.id);
    if (!mounted) return;
    final items = detail?.reportItems ?? const [];
    setState(() {
      _items = items;
      _loading = false;
    });
    if (items.isNotEmpty) {
      TmFastNetworkImage.precacheUrls(
        context,
        items.map((e) => e.image),
        max: 16,
        memCacheWidth: 480,
      );
    }
  }

  Future<void> _openComposer() async {
    final result = await Navigator.of(context).push<TmSiteReportComposerResult>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _provider,
          child: TmSiteReportComposerScreen(
            folder: widget.folder,
            projectName: widget.projectName,
            existingReport: widget.report,
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (result != null && result.pdfUrl.trim().isNotEmpty) {
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

  void _openViewer(int index) {
    final viewerItems = _items
        .map(
          (e) => TmGalleryViewerItem(
            imageUrl: e.image,
            description: e.description,
            location: e.location,
          ),
        )
        .toList();
    TmSiteImageViewerSheet.show(
      context,
      items: viewerItems,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TmSiteReportGlassShell(
      title: widget.report.name,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: TimesheetModuleColors.primary,
        foregroundColor: TimesheetModuleColors.surface,
        icon: Icon(PhosphorIcons.pencilSimple()),
        label: Text(
          _items.isEmpty ? 'Add photos' : 'Edit & regenerate',
          style: TimesheetModuleTypography.button(
            color: TimesheetModuleColors.surface,
          ),
        ),
      ),
      body: _loading
          ? const TimesheetLoadingState(style: TimesheetLoadingStyle.gallery)
          : _items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const TimesheetEmptyState(
                      message:
                          'No photos yet.\nTap Add photos to capture, describe, and generate a PDF for this report.',
                    ),
                    const SizedBox(height: 20),
                    TmPrimaryButton(
                      label: 'Add photos',
                      icon: PhosphorIcons.camera(),
                      onPressed: _openComposer,
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: TimesheetModuleColors.primary,
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      TimesheetModuleLayout.screenPaddingH,
                      TimesheetModuleLayout.screenPaddingH,
                      TimesheetModuleLayout.screenPaddingH,
                      88,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final url = item.image.trim();
                      return Material(
                        color: TimesheetModuleColors.surface,
                        borderRadius: BorderRadius.circular(
                          TimesheetModuleLayout.cardRadiusMd,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: url.isEmpty ? null : () => _openViewer(index),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (url.isEmpty)
                                Center(
                                  child: Icon(
                                    PhosphorIcons.image(),
                                    color: TimesheetModuleColors.mutedText,
                                  ),
                                )
                              else
                                TmFastNetworkImage(
                                  url: url,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
                                ),
                              if (item.description.trim().isEmpty)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(
                                    PhosphorIcons.warningCircle(),
                                    color: const Color(0xFFE6A700),
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
