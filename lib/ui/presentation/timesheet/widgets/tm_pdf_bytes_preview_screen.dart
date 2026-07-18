import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
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
class TmPdfBytesPreviewScreen extends StatelessWidget {
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

  void _share(BuildContext context) {
    TmSharePdfSheet.show(
      context,
      pdfBytes: pdfBytes,
      fileName: title,
      projectId: projectId,
      projectName: projectName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TmModuleGlassHeader(
            title: title,
            trailing: [
              IconButton(
                onPressed: () => _share(context),
                icon: Icon(PhosphorIcons.shareNetwork()),
                tooltip: 'Share',
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: TmPdfFileViewer(
                pdfBytes: pdfBytes,
                fileName: title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
