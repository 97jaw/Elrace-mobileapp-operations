import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signatures_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Writes PDF bytes to a temp file and shows them with [PDFView] (stable on iOS).
class TmPdfFileViewer extends StatefulWidget {
  const TmPdfFileViewer({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  final Uint8List pdfBytes;
  final String fileName;

  @override
  State<TmPdfFileViewer> createState() => _TmPdfFileViewerState();
}

class _TmPdfFileViewerState extends State<TmPdfFileViewer> {
  bool _loading = true;
  String? _filePath;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    try {
      final file = await TmSharePdfSheet.writeTempFile(
        widget.pdfBytes,
        widget.fileName,
      );
      if (!mounted) return;
      setState(() {
        _filePath = file.path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open PDF preview';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TimesheetLoadingState(style: TimesheetLoadingStyle.list);
    }
    if (_error != null) {
      return TimesheetErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
            _filePath = null;
          });
          _prepareFile();
        },
      );
    }
    final path = _filePath;
    if (path == null) {
      return const TimesheetEmptyState(message: 'No PDF file');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PDFView(
            filePath: path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            onRender: (pages) {
              if (!mounted || pages == null) return;
              setState(() => _totalPages = pages);
            },
            onPageChanged: (page, total) {
              if (!mounted) return;
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? _totalPages;
              });
            },
            onError: (message) {
              if (!mounted) return;
              setState(() => _error = message);
            },
          ),
        ),
        if (_totalPages > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Page ${_currentPage + 1} of $_totalPages',
              textAlign: TextAlign.center,
              style: TimesheetModuleTypography.caption(),
            ),
          ),
      ],
    );
  }
}

/// Full-screen timesheet / generated PDF preview.
class TmPdfBytesPreviewScreen extends StatefulWidget {
  const TmPdfBytesPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
    this.projectId,
    this.projectName,
  });

  final Uint8List pdfBytes;
  final String title;
  final String? projectId;
  final String? projectName;

  @override
  State<TmPdfBytesPreviewScreen> createState() =>
      _TmPdfBytesPreviewScreenState();
}

class _TmPdfBytesPreviewScreenState extends State<TmPdfBytesPreviewScreen> {
  bool _openingSign = false;

  String get _fileName {
    final name = widget.title.trim();
    if (name.toLowerCase().endsWith('.pdf')) return name;
    return '$name.pdf';
  }

  Future<void> _share() {
    return TmSharePdfSheet.shareExternal(
      context,
      widget.pdfBytes,
      _fileName,
    );
  }

  Future<void> _download() {
    return TmSharePdfSheet.downloadToDevice(
      context,
      widget.pdfBytes,
      _fileName,
    );
  }

  Future<void> _signTimesheet() async {
    if (_openingSign) return;
    setState(() => _openingSign = true);
    try {
      final file = await TmSharePdfSheet.writeTempFile(
        widget.pdfBytes,
        _fileName,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SignaturesScreen(
            initialPdf: file,
            initialFileName: _fileName,
            timesheetMode: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingSign = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TmModuleGlassHeader(title: widget.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: _PdfActionButton(
                    icon: PhosphorIcons.shareNetwork(),
                    label: 'Share',
                    onTap: _share,
                  ),
                ),
                Expanded(
                  child: _PdfActionButton(
                    icon: PhosphorIcons.download(),
                    label: 'Download',
                    onTap: _download,
                  ),
                ),
                Expanded(
                  child: _PdfActionButton(
                    icon: PhosphorIcons.signature(),
                    label: 'Sign Timesheet',
                    onTap: _openingSign ? null : _signTimesheet,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: TmPdfFileViewer(
                pdfBytes: widget.pdfBytes,
                fileName: widget.title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfActionButton extends StatelessWidget {
  const _PdfActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.iconSurface,
                shape: BoxShape.circle,
                border: Border.all(color: TimesheetModuleColors.glassBorder),
              ),
              child: Icon(icon, size: 26, color: TimesheetModuleColors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TimesheetModuleTypography.caption().copyWith(
                fontWeight: FontWeight.w600,
                color: TimesheetModuleColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
