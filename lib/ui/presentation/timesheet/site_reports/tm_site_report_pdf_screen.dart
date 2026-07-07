import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_actions.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        final response = await http.get(Uri.parse(widget.url!));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        _bytes = response.bodyBytes;
      }
    } catch (_) {
      _error = 'Could not load PDF';
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
    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      appBar: AppBar(
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
        title: Text(
          widget.title,
          style: TimesheetModuleTypography.h2(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.reportId != null &&
              widget.allowRenameDelete &&
              widget.url != null)
            IconButton(
              onPressed: _pdfMenu,
              icon: Icon(PhosphorIcons.dotsThreeVertical()),
            ),
          if (_bytes != null)
            IconButton(
              onPressed: _openShare,
              icon: Icon(PhosphorIcons.shareNetwork()),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const TimesheetLoadingState(style: TimesheetLoadingStyle.list)
            : _error != null || _bytes == null
                ? Center(
                    child: Text(
                      _error ?? 'Could not load PDF',
                      style: TimesheetModuleTypography.body().copyWith(
                        color: TimesheetModuleColors.danger,
                      ),
                    ),
                  )
                : TmPdfFileViewer(
                    pdfBytes: _bytes!,
                    fileName: widget.title,
                  ),
      ),
    );
  }
}
