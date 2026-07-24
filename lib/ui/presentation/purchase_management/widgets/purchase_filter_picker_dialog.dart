import 'dart:async';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseFilterPickerDialog extends StatefulWidget {
  const PurchaseFilterPickerDialog({
    super.key,
    required this.title,
    required this.selectedIds,
    required this.fetchPage,
    this.coloredChips = false,
    this.onLabelsResolved,
  });

  final String title;
  final List<int> selectedIds;

  /// Paginated option loader: `(search, offset, limit) → page`.
  final Future<PurchaseFilterOptionsPage> Function(
    String search,
    int offset,
    int limit,
  ) fetchPage;
  final bool coloredChips;

  /// Called whenever options load so the parent can cache labels.
  final ValueChanged<List<PurchaseFilterOption>>? onLabelsResolved;

  static Future<List<int>?> show(
    BuildContext context, {
    required String title,
    required List<int> selectedIds,
    required Future<PurchaseFilterOptionsPage> Function(
      String search,
      int offset,
      int limit,
    ) fetchPage,
    bool coloredChips = false,
    ValueChanged<List<PurchaseFilterOption>>? onLabelsResolved,
  }) {
    return showDialog<List<int>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.tw, vertical: 28.th),
        child: PurchaseFilterPickerDialog(
          title: title,
          selectedIds: selectedIds,
          fetchPage: fetchPage,
          coloredChips: coloredChips,
          onLabelsResolved: onLabelsResolved,
        ),
      ),
    );
  }

  @override
  State<PurchaseFilterPickerDialog> createState() =>
      _PurchaseFilterPickerDialogState();
}

class _PurchaseFilterPickerDialogState extends State<PurchaseFilterPickerDialog> {
  static const _pageSize = 40;

  late final TextEditingController _searchCtrl;
  late Set<int> _selected;
  final _scroll = ScrollController();

  List<PurchaseFilterOption> _visible = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  String _query = '';
  Timer? _searchDebounce;
  int _requestGen = 0;

  static const _chipPalette = [
    Color(0xFF4A9FD4),
    Color(0xFF2B6CB0),
    Color(0xFF16A34A),
    Color(0xFFE09A3E),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFCA8A04),
    Color(0xFF0891B2),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _selected = widget.selectedIds.toSet();
    _searchCtrl.addListener(_onSearchChanged);
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      _load(reset: false);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _query = _searchCtrl.text.trim();
      _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    final gen = ++_requestGen;
    if (reset) {
      setState(() {
        _loading = true;
        _loadError = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final offset = reset ? 0 : _visible.length;
    try {
      final page = await widget.fetchPage(_query, offset, _pageSize);
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _visible = reset ? page.items : [..._visible, ...page.items];
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _loadError = null;
      });
      widget.onLabelsResolved?.call(page.items);
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _visible = const [];
          _loadError = 'Could not load options';
        }
      });
    }
  }

  Color _chipColor(PurchaseFilterOption option) {
    if (option.color != null && option.color! >= 0) {
      return _chipPalette[option.color! % _chipPalette.length];
    }
    return _chipPalette[option.id % _chipPalette.length];
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogHeight = (screenH * 0.55).clamp(340.th, 520.th);

    return Container(
      height: dialogHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FD),
        borderRadius: BorderRadius.circular(20.tr),
        border: Border.all(
          color: PurchaseTheme.accentBlue.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: PurchaseTheme.accentDeep.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.tw, 16.th, 8.tw, 8.th),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.tsp,
                      fontWeight: FontWeight.w700,
                      color: PurchaseTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20.tsp),
                  color: PurchaseTheme.textMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.tw),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.poppins(fontSize: 13.tsp),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: PurchaseTheme.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: PurchaseTheme.accentBlue,
                  size: 20.tsp,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.tr),
                  borderSide: BorderSide(
                    color: PurchaseTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.tr),
                  borderSide: BorderSide(
                    color: PurchaseTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
              ),
            ),
          ),
          SizedBox(height: 10.th),
          Expanded(child: _buildOptionsList()),
          Padding(
            padding: EdgeInsets.fromLTRB(18.tw, 10.th, 18.tw, 18.th),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w600,
                      color: PurchaseTheme.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PurchaseTheme.accentBlue,
                    minimumSize: Size(120.tw, 42.th),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.tr),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    'Apply',
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList() {
    if (_loading && _visible.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
      );
    }
    if (_loadError != null && _visible.isEmpty) {
      return Center(
        child: Text(
          _loadError!,
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: PurchaseTheme.textMuted,
          ),
        ),
      );
    }
    if (_visible.isEmpty) {
      return Center(
        child: Text(
          'No options found',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: PurchaseTheme.textMuted,
          ),
        ),
      );
    }

    final footer = _loadingMore || _hasMore ? 1 : 0;
    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.symmetric(horizontal: 12.tw),
      itemCount: _visible.length + footer,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: PurchaseTheme.textMuted.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, index) {
        if (index >= _visible.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 14.th),
            child: Center(
              child: _loadingMore
                  ? SizedBox(
                      width: 22.tw,
                      height: 22.tw,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PurchaseTheme.accentBlue,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }

        final option = _visible[index];
        final checked = _selected.contains(option.id);
        final chipColor = widget.coloredChips
            ? _chipColor(option)
            : PurchaseTheme.accentBlue;

        return InkWell(
          onTap: () => _toggle(option.id),
          borderRadius: BorderRadius.circular(10.tr),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 10.th),
            child: Row(
              children: [
                if (widget.coloredChips) ...[
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.tw,
                        vertical: 4.th,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.tr),
                        border: Border.all(
                          color: chipColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        option.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      option.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w500,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                  ),
                Checkbox(
                  value: checked,
                  activeColor: chipColor,
                  onChanged: (_) => _toggle(option.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
