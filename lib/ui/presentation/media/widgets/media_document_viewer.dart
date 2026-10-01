import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../lpo/screens/lpo_pdf_viewer_screen.dart';
import '../data/content_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_pdf_pages.dart';

/// Fullscreen photo viewer for a Photos-tab file: every PDF page is shown as
/// a photo with swipe, pinch / double-tap zoom, page counter, page strip,
/// share and save.
class MediaDocumentViewer extends StatefulWidget {
  const MediaDocumentViewer({
    super.key,
    required this.content,
    this.headers,
  });

  final ContentModel content;
  final Map<String, String>? headers;

  static Future<void> open(
    BuildContext context, {
    required ContentModel content,
    Map<String, String>? headers,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            MediaDocumentViewer(content: content, headers: headers),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<MediaDocumentViewer> createState() => _MediaDocumentViewerState();
}

class _MediaDocumentViewerState extends State<MediaDocumentViewer> {
  static const double _savePageWidthPx = 2400;
  static const double _stripThumbWidthPx = 160;

  final PageController _pageController = PageController();
  final ScrollController _stripController = ScrollController();

  MediaPdfDocument? _doc;
  Object? _error;
  double? _progress;
  int _index = 0;
  bool _chromeVisible = true;
  bool _zoomed = false;
  bool _busy = false;

  double get _stripItemExtent => 52.tw + 8.tw;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _progress = null;
    });
    try {
      final doc = await MediaPdfPages.load(
        widget.content,
        headers: widget.headers,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _doc = doc);
      _prefetchAfter(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  double _viewerPageWidthPx(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.min(media.size.width * media.devicePixelRatio * 1.5, 2400);
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
    });
    _scrollStripTo(index);
    _prefetchAfter(index);
  }

  /// Renders the next page once the visible one is queued, so swipes feel
  /// instant without delaying the page on screen.
  void _prefetchAfter(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doc = _doc;
      if (!mounted || doc == null || index + 1 >= doc.pageCount) return;
      doc.page(index + 1, targetWidthPx: _viewerPageWidthPx(context)).ignore();
    });
  }

  void _scrollStripTo(int index) {
    if (!_stripController.hasClients) return;
    final viewport = _stripController.position.viewportDimension;
    final target =
        (index * _stripItemExtent) - (viewport - _stripItemExtent) / 2;
    _stripController.animateTo(
      target.clamp(0.0, _stripController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _jumpTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String get _baseName {
    final name = widget.content.displayName.trim();
    final safe = name.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
    return safe.isEmpty ? 'photo' : safe.replaceAll(' ', '_');
  }

  Rect _shareOrigin() {
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _currentPageForExport() {
    return _doc!.page(_index, targetWidthPx: _savePageWidthPx);
  }

  Future<void> _savePage() => _runBusy(() async {
        final doc = _doc;
        if (doc == null) return;
        try {
          if (!await Gal.hasAccess(toAlbum: true) &&
              !await Gal.requestAccess(toAlbum: true)) {
            _toast('Allow photo access to save images.');
            return;
          }
          final bytes = await _currentPageForExport();
          final name =
              doc.pageCount > 1 ? '${_baseName}_${_index + 1}' : _baseName;
          await Gal.putImageBytes(bytes, album: 'RCC', name: name);
          if (mounted) _toast('Saved to gallery');
        } catch (_) {
          if (mounted) _toast('Could not save the photo.');
        }
      });

  Future<void> _sharePage() => _runBusy(() async {
        final doc = _doc;
        if (doc == null) return;
        try {
          final XFile file;
          if (doc.isPdf) {
            final bytes = await _currentPageForExport();
            final dir = await getTemporaryDirectory();
            final path = '${dir.path}/${_baseName}_${_index + 1}.png';
            await File(path).writeAsBytes(bytes, flush: true);
            file = XFile(path, mimeType: 'image/png');
          } else {
            file = XFile(doc.file.path);
          }
          await SharePlus.instance.share(ShareParams(
            files: [file],
            sharePositionOrigin: _shareOrigin(),
          ));
        } catch (_) {
          if (mounted) _toast('Could not share the photo.');
        }
      });

  Future<void> _shareDocument() => _runBusy(() async {
        final doc = _doc;
        if (doc == null) return;
        try {
          await SharePlus.instance.share(ShareParams(
            files: [
              XFile(
                doc.file.path,
                mimeType: 'application/pdf',
                name: '$_baseName.pdf',
              ),
            ],
            sharePositionOrigin: _shareOrigin(),
          ));
        } catch (_) {
          if (mounted) _toast('Could not share the file.');
        }
      });

  void _openAsDocument() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LpoPdfViewerScreen(
          pdfUrl: widget.content.previewUrl,
          title: widget.content.displayName,
        ),
      ),
    );
  }

  void _showMoreMenu() {
    final doc = _doc;
    if (doc == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MediaTheme.sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
      ),
      builder: (sheetContext) {
        Widget tile(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: Icon(icon, color: Colors.white),
            title: Text(label, style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.th),
              tile(
                  Icons.download_rounded,
                  doc.pageCount > 1 ? 'Save this photo' : 'Save photo',
                  _savePage),
              tile(
                  Icons.ios_share_rounded,
                  doc.pageCount > 1 ? 'Share this photo' : 'Share photo',
                  _sharePage),
              if (doc.isPdf) ...[
                tile(Icons.picture_as_pdf_rounded, 'Share PDF file',
                    _shareDocument),
                tile(Icons.description_outlined, 'Open as PDF document',
                    _openAsDocument),
              ],
              SizedBox(height: 8.th),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBody(context),
            _buildTopBar(context),
            if (_doc != null && _doc!.pageCount > 1) _buildPageStrip(context),
            if (_busy)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final doc = _doc;
    if (_error != null) return _buildError();
    if (doc == null) return _buildLoading();

    final pageWidthPx = _viewerPageWidthPx(context);
    return PageView.builder(
      controller: _pageController,
      itemCount: doc.pageCount,
      physics: _zoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _ZoomablePage(
          key: ValueKey('media-page-$index'),
          doc: doc,
          index: index,
          targetWidthPx: pageWidthPx,
          onTap: () => setState(() => _chromeVisible = !_chromeVisible),
          onZoomChanged: (zoomed) {
            if (index == _index && zoomed != _zoomed) {
              setState(() => _zoomed = zoomed);
            }
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    final progress = _progress;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44.tw,
            height: 44.tw,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
              value: progress,
            ),
          ),
          SizedBox(height: 14.th),
          Text(
            progress == null
                ? 'Loading photos...'
                : 'Loading photos ${(progress * 100).round()}%',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13.tsp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.tw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 56.tsp),
            SizedBox(height: 12.th),
            Text(
              'Could not load these photos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15.tsp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.th),
            Text(
              'Check your connection and try again. If it keeps failing, '
              'reopen the Media screen.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 12.tsp,
              ),
            ),
            SizedBox(height: 18.th),
            MediaTheme.pillButton(label: 'Retry', onTap: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final doc = _doc;
    final title = widget.content.displayName.trim();
    final subtitle = widget.content.projectName.trim();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.tw, 4.th, 8.tw, 16.th),
                child: Row(
                  children: [
                    _circleButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title.isNotEmpty)
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14.tsp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11.tsp,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (doc != null && doc.pageCount > 1)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 6.tw),
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.tw, vertical: 4.th),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12.tr),
                        ),
                        child: Text(
                          '${_index + 1}/${doc.pageCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (doc != null) ...[
                      _circleButton(
                        icon: Icons.ios_share_rounded,
                        tooltip: 'Share',
                        onTap: _sharePage,
                      ),
                      SizedBox(width: 6.tw),
                      _circleButton(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More',
                        onTap: _showMoreMenu,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageStrip(BuildContext context) {
    final doc = _doc!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(top: 20.th, bottom: 10.th),
                child: SizedBox(
                  height: 68.th,
                  child: ListView.builder(
                    controller: _stripController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12.tw),
                    itemExtent: _stripItemExtent,
                    itemCount: doc.pageCount,
                    itemBuilder: (context, index) {
                      final selected = index == _index;
                      return Padding(
                        padding: EdgeInsets.only(right: 8.tw),
                        child: GestureDetector(
                          onTap: () => _jumpTo(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.tr),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.18),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7.tr),
                              child: Opacity(
                                opacity: selected ? 1 : 0.6,
                                child: _PageImage(
                                  doc: doc,
                                  index: index,
                                  targetWidthPx: _stripThumbWidthPx,
                                  fit: BoxFit.cover,
                                  compact: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Container(
        padding: EdgeInsets.all(6.tw),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.tsp),
      ),
    );
  }
}

/// One page with pinch zoom and double-tap to zoom in / out.
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    super.key,
    required this.doc,
    required this.index,
    required this.targetWidthPx,
    required this.onTap,
    required this.onZoomChanged,
  });

  final MediaPdfDocument doc;
  final int index;
  final double targetWidthPx;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _zoomTween;
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final tween = _zoomTween;
        if (tween != null) _transform.value = tween.value;
      });
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _toggleZoom() {
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      final p = _doubleTapPosition;
      end = Matrix4.identity()
        ..translateByDouble(
          -p.dx * (_doubleTapScale - 1),
          -p.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    );
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: AspectRatio(
            aspectRatio: widget.doc.aspectRatio(widget.index),
            child: _PageImage(
              doc: widget.doc,
              index: widget.index,
              targetWidthPx: widget.targetWidthPx,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders one page lazily; keeps the last frame while a sharper one loads.
class _PageImage extends StatefulWidget {
  const _PageImage({
    required this.doc,
    required this.index,
    required this.targetWidthPx,
    required this.fit,
    this.compact = false,
  });

  final MediaPdfDocument doc;
  final int index;
  final double targetWidthPx;
  final BoxFit fit;
  final bool compact;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _render();
  }

  @override
  void didUpdateWidget(covariant _PageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc != widget.doc ||
        oldWidget.index != widget.index ||
        oldWidget.targetWidthPx != widget.targetWidthPx) {
      _future = _render();
    }
  }

  Future<Uint8List> _render() =>
      widget.doc.page(widget.index, targetWidthPx: widget.targetWidthPx);

  void _retry() => setState(() => _future = _render());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: const Color(0xFF1A1A1A),
            child: widget.compact
                ? Icon(Icons.error_outline, color: Colors.white38, size: 18.tsp)
                : Center(
                    child: TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      label: Text(
                        'Tap to retry',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ),
                  ),
          );
        }
        return ColoredBox(
          color: const Color(0xFF1A1A1A),
          child: Center(
            child: SizedBox(
              width: widget.compact ? 14.tw : 28.tw,
              height: widget.compact ? 14.tw : 28.tw,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        );
      },
    );
  }
}
