import 'dart:async';

import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_filters_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsSearchBar extends StatefulWidget {
  const ProjectDocumentsSearchBar({
    super.key,
    required this.hint,
    required this.hasActiveFilters,
    required this.initialFilters,
    required this.onSearchChanged,
    required this.onFiltersApplied,
    this.initialQuery = '',
  });

  final String hint;
  final bool hasActiveFilters;
  final ProjectsGroupHubFilters initialFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProjectsGroupHubFilters> onFiltersApplied;
  final String initialQuery;

  @override
  State<ProjectDocumentsSearchBar> createState() =>
      _ProjectDocumentsSearchBarState();
}

class _ProjectDocumentsSearchBarState extends State<ProjectDocumentsSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onSearchChanged(value);
    });
  }

  Future<void> _openFilters() async {
    final result = await ProjectDocumentsFiltersSheet.show(
      context,
      initial: widget.initialFilters,
    );
    if (result != null && mounted) {
      widget.onFiltersApplied(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.14),
                border: Border.all(
                  color: ProjectsDashboardTheme.white.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20.sp,
                    color: ProjectsDashboardTheme.greyPanel,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onChanged,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: ProjectsDashboardTheme.white,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: ProjectsDashboardTheme.greyPanel
                              .withValues(alpha: 0.85),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: widget.hasActiveFilters
                      ? ProjectsDashboardTheme.maroon.withValues(alpha: 0.85)
                      : ProjectsDashboardTheme.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20.sp,
                      color: ProjectsDashboardTheme.white,
                    ),
                    if (widget.hasActiveFilters)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
