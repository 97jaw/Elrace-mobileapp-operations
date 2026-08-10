import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// In-app PDF viewer. Supports one URL or many (RFQ multi-attachment).
///
/// Multiple files are merged with Syncfusion before display/watermark.
/// Server-side PyPDF2 merges often appear as "Page 0 of 1" in this viewer.
class LpoPdfViewerScreen extends StatefulWidget {
  final String? pdfUrl;
  final List<String>? pdfUrls;
  final String? title;

  const LpoPdfViewerScreen({
    super.key,
    this.pdfUrl,
    this.pdfUrls,
    this.title,
  });

  @override
  State<LpoPdfViewerScreen> createState() => _LpoPdfViewerScreenState();
}

class _LpoPdfViewerScreenState extends State<LpoPdfViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;
  int _totalPages = 0;
  int _currentPage = 0;

  List<String> get _resolvedUrls {
    final multi = widget.pdfUrls
            ?.map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (multi.isNotEmpty) return multi;
    final single = widget.pdfUrl?.trim() ?? '';
    return single.isEmpty ? const <String>[] : <String>[single];
  }

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  bool _isPdfBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Allow leading BOM / whitespace before %PDF.
    var i = 0;
    while (i < bytes.length &&
        (bytes[i] == 0x00 ||
            bytes[i] == 0x09 ||
            bytes[i] == 0x0A ||
            bytes[i] == 0x0D ||
            bytes[i] == 0x20 ||
            bytes[i] == 0xEF ||
            bytes[i] == 0xBB ||
            bytes[i] == 0xBF)) {
      i++;
    }
    if (i + 4 > bytes.length) return false;
    return bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46;
  }

  bool _isBase64Pdf(Uint8List bytes) {
    if (bytes.length < 8) return false;
    final head = String.fromCharCodes(
      bytes.sublist(0, bytes.length < 32 ? bytes.length : 32),
    ).trimLeft();
    return head.startsWith('JVBERi0');
  }

  Uint8List _coercePdfBytes(Uint8List bytes) {
    if (_isPdfBytes(bytes)) return bytes;
    if (_isBase64Pdf(bytes)) {
      try {
        final cleaned = String.fromCharCodes(bytes)
            .replaceAll(RegExp(r'\s+'), '');
        final decoded = base64Decode(cleaned);
        if (_isPdfBytes(decoded)) return decoded;
      } catch (e) {
        debugPrint('PDF base64 decode failed: $e');
      }
    }
    return bytes;
  }

  bool _looksLikeHtmlBytes(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final sampleLength = bytes.length < 64 ? bytes.length : 64;
    final head = String.fromCharCodes(bytes.sublist(0, sampleLength))
        .trimLeft()
        .toLowerCase();
    return head.startsWith('<!doctype') ||
        head.startsWith('<html') ||
        head.startsWith('<head') ||
        head.startsWith('<body');
  }

  Future<http.Response> _fetchPdfResponse(String url) async {
    final uri = Uri.parse(url);
    final token = SharedPref.getLoginData().result?.token ?? '';
    final authHeaders = <String, String>{
      'Accept': 'application/pdf,*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    var response =
        await http.get(uri, headers: const {'Accept': 'application/pdf,*/*'});
    if (response.statusCode != 200 && token.isNotEmpty) {
      response = await http.get(uri, headers: authHeaders);
    }
    return response;
  }

  Future<Uint8List?> _downloadPdfBytes(String url) async {
    final response = await _fetchPdfResponse(url);
    if (response.statusCode != 200) {
      debugPrint('PDF download HTTP ${response.statusCode} for $url');
      return null;
    }
    var bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      debugPrint('PDF download empty body for $url');
      return null;
    }

    // Odoo sometimes serves base64 text with Content-Type: application/pdf.
    bytes = _coercePdfBytes(bytes);

    final ctype = (response.headers['content-type'] ?? '').toLowerCase();
    final looksHtml = _looksLikeHtmlBytes(bytes);
    final isPdf = _isPdfBytes(bytes);

    // Trust real PDF magic bytes even if Content-Type is wrong/missing.
    if (isPdf) return bytes;

    if (looksHtml ||
        ctype.contains('text/html') ||
        (ctype.contains('text/plain') && !isPdf)) {
      debugPrint(
        'PDF download rejected for $url '
        '(ctype=$ctype, len=${bytes.length}, html=$looksHtml, pdf=$isPdf)',
      );
      return null;
    }

    debugPrint(
      'PDF download rejected for $url '
      '(ctype=$ctype, len=${bytes.length}, head=${bytes.take(8).toList()})',
    );
    return null;
  }

  /// Merge PDFs with Syncfusion so the viewer can paginate all files.
  Uint8List _mergePdfDocuments(List<Uint8List> parts) {
    if (parts.isEmpty) {
      throw StateError('No PDF parts to merge');
    }
    if (parts.length == 1) return parts.first;

    final PdfDocument output = PdfDocument();
    // Drop the default blank page Syncfusion creates.
    if (output.pages.count > 0) {
      output.pages.removeAt(0);
    }

    var imported = 0;
    for (final part in parts) {
      final PdfDocument source = PdfDocument(inputBytes: part);
      try {
        for (var i = 0; i < source.pages.count; i++) {
          final PdfPage sourcePage = source.pages[i];
          final Size pageSize = sourcePage.size;
          output.pageSettings.size = pageSize;
          final PdfPage newPage = output.pages.add();
          final PdfTemplate template = sourcePage.createTemplate();
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            pageSize,
          );
          imported++;
        }
      } finally {
        source.dispose();
      }
    }

    if (imported == 0) {
      output.dispose();
      return parts.first;
    }

    final List<int> bytes = output.saveSync();
    output.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final urls = _resolvedUrls;
      if (urls.isEmpty) {
        setState(() {
          _error = 'No PDF URL provided';
          _loading = false;
        });
        return;
      }

      final parts = <Uint8List>[];
      for (final url in urls) {
        final bytes = await _downloadPdfBytes(url);
        if (bytes != null) parts.add(bytes);
      }

      if (parts.isEmpty) {
        setState(() {
          _error =
              'Server did not return a valid PDF. Please retry or open from ERP.';
          _loading = false;
        });
        return;
      }

      final Uint8List merged = _mergePdfDocuments(parts);
      final empId = SharedPref.getLoginData().result?.data?.emp_id ?? '';
      final Uint8List watermarked =
          empId.isNotEmpty ? _addWatermarkToPdf(merged, empId) : merged;
      if (!mounted) return;
      setState(() {
        _pdfBytes = watermarked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading PDF: $e';
        _loading = false;
      });
    }
  }

  Uint8List _addWatermarkToPdf(Uint8List pdfBytes, String empId) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final int pageCountBefore = document.pages.count;
      final PdfFont font = PdfStandardFont(
        PdfFontFamily.helvetica,
        28,
        style: PdfFontStyle.bold,
      );
      final PdfBrush brush = PdfSolidBrush(PdfColor(180, 180, 180));

      const int cols = 3;
      const int rows = 6;
      const double rotateDeg = -30;

      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final Size pageSize = page.getClientSize();
        final double cellW = pageSize.width / cols;
        final double cellH = pageSize.height / rows;
        final PdfGraphics graphics = page.graphics;

        for (int row = 0; row < rows; row++) {
          for (int col = 0; col < cols; col++) {
            final double cx = cellW * col + cellW / 2;
            final double cy = cellH * row + cellH / 2;

            final PdfGraphicsState state = graphics.save();
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

      final List<int> bytes = document.saveSync();
      final int pageCountAfter = document.pages.count;
      document.dispose();

      // Never allow watermarking to collapse a multi-page PDF to 1 page.
      if (pageCountBefore > 1 && pageCountAfter < pageCountBefore) {
        debugPrint(
          'Watermark dropped pages ($pageCountBefore → $pageCountAfter); '
          'using original bytes',
        );
        return pdfBytes;
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Watermark error: $e');
      return pdfBytes;
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;

    var rawName = (widget.title ?? 'document').trim();
    rawName = rawName.replaceFirst(
      RegExp(r'^(LPO Report\s*#?\s*|RFQ\s+|Invoice\s+)', caseSensitive: false),
      '',
    );
    if (rawName.isEmpty) rawName = 'document';
    final safeName = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final fileName =
        safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(_pdfBytes!, flush: true);

    if (!mounted) return;
    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
      sharePositionOrigin: shareOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFD0D2D8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0E3A76)),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title ?? 'LPO Report',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0E3A76),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF0E3A76)),
              onPressed: _sharePdf,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF0E3A76),
            ),
            SizedBox(height: 16.h),
            Text(
              _resolvedUrls.length > 1
                  ? 'Loading ${_resolvedUrls.length} PDFs...'
                  : 'Loading PDF...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.w,
                color: Colors.red[400],
              ),
              SizedBox(height: 16.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadPdf();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A76),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: Text('No PDF data'));
    }

    return Column(
      children: [
        Expanded(
          child: SfPdfViewer.memory(
            _pdfBytes!,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            pageSpacing: 4,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
                if (_currentPage <= 0) _currentPage = 1;
              });
            },
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            },
          ),
        ),
        if (_totalPages > 0)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
