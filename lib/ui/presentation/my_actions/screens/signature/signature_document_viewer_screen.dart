import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../theme/signature_theme.dart';

/// Read-only PDF viewer for Signature documents: used for "Waiting for
/// Others" items, completed/signed documents, and drafts in the
/// Documents tab. Signing itself always goes through [SignDocumentScreen].
class SignatureDocumentViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? statusLabel;
  final Color? statusColor;

  const SignatureDocumentViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.statusLabel,
    this.statusColor,
  });

  @override
  State<SignatureDocumentViewerScreen> createState() =>
      _SignatureDocumentViewerScreenState();
}

class _SignatureDocumentViewerScreenState
    extends State<SignatureDocumentViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _bytes = response.bodyBytes;
          _loading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = 'Failed to load document (HTTP ${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading document: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _share() async {
    if (_bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.title}');
      await file.writeAsBytes(_bytes!);
      if (!mounted) return;
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? (box.localToGlobal(Offset.zero) & box.size)
          : const Rect.fromLTWH(1, 1, 1, 1);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      _showMessage('Share failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (_bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final signaturesDir = Directory('${dir.path}/Signatures');
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
      }
      final file = File('${signaturesDir.path}/${widget.title}');
      await file.writeAsBytes(_bytes!);
      _showMessage('Saved to app storage: Signatures/${widget.title}');
    } catch (e) {
      _showMessage('Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? SignatureTheme.expired : SignatureTheme.signed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignatureTheme.background,
      appBar: AppBar(
        backgroundColor: SignatureTheme.surface,
        foregroundColor: SignatureTheme.textDark,
        elevation: 0,
        systemOverlayStyle: SignatureTheme.lightStatusBar,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SignatureTheme.appBarTitle),
            if (widget.statusLabel != null)
              Text(
                widget.statusLabel!,
                style: SignatureTheme.cardSubtitle.copyWith(
                  color: widget.statusColor ?? SignatureTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _bytes == null || _busy ? null : _download,
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download',
          ),
          IconButton(
            onPressed: _bytes == null || _busy ? null : _share,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SignatureTheme.brown),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: SignatureTheme.expired),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: SignatureTheme.cardSubtitle),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SignatureTheme.brown,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return SfPdfViewer.memory(
      _bytes!,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
    );
  }
}
