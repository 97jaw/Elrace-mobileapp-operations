import 'dart:async';

import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseFilterPickerDialog extends StatefulWidget {
  const PurchaseFilterPickerDialog({
    super.key,
    required this.title,
    required this.selectedIds,
    required this.fetchOptions,
    this.coloredChips = false,
  });

  final String title;
  final List<int> selectedIds;
  final Future<List<PurchaseFilterOption>> Function(String search) fetchOptions;
  final bool coloredChips;

  static Future<List<int>?> show(
    BuildContext context, {
    required String title,
    required List<int> selectedIds,
    required Future<List<PurchaseFilterOption>> Function(String search)
        fetchOptions,
    bool coloredChips = false,
  }) {
    return showDialog<List<int>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
        child: PurchaseFilterPickerDialog(
          title: title,
          selectedIds: selectedIds,
          fetchOptions: fetchOptions,
          coloredChips: coloredChips,
        ),
      ),
    );
  }

  @override
  State<PurchaseFilterPickerDialog> createState() =>
      _PurchaseFilterPickerDialogState();
}

class _PurchaseFilterPickerDialogState extends State<PurchaseFilterPickerDialog> {
  late final TextEditingController _searchCtrl;
  late Set<int> _selected;
  List<PurchaseFilterOption> _visible = [];
  bool _loading = true;
  String? _loadError;
  Timer? _searchDebounce;

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
    _loadOptions('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions(String query) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await widget.fetchOptions(query);
      if (!mounted) return;
      setState(() {
        _visible = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load options';
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadOptions(_searchCtrl.text.trim());
    });
  }

  Color _chipColor(PurchaseFilterOption option) {
    if (option.color != null && option.color! >= 0) {
      return _chipPalette[option.color! % _chipPalette.length];
    }
    return _chipPalette[option.id % _chipPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogHeight = (screenH * 0.55).clamp(340.h, 520.h);

    return Container(
      height: dialogHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FD),
        borderRadius: BorderRadius.circular(20.r),
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
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 8.w, 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: PurchaseTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20.sp),
                  color: PurchaseTheme.textMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.poppins(fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: PurchaseTheme.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: PurchaseTheme.accentBlue,
                  size: 20.sp,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: PurchaseTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: PurchaseTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(child: _buildOptionsList()),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 18.h),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: PurchaseTheme.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PurchaseTheme.accentBlue,
                    minimumSize: Size(120.w, 42.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    'Apply',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
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
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          _loadError!,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
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
            fontSize: 13.sp,
            color: PurchaseTheme.textMuted,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      itemCount: _visible.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: PurchaseTheme.textMuted.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, index) {
        final option = _visible[index];
        final checked = _selected.contains(option.id);
        final chipColor = widget.coloredChips
            ? _chipColor(option)
            : PurchaseTheme.accentBlue;

        return InkWell(
          onTap: () {
            setState(() {
              if (checked) {
                _selected.remove(option.id);
              } else {
                _selected.add(option.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            child: Row(
              children: [
                if (widget.coloredChips) ...[
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: chipColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        option.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
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
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                  ),
                Checkbox(
                  value: checked,
                  activeColor: chipColor,
                  onChanged: (_) {
                    setState(() {
                      if (checked) {
                        _selected.remove(option.id);
                      } else {
                        _selected.add(option.id);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
