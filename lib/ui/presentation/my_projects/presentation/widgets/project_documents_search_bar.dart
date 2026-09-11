import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Expandable search field for Project Documents (toggled from header).
class ProjectDocumentsSearchBar extends StatefulWidget {
  const ProjectDocumentsSearchBar({
    super.key,
    required this.hint,
    required this.onSearchChanged,
    this.initialQuery = '',
    this.autofocus = true,
  });

  final String hint;
  final ValueChanged<String> onSearchChanged;
  final String initialQuery;
  final bool autofocus;

  @override
  State<ProjectDocumentsSearchBar> createState() =>
      _ProjectDocumentsSearchBarState();
}

class _ProjectDocumentsSearchBarState extends State<ProjectDocumentsSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onSearchChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 10.th),
      child: Container(
        height: 42.th,
        padding: EdgeInsets.symmetric(horizontal: 12.tw),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.tr),
          color: Colors.black.withValues(alpha: 0.58),
          border: Border.all(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20.tsp,
              color: ProjectsDashboardTheme.greyPanel,
            ),
            SizedBox(width: 8.tw),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.white,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    color: ProjectsDashboardTheme.greyPanel
                        .withValues(alpha: 0.85),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: _clear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18.tsp,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.tw, minHeight: 32.tw),
              ),
          ],
        ),
      ),
    );
  }
}
