import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// In-app attachment viewer used by My Documents, Petty Cash, and search.
///
/// Loads bytes via [DocumentAttachmentOpener.fetchAttachmentBytes]
/// (`/web/content` first, then public URL, then validated API base64).
/// Uses Syncfusion with a [PDFView] fallback when Syncfusion reports corruption
/// (common with some Odoo-exported PDFs that still open in ERP).
class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.publicUrl,
    required this.title,
    this.attachmentType,
    this.attachmentId,
    this.initialBytes,
  });

  final String publicUrl;
  final String title;
  final String? attachmentType;
  final int? attachmentId;
  final Uint8List? initialBytes;

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _bytes;
  _ViewerKind _kind = _ViewerKind.unsupported;
  bool _useLegacyPdfView = false;

  @override
  void initState() {
    super.initState();
    final seeded = DocumentAttachmentOpener.isPreviewableBinary(widget.initialBytes)
        ? widget.initialBytes
        : null;
    _kind = _detectKind(
      type: widget.attachmentType,
      url: widget.publicUrl,
      title: widget.title,
      bytes: seeded,
    );
    if (seeded != null && seeded.isNotEmpty) {
      _bytes = seeded;
      _loading = false;
      return;
    }
    _load();
  }

  static _ViewerKind _detectKind({
    required String? type,
    required String url,
    required String title,
    Uint8List? bytes,
  }) {
    if (DocumentAttachmentOpener.isPdfBytes(bytes)) return _ViewerKind.pdf;
    if (DocumentAttachmentOpener.isImageBytes(bytes)) return _ViewerKind.image;

    final mime = (type ?? '').toLowerCase();
    final name = title.toLowerCase();
    final u = url.toLowerCase();

    if (mime.contains('pdf') || name.endsWith('.pdf') || u.contains('.pdf')) {
      return _ViewerKind.pdf;
    }
    if (mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.bmp') ||
        u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('.bmp')) {
      return _ViewerKind.image;
    }

    // Public Odoo file URLs often have no extension.
    if (u.contains('/my/public/file/') || mime.isEmpty) {
      return _ViewerKind.pdf;
    }
    return _ViewerKind.unsupported;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _useLegacyPdfView = false;
    });

    try {
      final attachmentId =
          widget.attachmentId ?? extractPublicAttachmentId(widget.publicUrl);
      final normalizedUrl = normalizeProjectFileUrl(widget.publicUrl);
      final seeded =
          DocumentAttachmentOpener.isPreviewableBinary(widget.initialBytes)
              ? widget.initialBytes
              : null;

      final bytes = await DocumentAttachmentOpener.fetchAttachmentBytes(
        attachmentId: attachmentId,
        publicUrl: normalizedUrl,
        seededBytes: seeded,
        requirePreviewable: true,
      );

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to load attachment');
      }

      final resolvedKind = _detectKind(
        type: widget.attachmentType,
        url: normalizedUrl,
        title: widget.title,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _kind = resolvedKind;
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

  Future<void> _shareAttachment() async {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return;

    final safeName = widget.title.trim().isEmpty ? 'document' : widget.title.trim();
    String fileName = safeName;
    String mime = 'application/octet-stream';

    switch (_kind) {
      case _ViewerKind.pdf:
        if (!fileName.toLowerCase().endsWith('.pdf')) {
          fileName = '$fileName.pdf';
        }
        mime = 'application/pdf';
      case _ViewerKind.image:
        final lower = fileName.toLowerCase();
        if (!lower.endsWith('.png') &&
            !lower.endsWith('.jpg') &&
            !lower.endsWith('.jpeg') &&
            !lower.endsWith('.webp') &&
            !lower.endsWith('.gif')) {
          fileName = '$fileName.jpg';
        }
        mime = 'image/jpeg';
      case _ViewerKind.unsupported:
        break;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;

    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: fileName)],
      sharePositionOrigin: shareOrigin,
    );
  }

  Widget _buildPdfViewer(Uint8List bytes) {
    if (_useLegacyPdfView) {
      return PDFView(
        pdfData: bytes,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = error.toString();
          });
        },
        onPageError: (page, error) {
          debugPrint('PDF page $page error: $error');
        },
      );
    }

    return SfPdfViewer.memory(
      bytes,
      canShowPaginationDialog: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoadFailed: (details) {
        // Syncfusion is stricter than Odoo / flutter_pdfview. Retry with the
        // legacy viewer before surfacing a “corrupted” error.
        if (!mounted) return;
        setState(() {
          _useLegacyPdfView = true;
          _error = null;
        });
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E2365)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.tw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 48.tsp,
                color: const Color(0xFF9AA3AF),
              ),
              SizedBox(height: 12.th),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  color: const Color(0xFF1E2365),
                ),
              ),
              SizedBox(height: 16.th),
              FilledButton.icon(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2365),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              if (_bytes != null &&
                  DocumentAttachmentOpener.isPdfBytes(_bytes)) ...[
                SizedBox(height: 8.th),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _useLegacyPdfView = true;
                    });
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    'Open with alternate viewer',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return Center(
        child: Text(
          'Attachment is empty',
          style: GoogleFonts.poppins(color: const Color(0xFF7B8290)),
        ),
      );
    }

    switch (_kind) {
      case _ViewerKind.pdf:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12.tr),
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.92),
            child: _buildPdfViewer(bytes),
          ),
        );
      case _ViewerKind.image:
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  'Failed to load image attachment',
                  style: GoogleFonts.poppins(color: const Color(0xFF7B8290)),
                ),
              ),
            ),
          ),
        );
      case _ViewerKind.unsupported:
        return Center(
          child: Text(
            'Unsupported attachment type',
            style: GoogleFonts.poppins(color: const Color(0xFF7B8290)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShare =
        !_loading && _bytes != null && _bytes!.isNotEmpty && _error == null;
    return MyDocumentsSilkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductivityGlassHeader(
              title: widget.title.isEmpty ? 'Attachment' : widget.title,
              showBack: true,
              onBack: _goBack,
              transparentGlassBar: true,
              scrimTopOpacity: 0.08,
              titleTrailing: canShare
                  ? IconButton(
                      tooltip: 'Share',
                      onPressed: _shareAttachment,
                      icon: Icon(
                        Icons.ios_share_rounded,
                        color: const Color(0xFF1E2365),
                        size: 22.tsp,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.tw, 4.th, 12.tw, 12.th),
                child: TabletContentFrame(child: _buildBody()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ViewerKind { pdf, image, unsupported }
