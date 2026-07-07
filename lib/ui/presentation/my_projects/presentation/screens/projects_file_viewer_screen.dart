import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

enum ProjectsFileViewerMode { pdf, image }

/// In-app file viewer for Projects / DMS — matches portfolio dashboard theme.
class ProjectsFileViewerScreen extends StatefulWidget {
  const ProjectsFileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.title,
    required this.mode,
  });

  final String fileUrl;
  final String title;
  final ProjectsFileViewerMode mode;

  @override
  State<ProjectsFileViewerScreen> createState() =>
      _ProjectsFileViewerScreenState();
}

class _ProjectsFileViewerScreenState extends State<ProjectsFileViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _bytes;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mode == ProjectsFileViewerMode.pdf) {
      _loadPdf();
    } else {
      _loading = false;
    }
  }

  Map<String, String> get _authHeaders {
    final token = SharedPref.getLoginData().result?.token ?? '';
    return {
      'Accept': '*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(widget.fileUrl),
        headers: _authHeaders,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load file (HTTP ${response.statusCode})');
      }

      final empId = SharedPref.getLoginData().result?.data?.emp_id ?? '';
      final bytes = empId.isNotEmpty
          ? _addWatermarkToPdf(response.bodyBytes, empId)
          : response.bodyBytes;

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Uint8List _addWatermarkToPdf(Uint8List pdfBytes, String empId) {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final font = PdfStandardFont(
        PdfFontFamily.helvetica,
        28,
        style: PdfFontStyle.bold,
      );
      final brush = PdfSolidBrush(PdfColor(180, 180, 180));

      const cols = 3;
      const rows = 6;
      const rotateDeg = -30.0;

      for (var i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final pageSize = page.getClientSize();
        final cellW = pageSize.width / cols;
        final cellH = pageSize.height / rows;
        final graphics = page.graphics;

        for (var row = 0; row < rows; row++) {
          for (var col = 0; col < cols; col++) {
            final cx = cellW * col + cellW / 2;
            final cy = cellH * row + cellH / 2;
            final state = graphics.save();
            graphics
              ..setTransparency(0.18)
              ..translateTransform(cx, cy)
              ..rotateTransform(rotateDeg)
              ..drawString(
                empId,
                font,
                brush: brush,
                bounds: const Rect.fromLTWH(-60, -20, 120, 40),
              );
            graphics.restore(state);
          }
        }
      }

      final out = document.saveSync();
      document.dispose();
      return Uint8List.fromList(out);
    } catch (_) {
      return pdfBytes;
    }
  }

  Future<void> _sharePdf() async {
    if (_bytes == null) return;

    final rawName = widget.title.trim().isEmpty ? 'document' : widget.title.trim();
    final safeName = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final fileName =
        safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';

    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    await Share.shareXFiles(
      [
        XFile.fromData(
          _bytes!,
          name: fileName,
          mimeType: 'application/pdf',
        ),
      ],
      sharePositionOrigin: shareOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ProjectsDashboardTheme.screenGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ViewerHeader(
                title: widget.title,
                onBack: () => Navigator.of(context).maybePop(),
                onShare: widget.mode == ProjectsFileViewerMode.pdf &&
                        _bytes != null
                    ? _sharePdf
                    : null,
              ),
              Expanded(child: _buildBody()),
              if (widget.mode == ProjectsFileViewerMode.pdf && _totalPages > 0)
                _PageFooter(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: ProjectsDashboardTheme.white,
              strokeWidth: 2.6,
            ),
            SizedBox(height: 14.h),
            Text(
              'Loading file…',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: ProjectsDashboardTheme.greyPanel,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48.sp,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
              ),
              SizedBox(height: 12.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
                ),
              ),
              SizedBox(height: 18.h),
              FilledButton(
                onPressed: widget.mode == ProjectsFileViewerMode.pdf
                    ? _loadPdf
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ProjectsDashboardTheme.maroon,
                  foregroundColor: ProjectsDashboardTheme.white,
                  padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: widget.mode == ProjectsFileViewerMode.pdf
              ? _buildPdfViewer()
              : _buildImageViewer(),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: Text('No PDF data'));
    }

    return SfPdfViewer.memory(
      bytes,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      pageSpacing: 4,
      onDocumentLoaded: (details) {
        setState(() => _totalPages = details.document.pages.count);
      },
      onPageChanged: (details) {
        setState(() => _currentPage = details.newPageNumber);
      },
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 4,
      child: Center(
        child: Image.network(
          widget.fileUrl,
          fit: BoxFit.contain,
          headers: _authHeaders,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: ProjectsDashboardTheme.maroon,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 42.sp,
                  color: ProjectsDashboardTheme.greyDark,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Failed to load image',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: ProjectsDashboardTheme.greyDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({
    required this.title,
    required this.onBack,
    this.onShare,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 8.w, 10.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18.sp,
              color: ProjectsDashboardTheme.white,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 38.w, minHeight: 38.w),
          ),
          Expanded(
            child: ProjectDocumentsOneLineMarquee(
              text: title.isEmpty ? 'File' : title,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              italic: false,
              color: ProjectsDashboardTheme.white,
            ),
          ),
          if (onShare != null)
            IconButton(
              onPressed: onShare,
              icon: Icon(
                Icons.ios_share_rounded,
                size: 20.sp,
                color: ProjectsDashboardTheme.white,
              ),
              tooltip: 'Share',
            ),
        ],
      ),
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
        decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
        child: Center(
          child: Text(
            'Page $currentPage of $totalPages',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ),
      ),
    );
  }
}
