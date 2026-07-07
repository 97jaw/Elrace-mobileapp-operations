import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmSearchField extends StatefulWidget {
  const TmSearchField({
    super.key,
    this.hintText = 'Search',
    required this.onDebouncedChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hintText;
  final ValueChanged<String> onDebouncedChanged;
  final Duration debounce;

  @override
  State<TmSearchField> createState() => _TmSearchFieldState();
}

class _TmSearchFieldState extends State<TmSearchField> {
  late final TextEditingController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onDebouncedChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TimesheetModuleColors.divider),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: TimesheetModuleColors.mutedText,
            size: 20,
          ),
          hintText: widget.hintText,
          hintStyle: TimesheetModuleTypography.body().copyWith(
            color: TimesheetModuleColors.mutedText,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: TimesheetModuleTypography.body(),
      ),
    );
  }
}
