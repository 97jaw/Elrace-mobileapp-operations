import 'dart:async';

import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Search field with leading icon and 300ms debounced callbacks (SRD §3.1).
///
/// Stateful: owns debounce timer. Pass [controller] to sync with parent; if
/// omitted, an internal controller is created and disposed.
///
/// ```dart
/// HrSearchBar(
///   hintText: 'Search by reference or type',
///   onDebouncedChanged: (q) => ref.read(searchProvider.notifier).state = q,
/// )
/// ```
class HrSearchBar extends StatefulWidget {
  const HrSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onDebouncedChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onDebouncedChanged;
  final Duration debounce;

  @override
  State<HrSearchBar> createState() => _HrSearchBarState();
}

class _HrSearchBarState extends State<HrSearchBar> {
  late TextEditingController _controller;
  Timer? _timer;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () {
      widget.onDebouncedChanged?.call(_controller.text);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: HrModuleTypography.body().copyWith(
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: HrModuleTypography.caption().copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: HrModuleColors.mutedText.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(Icons.search, color: HrModuleColors.mutedText, size: 22.sp),
        filled: true,
        fillColor: HrModuleColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: HrModuleLayout.screenPaddingH.w,
          vertical: 12.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
          borderSide: const BorderSide(color: HrModuleColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
          borderSide: const BorderSide(color: HrModuleColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
          borderSide: const BorderSide(color: HrModuleColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
