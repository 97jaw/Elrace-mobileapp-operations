import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Document scope filters — project scoping for DMS only (not main Projects hub).
class ProjectDocumentsFiltersSheet extends StatefulWidget {
  const ProjectDocumentsFiltersSheet({super.key, required this.initial});

  final ProjectsGroupHubFilters initial;

  static Future<ProjectsGroupHubFilters?> show(
    BuildContext context, {
    required ProjectsGroupHubFilters initial,
  }) {
    return showDialog<ProjectsGroupHubFilters>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 22.w),
        child: ProjectDocumentsFiltersSheet(initial: initial),
      ),
    );
  }

  @override
  State<ProjectDocumentsFiltersSheet> createState() =>
      _ProjectDocumentsFiltersSheetState();
}

class _ProjectDocumentsFiltersSheetState extends State<ProjectDocumentsFiltersSheet> {
  late int? _year;
  late int? _month;
  late String? _statusCompute;
  late String? _woType;
  late final TextEditingController _woRefController;

  static const _statusOptions = [
    ('', 'projects_dashboard.filter_status_all'),
    ('in_progress', 'projects_dashboard.in_progress'),
    ('completed', 'projects_dashboard.completed'),
    ('on_map', 'projects_dashboard.on_map'),
    ('unmapped', 'projects_dashboard.unmapped'),
  ];

  static const _months = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _statusCompute = widget.initial.projectStatusCompute;
    _woType = widget.initial.woTypeNoOffice;
    _woRefController = TextEditingController(text: widget.initial.woRefNo);
  }

  @override
  void dispose() {
    _woRefController.dispose();
    super.dispose();
  }

  List<int> get _yearOptions {
    final now = DateTime.now().year;
    return List.generate(8, (i) => now - i);
  }

  ProjectsGroupHubFilters _buildResult() {
    return ProjectsGroupHubFilters(
      year: _year,
      month: _month,
      projectStatusCompute: _statusCompute,
      woRefNo: _woRefController.text.trim().isEmpty
          ? null
          : _woRefController.text.trim(),
      woTypeNoOffice: _woType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ProjectsDashboardTheme.navy.withValues(alpha: 0.94),
              ProjectsDashboardTheme.greyDeep.withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.18),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Document scope',
                        style: GoogleFonts.poppins(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Limit which project documents appear (folders, files, uploaders). Use the search bar to find by name.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  translate('projects_dashboard.filter_year_month'),
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<int?>(
                        label: translate('projects_dashboard.filter_year'),
                        value: _year,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              translate('projects_dashboard.filter_all'),
                              style: GoogleFonts.poppins(
                                color: ProjectsDashboardTheme.white,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          ..._yearOptions.map(
                            (y) => DropdownMenuItem<int?>(
                              value: y,
                              child: Text(
                                '$y',
                                style: GoogleFonts.poppins(
                                  color: ProjectsDashboardTheme.white,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _year = v),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _DropdownField<int?>(
                        label: translate('projects_dashboard.filter_month'),
                        value: _month,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              translate('projects_dashboard.filter_all'),
                              style: GoogleFonts.poppins(
                                color: ProjectsDashboardTheme.white,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          ..._months.map(
                            (m) => DropdownMenuItem<int?>(
                              value: m,
                              child: Text(
                                DateFormat.MMMM().format(DateTime(2000, m)),
                                style: GoogleFonts.poppins(
                                  color: ProjectsDashboardTheme.white,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _month = v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Text(
                  translate('projects_dashboard.filter_status_compute'),
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _statusOptions.map((opt) {
                    final selected = (_statusCompute ?? '') == opt.$1;
                    return FilterChip(
                      label: Text(translate(opt.$2)),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _statusCompute = opt.$1.isEmpty ? null : opt.$1;
                      }),
                      backgroundColor:
                          ProjectsDashboardTheme.white.withValues(alpha: 0.12),
                      selectedColor: ProjectsDashboardTheme.maroon,
                      checkmarkColor: ProjectsDashboardTheme.white,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? ProjectsDashboardTheme.white
                            : ProjectsDashboardTheme.white,
                      ),
                      side: BorderSide(
                        color: selected
                            ? ProjectsDashboardTheme.maroon
                            : ProjectsDashboardTheme.white
                                .withValues(alpha: 0.22),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: _woRefController,
                  style: GoogleFonts.poppins(
                    color: ProjectsDashboardTheme.white,
                    fontSize: 13.sp,
                  ),
                  decoration: InputDecoration(
                    labelText: translate('projects_dashboard.filter_wo_ref'),
                    labelStyle: GoogleFonts.poppins(
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
                      fontSize: 12.sp,
                    ),
                    hintStyle: GoogleFonts.poppins(
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.45),
                      fontSize: 13.sp,
                    ),
                    filled: true,
                    fillColor: ProjectsDashboardTheme.white.withValues(alpha: 0.16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  translate('projects_dashboard.filter_wo_type'),
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: Text(translate('projects_dashboard.wo_type_active')),
                        selected: _woType == ProjectsWoTypeFilter.active,
                        onSelected: (_) => setState(() {
                          _woType = _woType == ProjectsWoTypeFilter.active
                              ? null
                              : ProjectsWoTypeFilter.active;
                        }),
                        selectedColor: ProjectsDashboardTheme.maroon,
                        backgroundColor:
                            ProjectsDashboardTheme.white.withValues(alpha: 0.12),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: _woType == ProjectsWoTypeFilter.active
                              ? ProjectsDashboardTheme.white
                              : ProjectsDashboardTheme.white,
                        ),
                        side: BorderSide(
                          color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: FilterChip(
                        label: Text(translate('projects_dashboard.wo_type_pending')),
                        selected: _woType == ProjectsWoTypeFilter.pending,
                        onSelected: (_) => setState(() {
                          _woType = _woType == ProjectsWoTypeFilter.pending
                              ? null
                              : ProjectsWoTypeFilter.pending;
                        }),
                        selectedColor: ProjectsDashboardTheme.maroon,
                        backgroundColor:
                            ProjectsDashboardTheme.white.withValues(alpha: 0.12),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: _woType == ProjectsWoTypeFilter.pending
                              ? ProjectsDashboardTheme.white
                              : ProjectsDashboardTheme.white,
                        ),
                        side: BorderSide(
                          color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, const ProjectsGroupHubFilters()),
                      icon: Icon(
                        Icons.clear_all_rounded,
                        size: 18.sp,
                        color: ProjectsDashboardTheme.maroonSoft,
                      ),
                      label: Text(
                        translate('projects_dashboard.clear_filters'),
                        style: GoogleFonts.poppins(
                          color: ProjectsDashboardTheme.maroonSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, _buildResult()),
                      style: FilledButton.styleFrom(
                        backgroundColor: ProjectsDashboardTheme.maroon,
                        foregroundColor: ProjectsDashboardTheme.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 22.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        translate('projects_dashboard.apply_filters'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: GoogleFonts.poppins(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
          fontSize: 11.sp,
        ),
        labelStyle: GoogleFonts.poppins(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
          fontSize: 11.sp,
        ),
        filled: true,
        fillColor: ProjectsDashboardTheme.white.withValues(alpha: 0.16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.32),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(
            color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.9),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: ProjectsDashboardTheme.navy,
          iconEnabledColor: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
          style: GoogleFonts.poppins(
            color: ProjectsDashboardTheme.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
