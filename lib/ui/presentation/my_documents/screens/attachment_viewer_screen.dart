import 'dart:typed_data';

import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              if (_bytes != null && DocumentAttachmentOpener.isPdfBytes(_bytes)) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _useLegacyPdfView = true;
                    });
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Open with alternate viewer'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return const Center(child: Text('Attachment is empty'));
    }

    switch (_kind) {
      case _ViewerKind.pdf:
        return _buildPdfViewer(bytes);
      case _ViewerKind.image:
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('Failed to load image attachment')),
            ),
          ),
        );
      case _ViewerKind.unsupported:
        return const Center(child: Text('Unsupported attachment type'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductivityScreenShell(
      title: widget.title.isEmpty ? 'Attachment' : widget.title,
      showBack: true,
      onBack: _goBack,
      body: _buildBody(),
    );
  }
}

enum _ViewerKind { pdf, image, unsupported }
