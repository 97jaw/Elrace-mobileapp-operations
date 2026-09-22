import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/app_screen_protection.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

enum ProjectsFileViewerMode { pdf, image }

/// In-app file viewer for Projects / DMS — matches portfolio dashboard theme.
///
/// For large SharePoint PDFs, prefer [streamToDisk] so we never hold the full
/// file in Dart memory (avoids OOM on architectural drawing books).
class ProjectsFileViewerScreen extends StatefulWidget {
  const ProjectsFileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.title,
    required this.mode,
    this.preferUnauthenticated = false,
    this.attachmentId,
    this.initialBytes,
    this.streamToDisk = false,
    this.protectScreen = false,
    this.allowShare = true,
    this.applyWatermark = true,
  });

  final String fileUrl;
  final String title;
  final ProjectsFileViewerMode mode;

  /// Public `/my/public/file/<id>` endpoints do not need Bearer; sending auth
  /// can confuse some gateways. Prefer unauthenticated GET for those URLs.
  final bool preferUnauthenticated;

  /// When public URL returns 502/404, load via get_attachment_details binary.
  final int? attachmentId;

  /// Optional preloaded PDF bytes (skips network when set). Avoid for large files.
  final Uint8List? initialBytes;

  /// Stream remote URL to a temp file and open with [SfPdfViewer.file].
  final bool streamToDisk;

  /// Re-assert screenshot / screen-recording protection while this viewer is open.
  final bool protectScreen;

  /// Share button (disabled for SharePoint).
  final bool allowShare;

  /// Emp-id PDF watermark (disabled for SharePoint).
  final bool applyWatermark;

  @override
  State<ProjectsFileViewerScreen> createState() =>
      _ProjectsFileViewerScreenState();
}

class _ProjectsFileViewerScreenState extends State<ProjectsFileViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _bytes;
  File? _localFile;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.protectScreen) {
      AppScreenProtection.enable();
    }

    if (widget.streamToDisk &&
        widget.mode == ProjectsFileViewerMode.pdf &&
        widget.fileUrl.trim().isNotEmpty) {
      _loadPdfToDisk();
      return;
    }

    final seeded = widget.initialBytes;
    final seedOk = widget.mode == ProjectsFileViewerMode.pdf
        ? DocumentAttachmentOpener.isPdfBytes(seeded)
        : DocumentAttachmentOpener.isImageBytes(seeded);
    if (seedOk && seeded != null && seeded.isNotEmpty) {
      _bytes = widget.mode == ProjectsFileViewerMode.pdf && widget.applyWatermark
          ? _maybeWatermark(seeded)
          : seeded;
      _loading = false;
      return;
    }
    if (widget.mode == ProjectsFileViewerMode.pdf) {
      _loadPdf();
    } else {
      _loadImage();
    }
  }

  @override
  void dispose() {
    if (widget.protectScreen) {
      AppScreenProtection.disable();
    }
    final file = _localFile;
    if (file != null) {
      // Best-effort cleanup of streamed temp PDFs.
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Uint8List _maybeWatermark(Uint8List pdfBytes) {
    if (!widget.applyWatermark) return pdfBytes;
    // Skip watermark for large payloads — Syncfusion rewrite doubles RAM.
    if (pdfBytes.lengthInBytes > 12 * 1024 * 1024) return pdfBytes;
    final empId = SharedPref.getLoginData().result?.data?.emp_id ?? '';
    if (empId.isEmpty) return pdfBytes;
    return _addWatermarkToPdf(pdfBytes, empId);
  }

  Future<void> _loadPdfToDisk() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await DocumentAttachmentOpener.streamUrlToTempFile(
        url: widget.fileUrl,
        fileName: widget.title,
        extension: '.pdf',
      );
      if (!DocumentAttachmentOpener.fileLooksLikePdf(file)) {
        try {
          await file.delete();
        } catch (_) {}
        throw Exception('Downloaded file is not a valid PDF');
      }
      if (!mounted) return;
      setState(() {
        _localFile = file;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Large remote PDFs should never go through the in-memory path.
      if (widget.streamToDisk || _shouldPreferDisk(widget.fileUrl)) {
        await _loadPdfToDisk();
        return;
      }

      final seeded =
          DocumentAttachmentOpener.isPdfBytes(widget.initialBytes)
              ? widget.initialBytes
              : null;
      final bytes = await DocumentAttachmentOpener.fetchAttachmentBytes(
        attachmentId: widget.attachmentId,
        publicUrl: widget.fileUrl,
        seededBytes: seeded,
        requirePreviewable: true,
      );

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to load file');
      }
      if (!DocumentAttachmentOpener.isPdfBytes(bytes)) {
        throw Exception('Downloaded file is not a valid PDF');
      }

      // If unexpectedly large, spill to disk instead of watermarking in RAM.
      if (bytes.lengthInBytes > 12 * 1024 * 1024 || !widget.applyWatermark) {
        final file = await DocumentAttachmentOpener.writeBytesToTempFile(
          bytes: bytes,
          fileName: widget.title,
          extension: '.pdf',
        );
        if (!mounted) return;
        setState(() {
          _localFile = file;
          _bytes = null;
          _loading = false;
        });
        return;
      }

      final watermarked = _maybeWatermark(bytes);

      if (!mounted) return;
      setState(() {
        _bytes = watermarked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  bool _shouldPreferDisk(String url) {
    final u = url.toLowerCase();
    return u.contains('sharepoint.com') ||
        u.contains('1drv.ms') ||
        u.contains('graph.microsoft.com') ||
        u.contains('download.aspx') ||
        u.contains('tempauth=');
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Prefer network image for remote SharePoint URLs (no full RAM buffer).
      if (_shouldPreferDisk(widget.fileUrl) && widget.initialBytes == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final seeded =
          DocumentAttachmentOpener.isImageBytes(widget.initialBytes)
              ? widget.initialBytes
              : null;
      final bytes = await DocumentAttachmentOpener.fetchAttachmentBytes(
        attachmentId: widget.attachmentId,
        publicUrl: widget.fileUrl,
        seededBytes: seeded,
        requirePreviewable: true,
      );
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to load image');
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
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
    final rawName =
        widget.title.trim().isEmpty ? 'document' : widget.title.trim();
    final safeName = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final fileName =
        safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';

    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    final local = _localFile;
    if (local != null && await local.exists()) {
      await Share.shareXFiles(
        [XFile(local.path, mimeType: 'application/pdf', name: fileName)],
        sharePositionOrigin: shareOrigin,
      );
      return;
    }

    if (_bytes == null) return;
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
    final canShare = widget.allowShare &&
        widget.mode == ProjectsFileViewerMode.pdf &&
        (_bytes != null || _localFile != null);

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
                onShare: canShare ? _sharePdf : null,
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
            SizedBox(height: 14.th),
            Text(
              widget.streamToDisk ? 'Preparing preview…' : 'Loading file…',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
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
          padding: EdgeInsets.symmetric(horizontal: 28.tw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48.tsp,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
              ),
              SizedBox(height: 12.th),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
                ),
              ),
              SizedBox(height: 18.th),
              FilledButton(
                onPressed: widget.mode == ProjectsFileViewerMode.pdf
                    ? _loadPdf
                    : _loadImage,
                style: FilledButton.styleFrom(
                  backgroundColor: ProjectsDashboardTheme.maroon,
                  foregroundColor: ProjectsDashboardTheme.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 22.tw, vertical: 10.th),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.tr),
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
      padding: EdgeInsets.fromLTRB(12.tw, 0, 12.tw, 12.th),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16.tr),
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
          borderRadius: BorderRadius.circular(16.tr),
          child: widget.mode == ProjectsFileViewerMode.pdf
              ? _buildPdfViewer()
              : _buildImageViewer(),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    final local = _localFile;
    if (local != null) {
      return SfPdfViewer.file(
        local,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        enableTextSelection: false,
        pageSpacing: 4,
        onDocumentLoaded: (details) {
          setState(() => _totalPages = details.document.pages.count);
        },
        onPageChanged: (details) {
          setState(() => _currentPage = details.newPageNumber);
        },
      );
    }

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
    if ((_bytes == null || _bytes!.isEmpty) &&
        _shouldPreferDisk(widget.fileUrl)) {
      return InteractiveViewer(
        minScale: 0.6,
        maxScale: 4,
        child: Center(
          child: Image.network(
            widget.fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(
                color: ProjectsDashboardTheme.maroon,
              );
            },
            errorBuilder: (_, __, ___) => Padding(
              padding: EdgeInsets.all(20.tw),
              child: Text(
                'Failed to load image',
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.greyDark,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return Center(
        child: Text(
          'Failed to load image',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.greyDark,
          ),
        ),
      );
    }
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 4,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Padding(
            padding: EdgeInsets.all(20.tw),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 42.tsp,
                  color: ProjectsDashboardTheme.greyDark,
                ),
                SizedBox(height: 8.th),
                Text(
                  'Failed to load image',
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
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
      padding: EdgeInsets.fromLTRB(4.tw, 4.th, 8.tw, 10.th),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18.tsp,
              color: ProjectsDashboardTheme.white,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 38.tw, minHeight: 38.tw),
          ),
          Expanded(
            child: ProjectDocumentsOneLineMarquee(
              text: title.isEmpty ? 'File' : title,
              fontSize: 15.tsp,
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
                size: 20.tsp,
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
      padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 10.th),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.th, horizontal: 14.tw),
        decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
        child: Center(
          child: Text(
            'Page $currentPage of $totalPages',
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w500,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ),
      ),
    );
  }
}
