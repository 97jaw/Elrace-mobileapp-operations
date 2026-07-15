import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_actions.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/utils/tm_http_url.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

/// In-app PDF viewer with share (project chat / external / download).
class TmSiteReportPdfScreen extends StatefulWidget {
  const TmSiteReportPdfScreen({
    super.key,
    this.url,
    this.pdfBytes,
    required this.title,
    this.reportId,
    this.projectId,
    this.projectName,
    this.allowRenameDelete = true,
  }) : assert(url != null || pdfBytes != null);

  final String? url;
  final Uint8List? pdfBytes;
  final String title;
  final String? reportId;
  final String? projectId;
  final String? projectName;
  final bool allowRenameDelete;

  @override
  State<TmSiteReportPdfScreen> createState() => _TmSiteReportPdfScreenState();
}

class _TmSiteReportPdfScreenState extends State<TmSiteReportPdfScreen> {
  bool _loading = true;
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.pdfBytes != null) {
        _bytes = widget.pdfBytes;
      } else {
        _bytes = await tmFetchUrlBytes(widget.url!);
      }
    } catch (e) {
      _error = 'Could not load PDF';
      debugPrint('PDF load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openShare() {
    final bytes = _bytes;
    if (bytes == null) return;
    TmSharePdfSheet.show(
      context,
      pdfBytes: bytes,
      fileName: widget.title,
      projectId: widget.projectId,
      projectName: widget.projectName,
    );
  }

  Future<void> _pdfMenu() async {
    final reportId = widget.reportId;
    if (reportId == null || !widget.allowRenameDelete) return;
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TimesheetModuleColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(PhosphorIcons.pencilSimple()),
              title: const Text('Rename PDF'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(PhosphorIcons.trash(),
                  color: TimesheetModuleColors.danger),
              title: Text(
                'Delete PDF',
                style: TextStyle(color: TimesheetModuleColors.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await TmSiteReportActions.renamePdf(
        context,
        provider: provider,
        reportId: reportId,
        currentName: widget.title,
      );
    } else if (action == 'delete') {
      final ok = await TmSiteReportActions.deletePdf(
        context,
        provider: provider,
        reportId: reportId,
      );
      if (ok && mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TmSiteReportGlassShell(
      title: widget.title,
      trailing: [
        if (widget.reportId != null &&
            widget.allowRenameDelete &&
            widget.url != null)
          IconButton(
            onPressed: _pdfMenu,
            icon: Icon(
              PhosphorIcons.dotsThreeVertical(),
              color: const Color(0xFF1E2365),
            ),
          ),
        if (_bytes != null)
          IconButton(
            onPressed: _openShare,
            icon: Icon(
              PhosphorIcons.shareNetwork(),
              color: const Color(0xFF1E2365),
            ),
          ),
      ],
      body: _loading
          ? const TimesheetLoadingState(style: TimesheetLoadingStyle.list)
          : _error != null || _bytes == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error ?? 'Could not load PDF',
                      textAlign: TextAlign.center,
                      style: TimesheetModuleTypography.body().copyWith(
                        color: TimesheetModuleColors.danger,
                      ),
                    ),
                  ),
                )
              : TmPdfFileViewer(
                  pdfBytes: _bytes!,
                  fileName: widget.title,
                ),
    );
  }
}
