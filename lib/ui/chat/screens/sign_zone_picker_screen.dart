import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../chat/models/message.dart';
import '../theme/chat_glass_theme.dart';

/// Screen for the sender to pick sign zones on a PDF before sending.
/// Zones are fixed-size (no resize). Max 2 signature + max 2 stamp zones.
class SignZonePickerScreen extends StatefulWidget {
  final File pdfFile;
  final String fileName;

  const SignZonePickerScreen({
    super.key,
    required this.pdfFile,
    required this.fileName,
  });

  @override
  State<SignZonePickerScreen> createState() => _SignZonePickerScreenState();
}

class _SignZonePickerScreenState extends State<SignZonePickerScreen> {
  static const int _maxSignatureZones = 2;
  static const int _maxStampZones = 2;

  /// Fixed signature zone (relative to page).
  static const double _sigZoneW = 0.30;
  static const double _sigZoneH = 0.06;

  /// Fixed stamp zone — roomy box; image is drawn contain/centered (no stretch).
  static const double _stampZoneW = 0.22;
  static const double _stampZoneH = 0.12;

  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  int _pageCount = 0;
  PDFViewController? _pdfController;

  final List<SignZone> _signZones = [];
  final List<Size> _pageSizes = [];

  bool _isPlaceMode = true;
  SignZoneType _activeTool = SignZoneType.signature;
  Size _viewSize = Size.zero;
  int? _selectedZoneIndex;

  int? _movingZoneIndex;
  Offset? _moveStartGlobal;
  SignZone? _moveStartZone;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      try {
        final doc = PdfDocument(inputBytes: bytes);
        _pageCount = doc.pages.count;
        _pageSizes
          ..clear()
          ..addAll(List<Size>.generate(_pageCount, (i) {
            final s = doc.pages[i].getClientSize();
            return Size(s.width, s.height);
          }));
        doc.dispose();
      } catch (_) {
        _pageCount = 1;
        _pageSizes
          ..clear()
          ..add(const Size(595, 842));
      }

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading PDF: $e';
          _loading = false;
        });
      }
    }
  }

  Rect _pdfPageRectForCurrentView() {
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return Rect.zero;

    const fallback = Size(595, 842);
    final pageSize = (_currentPage >= 0 && _currentPage < _pageSizes.length)
        ? _pageSizes[_currentPage]
        : fallback;

    final pageRatio = pageSize.width / pageSize.height;
    final viewRatio = _viewSize.width / _viewSize.height;

    if (viewRatio > pageRatio) {
      final height = _viewSize.height;
      final width = height * pageRatio;
      final left = (_viewSize.width - width) / 2;
      return Rect.fromLTWH(left, 0, width, height);
    }

    final width = _viewSize.width;
    final height = width / pageRatio;
    final top = (_viewSize.height - height) / 2;
    return Rect.fromLTWH(0, top, width, height);
  }

  int get _signatureCount =>
      _signZones.where((z) => z.type == SignZoneType.signature).length;
  int get _stampCount =>
      _signZones.where((z) => z.type == SignZoneType.stamp).length;

  void _addSignZone(Offset tapPosition) {
    if (_viewSize == Size.zero) return;

    final pageRect = _pdfPageRectForCurrentView();
    if (!pageRect.contains(tapPosition)) return;

    if (_activeTool == SignZoneType.signature &&
        _signatureCount >= _maxSignatureZones) {
      _showLimitSnack(
        'Maximum $_maxSignatureZones signature zones allowed',
      );
      return;
    }
    if (_activeTool == SignZoneType.stamp && _stampCount >= _maxStampZones) {
      _showLimitSnack('Maximum $_maxStampZones stamp zones allowed');
      return;
    }

    final zoneW =
        _activeTool == SignZoneType.stamp ? _stampZoneW : _sigZoneW;
    final zoneH =
        _activeTool == SignZoneType.stamp ? _stampZoneH : _sigZoneH;

    final relX =
        ((tapPosition.dx - pageRect.left) / pageRect.width).clamp(0.0, 1.0);
    final relY =
        ((tapPosition.dy - pageRect.top) / pageRect.height).clamp(0.0, 1.0);

    final x = (relX - zoneW / 2).clamp(0.0, 1.0 - zoneW);
    final y = (relY - zoneH / 2).clamp(0.0, 1.0 - zoneH);

    setState(() {
      _signZones.add(SignZone(
        page: _currentPage,
        x: x,
        y: y,
        width: zoneW,
        height: zoneH,
        type: _activeTool,
      ));
      _selectedZoneIndex = _signZones.length - 1;
    });
  }

  void _showLimitSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _onZoneMoveStart(int index, DragStartDetails details) {
    if (index < 0 || index >= _signZones.length) return;
    _movingZoneIndex = index;
    _moveStartGlobal = details.globalPosition;
    _moveStartZone = _signZones[index];
    setState(() => _selectedZoneIndex = index);
  }

  void _onZoneMoveUpdate(DragUpdateDetails details) {
    final index = _movingZoneIndex;
    final startGlobal = _moveStartGlobal;
    final startZone = _moveStartZone;
    if (index == null || startGlobal == null || startZone == null) return;
    if (index < 0 || index >= _signZones.length) return;

    final pageRect = _pdfPageRectForCurrentView();
    if (pageRect.width <= 0 || pageRect.height <= 0) return;

    final totalDelta = details.globalPosition - startGlobal;
    final dx = totalDelta.dx / pageRect.width;
    final dy = totalDelta.dy / pageRect.height;

    final nextX = (startZone.x + dx).clamp(0.0, 1.0 - startZone.width);
    final nextY = (startZone.y + dy).clamp(0.0, 1.0 - startZone.height);

    setState(() {
      _signZones[index] = startZone.copyWith(x: nextX, y: nextY);
    });
  }

  void _onZoneMoveEnd([DragEndDetails? _]) {
    _movingZoneIndex = null;
    _moveStartGlobal = null;
    _moveStartZone = null;
  }

  int? _findZoneAt(Offset point, Rect pageRect) {
    for (int i = _signZones.length - 1; i >= 0; i--) {
      final zone = _signZones[i];
      if (zone.page != _currentPage) continue;

      final rect = Rect.fromLTWH(
        pageRect.left + (zone.x * pageRect.width),
        pageRect.top + (zone.y * pageRect.height),
        zone.width * pageRect.width,
        zone.height * pageRect.height,
      );

      if (rect.contains(point)) return i;
    }
    return null;
  }

  void _removeSignZone(int index) {
    setState(() {
      _signZones.removeAt(index);
      if (_movingZoneIndex == index) _onZoneMoveEnd();

      if (_selectedZoneIndex == index) {
        _selectedZoneIndex = null;
      } else if (_selectedZoneIndex != null && _selectedZoneIndex! > index) {
        _selectedZoneIndex = _selectedZoneIndex! - 1;
      }
    });
  }

  void _confirm() {
    if (_signZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one sign or stamp zone'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'signZones': _signZones,
      'pageCount': _pageCount,
      'stampNeeded': _signZones.any((z) => z.isStamp),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D2449),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Sign & Stamp Zones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              'Send (${_signZones.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildToolBar(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color:
              _isPlaceMode ? const Color(0xFFFFF3CD) : const Color(0xFFD1ECF1),
          child: Row(
            children: [
              Icon(
                _isPlaceMode ? Icons.touch_app : Icons.swipe,
                size: 20,
                color: _isPlaceMode
                    ? const Color(0xFF856404)
                    : const Color(0xFF0C5460),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isPlaceMode
                      ? (_activeTool == SignZoneType.stamp
                          ? 'Stamp: tap to place (max $_maxStampZones). Drag to move.'
                          : 'Sign: tap to place (max $_maxSignatureZones). Drag to move.')
                      : 'Scroll to browse pages. Switch back to edit zones.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isPlaceMode
                        ? const Color(0xFF856404)
                        : const Color(0xFF0C5460),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_signZones.where((z) => z.page == _currentPage).isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _signZones.removeWhere((z) => z.page == _currentPage);
                      _selectedZoneIndex = null;
                    });
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                children: [
                  AbsorbPointer(
                    absorbing: _isPlaceMode,
                    child: _buildPdfView(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_isPlaceMode,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final pageRect = _pdfPageRectForCurrentView();
                          final tappedZone =
                              _findZoneAt(details.localPosition, pageRect);
                          if (tappedZone != null) {
                            setState(() => _selectedZoneIndex = tappedZone);
                            return;
                          }
                          _addSignZone(details.localPosition);
                        },
                      ),
                    ),
                  ),
                  if (_isPlaceMode) ..._buildSignZoneOverlays(),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'mode_toggle',
                      backgroundColor: _isPlaceMode
                          ? ChatGlassTheme.silverDeep
                          : ChatGlassTheme.gold,
                      onPressed: () {
                        setState(() {
                          _isPlaceMode = !_isPlaceMode;
                          _selectedZoneIndex = null;
                        });
                      },
                      child: Icon(
                        _isPlaceMode ? Icons.swipe : Icons.touch_app,
                        color: _isPlaceMode
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF1A1A1A),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => _pdfController?.setPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
              ),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => _pdfController?.setPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _signZones.isEmpty
                      ? Colors.grey[200]
                      : const Color(0xFF1D2449),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_signatureCount} sign · ${_stampCount} stamp'
                  '${_signZones.isEmpty ? ' · none yet' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _signZones.isEmpty ? Colors.grey[600] : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _ToolChip(
            selected: _activeTool == SignZoneType.signature && _isPlaceMode,
            icon: Icons.draw,
            label: 'Sign',
            color: const Color(0xFFD4A843),
            onTap: () => setState(() {
              _isPlaceMode = true;
              _activeTool = SignZoneType.signature;
            }),
          ),
          const SizedBox(width: 8),
          _ToolChip(
            selected: _activeTool == SignZoneType.stamp && _isPlaceMode,
            icon: Icons.approval,
            label: 'Stamp',
            color: const Color(0xFF2E7D6F),
            onTap: () => setState(() {
              _isPlaceMode = true;
              _activeTool = SignZoneType.stamp;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
    return PDFView(
      pdfData: _pdfBytes,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      backgroundColor: Colors.grey[200]!,
      onViewCreated: (controller) => _pdfController = controller,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
          _selectedZoneIndex = null;
        });
      },
    );
  }

  List<Widget> _buildSignZoneOverlays() {
    final zonesOnPage = <int, SignZone>{};
    for (int i = 0; i < _signZones.length; i++) {
      if (_signZones[i].page == _currentPage) {
        zonesOnPage[i] = _signZones[i];
      }
    }

    final pageRect = _pdfPageRectForCurrentView();

    return zonesOnPage.entries.map((entry) {
      final zone = entry.value;
      final idx = entry.key;
      final isSelected = _selectedZoneIndex == idx;

      final left = pageRect.left + (zone.x * pageRect.width);
      final top = pageRect.top + (zone.y * pageRect.height);
      final width = zone.width * pageRect.width;
      final height = zone.height * pageRect.height;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedZoneIndex = idx),
                onPanStart: (details) => _onZoneMoveStart(idx, details),
                onPanUpdate: _onZoneMoveUpdate,
                onPanEnd: _onZoneMoveEnd,
                onPanCancel: _onZoneMoveEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: (zone.isStamp
                            ? const Color(0xFF2E7D6F)
                            : const Color(0xFFD4A843))
                        .withValues(alpha: isSelected ? 0.35 : 0.25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D2449)
                          : (zone.isStamp
                              ? const Color(0xFF2E7D6F)
                              : const Color(0xFFD4A843)),
                      width: isSelected ? 2.5 : 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              zone.isStamp ? Icons.approval : Icons.draw,
                              size: 12,
                              color: zone.isStamp
                                  ? const Color(0xFF1B5E50)
                                  : const Color(0xFF856404),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              zone.isStamp ? 'Stamp Here' : 'Sign Here',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: zone.isStamp
                                    ? const Color(0xFF1B5E50)
                                    : const Color(0xFF856404),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -11,
              right: -11,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removeSignZone(idx),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _ToolChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.grey[300]!,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
