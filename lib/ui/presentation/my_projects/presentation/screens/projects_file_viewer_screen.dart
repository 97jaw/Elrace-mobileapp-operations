import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:flutter/material.dart';
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
    this.preferUnauthenticated = false,
    this.attachmentId,
    this.initialBytes,
  });

  final String fileUrl;
  final String title;
  final ProjectsFileViewerMode mode;

  /// Public `/my/public/file/<id>` endpoints do not need Bearer; sending auth
  /// can confuse some gateways. Prefer unauthenticated GET for those URLs.
  final bool preferUnauthenticated;

  /// When public URL returns 502/404, load via get_attachment_details binary.
  final int? attachmentId;

  /// Optional preloaded PDF bytes (skips network when set).
  final Uint8List? initialBytes;

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
    final seeded = widget.initialBytes;
    if (seeded != null && seeded.isNotEmpty) {
      _bytes = widget.mode == ProjectsFileViewerMode.pdf
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

  Map<String, String> get _authHeaders {
    final token = SharedPref.getLoginData().result?.token ?? '';
    return {
      'Accept': '*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uint8List _maybeWatermark(Uint8List pdfBytes) {
    final empId = SharedPref.getLoginData().result?.data?.emp_id ?? '';
    if (empId.isEmpty) return pdfBytes;
    return _addWatermarkToPdf(pdfBytes, empId);
  }

  Future<http.Response> _getUrl(String url, {required bool preferPublic}) async {
    final uri = Uri.parse(url);
    if (preferPublic) {
      var response = await http.get(uri, headers: const {'Accept': '*/*'});
      if (response.statusCode != 200) {
        response = await http.get(uri, headers: _authHeaders);
      }
      return response;
    }
    var response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200 && url.contains('/my/public/file/')) {
      response = await http.get(uri, headers: const {'Accept': '*/*'});
    }
    return response;
  }

  Future<Uint8List?> _loadBytesFromAttachmentApi(int attachmentId) async {
    final details = await DocumentAttachmentOpener.fetchAttachmentDetails(
      attachmentId: attachmentId,
    );
    final binary = (details['attachment_binary_data'] ?? '').toString().trim();
    if (binary.isEmpty) return null;
    try {
      return base64Decode(binary);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadBytesFromWebContent(int attachmentId) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    final urls = <String>[
      if (token.isNotEmpty)
        'https://erp.elrace.com/web/content/$attachmentId?download=true&access_token=$token',
      'https://erp.elrace.com/web/content/$attachmentId?download=true',
      'https://erp.elrace.com/web/content/ir.attachment/$attachmentId/datas?download=true',
    ];
    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: _authHeaders,
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final ctype = (response.headers['content-type'] ?? '').toLowerCase();
          // Avoid treating HTML error pages as PDFs.
          if (ctype.contains('text/html')) continue;
          return response.bodyBytes;
        }
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Uint8List? bytes;
      String? lastHttpError;

      // 1) Public / provided URL
      try {
        final response = await _getUrl(
          widget.fileUrl,
          preferPublic: widget.preferUnauthenticated ||
              widget.fileUrl.contains('/my/public/file/'),
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final ctype = (response.headers['content-type'] ?? '').toLowerCase();
          if (!ctype.contains('text/html') && !ctype.contains('text/plain')) {
            bytes = response.bodyBytes;
          } else {
            lastHttpError = 'HTTP ${response.statusCode}';
          }
        } else {
          lastHttpError = 'HTTP ${response.statusCode}';
        }
      } catch (e) {
        lastHttpError = e.toString();
      }

      // 2) Authenticated API binary fallback
      final attachmentId = widget.attachmentId;
      if ((bytes == null || bytes.isEmpty) && attachmentId != null) {
        try {
          bytes = await _loadBytesFromAttachmentApi(attachmentId);
        } catch (_) {
          // continue
        }
      }

      // 3) Odoo /web/content fallback
      if ((bytes == null || bytes.isEmpty) && attachmentId != null) {
        bytes = await _loadBytesFromWebContent(attachmentId);
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          lastHttpError == null
              ? 'Failed to load file'
              : 'Failed to load file ($lastHttpError)',
        );
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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      try {
        final response = await _getUrl(
          widget.fileUrl,
          preferPublic: widget.preferUnauthenticated ||
              widget.fileUrl.contains('/my/public/file/'),
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          bytes = response.bodyBytes;
        }
      } catch (_) {}

      final attachmentId = widget.attachmentId;
      if ((bytes == null || bytes.isEmpty) && attachmentId != null) {
        try {
          bytes = await _loadBytesFromAttachmentApi(attachmentId);
        } catch (_) {}
      }
      if ((bytes == null || bytes.isEmpty) && attachmentId != null) {
        bytes = await _loadBytesFromWebContent(attachmentId);
      }
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
            SizedBox(height: 14.th),
            Text(
              'Loading file…',
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
                  padding: EdgeInsets.symmetric(horizontal: 22.tw, vertical: 10.th),
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
