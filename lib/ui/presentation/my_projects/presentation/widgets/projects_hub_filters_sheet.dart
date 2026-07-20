import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Centered filter dialog for project / WO hub and list screens.
class ProjectsHubFiltersSheet extends StatefulWidget {
  const ProjectsHubFiltersSheet({super.key, required this.initial});

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
        insetPadding: EdgeInsets.symmetric(horizontal: 22.tw),
        child: ProjectsHubFiltersSheet(initial: initial),
      ),
    );
  }

  @override
  State<ProjectsHubFiltersSheet> createState() =>
      _ProjectsHubFiltersSheetState();
}

class _ProjectsHubFiltersSheetState extends State<ProjectsHubFiltersSheet> {
  late int? _year;
  late int? _month;
  late String? _statusCompute;
  late String? _woType;
  late final TextEditingController _searchController;
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
    _searchController = TextEditingController(text: widget.initial.searchName);
    _woRefController = TextEditingController(text: widget.initial.woRefNo);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _woRefController.dispose();
    super.dispose();
  }

  List<int> get _yearOptions {
    final now = DateTime.now().year;
    return List.generate(8, (i) => now - i);
  }

  static const _titleColor = ProjectsDashboardTheme.navy;
  static const _bodyColor = ProjectsDashboardTheme.greyDark;
  static const _hintColor = ProjectsDashboardTheme.grey;
  static const _panelTop = Color(0xFFF4F5F8);
  static const _panelBottom = Color(0xFFE8EBF0);

  InputDecoration _fieldDecoration({
    String? hint,
    String? label,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      hintStyle: GoogleFonts.poppins(
        color: _hintColor,
        fontSize: 13.tsp,
      ),
      labelStyle: GoogleFonts.poppins(
        color: _bodyColor,
        fontSize: 12.tsp,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: ProjectsDashboardTheme.maroon, size: 20.tsp)
          : null,
      filled: true,
      fillColor: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.tr),
        borderSide: BorderSide(
          color: ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.9),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.tr),
        borderSide: BorderSide(
          color: ProjectsDashboardTheme.greyPanel,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.tr),
        borderSide: BorderSide(
          color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.75),
          width: 1.4,
        ),
      ),
    );
  }

  TextStyle get _inputStyle => GoogleFonts.poppins(
        color: _titleColor,
        fontSize: 13.tsp,
      );

  TextStyle get _sectionLabel => GoogleFonts.poppins(
        fontSize: 12.tsp,
        fontWeight: FontWeight.w600,
        color: _bodyColor,
      );

  ProjectsGroupHubFilters _buildResult() {
    return ProjectsGroupHubFilters(
      year: _year,
      month: _month,
      projectStatusCompute: _statusCompute,
      woRefNo: _woRefController.text.trim().isEmpty
          ? null
          : _woRefController.text.trim(),
      woTypeNoOffice: _woType,
      searchName: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.tr),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_panelTop, _panelBottom],
          ),
          border: Border.all(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.tr),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.tw, 18.th, 20.tw, 16.th),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        translate('projects_dashboard.smart_filters'),
                        style: GoogleFonts.poppins(
                          fontSize: 17.tsp,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _bodyColor,
                        size: 22.tsp,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 32.tw,
                        minHeight: 32.tw,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.th),
                Text(
                  translate('projects_dashboard.filters_affect_projects_hint'),
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    color: _hintColor,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 14.th),
                TextField(
                  controller: _searchController,
                  style: _inputStyle,
                  decoration: _fieldDecoration(
                    hint: translate('projects_dashboard.search_name_hint'),
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                SizedBox(height: 14.th),
                Text(translate('projects_dashboard.filter_year_month'), style: _sectionLabel),
                SizedBox(height: 8.th),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<int?>(
                        label: translate('projects_dashboard.filter_year'),
                        value: _year,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(translate('projects_dashboard.filter_all')),
                          ),
                          ..._yearOptions.map(
                            (y) => DropdownMenuItem<int?>(value: y, child: Text('$y')),
                          ),
                        ],
                        onChanged: (v) => setState(() => _year = v),
                      ),
                    ),
                    SizedBox(width: 10.tw),
                    Expanded(
                      child: _DropdownField<int?>(
                        label: translate('projects_dashboard.filter_month'),
                        value: _month,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(translate('projects_dashboard.filter_all')),
                          ),
                          ..._months.map(
                            (m) => DropdownMenuItem<int?>(
                              value: m,
                              child: Text(DateFormat.MMMM().format(DateTime(2000, m))),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _month = v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.th),
                Text(translate('projects_dashboard.filter_status_compute'), style: _sectionLabel),
                SizedBox(height: 8.th),
                Wrap(
                  spacing: 8.tw,
                  runSpacing: 8.th,
                  children: _statusOptions.map((opt) {
                    final selected = (_statusCompute ?? '') == opt.$1;
                    return FilterChip(
                      label: Text(translate(opt.$2)),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _statusCompute = opt.$1.isEmpty ? null : opt.$1;
                      }),
                      backgroundColor: ProjectsDashboardTheme.white,
                      selectedColor: ProjectsDashboardTheme.maroon,
                      checkmarkColor: ProjectsDashboardTheme.white,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? ProjectsDashboardTheme.white
                            : _titleColor,
                      ),
                      side: BorderSide(
                        color: selected
                            ? ProjectsDashboardTheme.maroon
                            : ProjectsDashboardTheme.greyPanel,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 14.th),
                TextField(
                  controller: _woRefController,
                  style: _inputStyle,
                  decoration: _fieldDecoration(
                    label: translate('projects_dashboard.filter_wo_ref'),
                  ),
                ),
                SizedBox(height: 14.th),
                Text(translate('projects_dashboard.filter_wo_type'), style: _sectionLabel),
                SizedBox(height: 8.th),
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
                        backgroundColor: ProjectsDashboardTheme.white,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: _woType == ProjectsWoTypeFilter.active
                              ? ProjectsDashboardTheme.white
                              : _titleColor,
                        ),
                        side: BorderSide(color: ProjectsDashboardTheme.greyPanel),
                      ),
                    ),
                    SizedBox(width: 8.tw),
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
                        backgroundColor: ProjectsDashboardTheme.white,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: _woType == ProjectsWoTypeFilter.pending
                              ? ProjectsDashboardTheme.white
                              : _titleColor,
                        ),
                        side: BorderSide(color: ProjectsDashboardTheme.greyPanel),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.th),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, const ProjectsGroupHubFilters()),
                      icon: Icon(
                        Icons.clear_all_rounded,
                        size: 18.tsp,
                        color: ProjectsDashboardTheme.maroon,
                      ),
                      label: Text(
                        translate('projects_dashboard.clear_filters'),
                        style: GoogleFonts.poppins(
                          color: ProjectsDashboardTheme.maroon,
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
                          horizontal: 22.tw,
                          vertical: 12.th,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.tr),
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
        labelStyle: GoogleFonts.poppins(
          color: ProjectsDashboardTheme.greyDark,
          fontSize: 11.tsp,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.tr),
          borderSide: BorderSide(color: ProjectsDashboardTheme.greyPanel),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 4.th),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: ProjectsDashboardTheme.white,
          style: GoogleFonts.poppins(
            color: ProjectsDashboardTheme.navy,
            fontSize: 13.tsp,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
