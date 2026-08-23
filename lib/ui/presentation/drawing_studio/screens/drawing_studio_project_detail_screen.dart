import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_status_chip.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Project folder detail — summary, WhatsApp-style PDF, image gallery.
class DrawingStudioProjectDetailScreen extends StatefulWidget {
  const DrawingStudioProjectDetailScreen({
    super.key,
    required this.project,
  });

  final DrawingStudioProject project;

  @override
  State<DrawingStudioProjectDetailScreen> createState() =>
      _DrawingStudioProjectDetailScreenState();
}

class _DrawingStudioProjectDetailScreenState
    extends State<DrawingStudioProjectDetailScreen> {
  final _api = DrawingStudioApiClient();
  late DrawingStudioProject _project;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getProject(_project.projectId);
      if (!mounted) return;
      setState(() {
        _project = detail;
        _loading = false;
      });
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      // Keep list payload if detail endpoint is unavailable yet.
      setState(() {
        _loading = false;
        if (_project.briefPreview == null && _project.pdfUrl == null) {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openPdf() {
    final url = _project.pdfUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LpoPdfViewerScreen(
          pdfUrl: url,
          title: _project.pdfName ?? '${_project.title}.pdf',
        ),
      ),
    );
  }

  void _openImage(DrawingStudioProjectImage image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StudioImageViewerScreen(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _project.createdAt == null
        ? null
        : DateFormat('d MMM yyyy').format(_project.createdAt!.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DrawingStudioChromeHeader(),
          DrawingStudioHeadingCard(title: _project.title),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshDetail,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.uh, 16.w, 28.uh),
                children: [
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.uh),
                      child: const LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.uh),
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.usp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFE63946),
                        ),
                      ),
                    ),
                  _ContextSummary(
                    brief: _project.briefPreview,
                    status: _project.status,
                    dateLabel: dateLabel,
                  ),
                  SizedBox(height: 18.uh),
                  Text(
                    'Document',
                    style: GoogleFonts.poppins(
                      fontSize: 14.usp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2A4F),
                    ),
                  ),
                  SizedBox(height: 10.uh),
                  if (_project.pdfUrl != null && _project.pdfUrl!.isNotEmpty)
                    _WhatsAppPdfCard(
                      fileName: _project.pdfName ?? '${_project.title}.pdf',
                      onTap: _openPdf,
                    )
                  else
                    _EmptyBlock(
                      message: _project.isProcessing
                          ? 'PDF is still processing.'
                          : 'No PDF available yet.',
                    ),
                  SizedBox(height: 22.uh),
                  Text(
                    'Images',
                    style: GoogleFonts.poppins(
                      fontSize: 14.usp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2A4F),
                    ),
                  ),
                  SizedBox(height: 10.uh),
                  if (_project.images.isEmpty)
                    const _EmptyBlock(message: 'No images for this project yet.')
                  else
                    ..._project.images.map(
                      (image) => Padding(
                        padding: EdgeInsets.only(bottom: 10.uh),
                        child: _ImageGalleryRow(
                          image: image,
                          onView: () => _openImage(image),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextSummary extends StatelessWidget {
  const _ContextSummary({
    required this.brief,
    required this.status,
    required this.dateLabel,
  });

  final String? brief;
  final String status;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.uh, 14.w, 12.uh),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.ur),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (brief == null || brief!.trim().isEmpty)
                ? 'No project context summary yet.'
                : brief!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.usp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A6A82),
              height: 1.35,
            ),
          ),
          SizedBox(height: 10.uh),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.uh,
            children: [
              DrawingStudioStatusChip(status: status),
              if (dateLabel != null) _MetaBadge(label: dateLabel!),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.uh),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.usp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF3730A3),
        ),
      ),
    );
  }
}

/// WhatsApp-style PDF attachment card.
class _WhatsAppPdfCard extends StatelessWidget {
  const _WhatsAppPdfCard({
    required this.fileName,
    required this.onTap,
  });

  final String fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.ur),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.ur),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.ur),
            border: Border.all(color: const Color(0xFFE4E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 52.w,
                height: 60.uh,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10.ur),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFE53935),
                      size: 26.usp,
                    ),
                    SizedBox(height: 2.uh),
                    Text(
                      'PDF',
                      style: GoogleFonts.poppins(
                        fontSize: 9.usp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.usp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2A4F),
                      ),
                    ),
                    SizedBox(height: 4.uh),
                    Text(
                      'Tap to open',
                      style: GoogleFonts.poppins(
                        fontSize: 11.usp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7A849C),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFB0BAC8),
                size: 22.usp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageGalleryRow extends StatelessWidget {
  const _ImageGalleryRow({
    required this.image,
    required this.onView,
  });

  final DrawingStudioProjectImage image;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final preview = image.thumbnailUrl ?? image.url;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.ur),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.ur),
            child: Image.network(
              preview,
              width: 64.w,
              height: 64.w,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64.w,
                height: 64.w,
                color: const Color(0xFFEEF2FF),
                child: Icon(
                  Icons.image_outlined,
                  color: const Color(0xFF3E7BFA),
                  size: 24.usp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              image.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2A4F),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3E7BFA),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
            ),
            child: Text(
              'View',
              style: GoogleFonts.poppins(
                fontSize: 13.usp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 18.uh),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.ur),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12.5.usp,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF7A849C),
        ),
      ),
    );
  }
}

class _StudioImageViewerScreen extends StatelessWidget {
  const _StudioImageViewerScreen({required this.image});

  final DrawingStudioProjectImage image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  image.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48.usp,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8.uh,
              left: 8.w,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 16.uh,
              child: Text(
                image.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.usp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
