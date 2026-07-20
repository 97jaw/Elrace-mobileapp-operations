import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_hub_loader.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_hub_filter_button.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_hub_filters_sheet.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_cached_image.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

typedef ProjectsGroupHubItemTap = void Function(
  ProjectManagerFilterItem item,
  ProjectsGroupByMode mode,
  ProjectsGroupHubFilters filters,
);

/// Unified group-by hub: PM / Client / City badges + smart filters.
class ProjectsGroupHubScreen extends StatefulWidget {
  const ProjectsGroupHubScreen({
    super.key,
    required this.onItemTap,
    this.onHome,
    this.initialMode = ProjectsGroupByMode.projectManager,
  });

  final ProjectsGroupHubItemTap onItemTap;
  final VoidCallback? onHome;
  final ProjectsGroupByMode initialMode;

  @override
  State<ProjectsGroupHubScreen> createState() => _ProjectsGroupHubScreenState();
}

class _ProjectsGroupHubScreenState extends State<ProjectsGroupHubScreen> {
  late ProjectsGroupByMode _mode;
  ProjectsGroupHubFilters _filters = const ProjectsGroupHubFilters();

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final q = _searchController.text.trim();
      final next = ProjectsGroupHubFilters(
        year: _filters.year,
        month: _filters.month,
        projectStatusCompute: _filters.projectStatusCompute,
        woRefNo: _filters.woRefNo,
        woTypeNoOffice: _filters.woTypeNoOffice,
        searchName: q.isEmpty ? null : q,
      );
      if (next == _filters) return;
      setState(() => _filters = next);
      _load();
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectsGroupHubLoader().load(
        mode: _mode,
        filters: _filters,
      );

      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('handshake') ||
        msg.contains('connection') ||
        msg.contains('terminated') ||
        msg.contains('socket')) {
      return translate('projects_dashboard.connection_error');
    }
    return e.toString();
  }

  void _selectMode(ProjectsGroupByMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _load();
  }

  Future<void> _openSmartFilters() async {
    final result = await ProjectsHubFiltersSheet.show(
      context,
      initial: _filters,
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    final sheetSearch = result.searchName?.trim() ?? '';
    if (_searchController.text.trim() != sheetSearch) {
      _searchController.text = sheetSearch;
    }
    _load();
  }

  void _clearFilters() {
    if (!_filters.hasActiveFilters) return;
    setState(() => _filters = const ProjectsGroupHubFilters());
    _searchController.clear();
    _load();
  }

  void _goHome() {
    if (widget.onHome != null) {
      widget.onHome!();
      return;
    }
    Navigator.of(context).pop();
  }

  String _titleForMode(ProjectsGroupByMode mode) {
    return switch (mode) {
      ProjectsGroupByMode.projectManager =>
        translate('projects_dashboard.group_by_pm'),
      ProjectsGroupByMode.client =>
        translate('projects_dashboard.group_by_client'),
      ProjectsGroupByMode.city => translate('projects_dashboard.group_by_city'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ProjectsDashboardTheme.screenGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProjectsGlassChromeHeader(
              title: translate('projects_dashboard.my_projects_title'),
              showBack: true,
              scrimTopOpacity: 0.07,
              transparentGlassBar: true,
              titleTrailing: ProjectsGlassChromeHeader.homeTrailing(
                onPressed: _goHome,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 8.th),
              child: _GroupByBadgeRow(
                selected: _mode,
                onSelected: _selectMode,
                filtersActive: _filters.hasActiveFilters,
                onFilterTap: _openSmartFilters,
                onFilterClear: _filters.hasActiveFilters ? _clearFilters : null,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 10.th),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.white,
                ),
                decoration: InputDecoration(
                  hintText: translate('projects_dashboard.search_name_hint'),
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    color:
                        ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.85),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
                    size: 22.tsp,
                  ),
                  filled: true,
                  fillColor: ProjectsDashboardTheme.white.withValues(alpha: 0.12),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.tw,
                    vertical: 10.th,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.tr),
                    borderSide: BorderSide(
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.28),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.tr),
                    borderSide: BorderSide(
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.28),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.tr),
                    borderSide: BorderSide(
                      color: ProjectsDashboardTheme.maroonLight.withValues(
                        alpha: 0.75,
                      ),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            if (_filters.hasActiveFilters)
              Padding(
                padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 6.th),
                child: Text(
                  translate('projects_dashboard.filters_affect_projects_hint'),
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    color: ProjectsDashboardTheme.greyPanel,
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.tw),
                      itemCount: 8,
                      separatorBuilder: (_, __) => SizedBox(height: 10.th),
                      itemBuilder: (_, __) => const ProjectsProjectRowShimmer(),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.tw),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: ProjectsDashboardTheme.white,
                                    fontSize: 13.tsp,
                                  ),
                                ),
                                SizedBox(height: 16.th),
                                TextButton.icon(
                                  onPressed: () => _load(forceRefresh: true),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                  label: Text(
                                    translate('projects_dashboard.retry'),
                                    style: GoogleFonts.poppins(
                                      color: ProjectsDashboardTheme.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                translate('projects_dashboard.no_group_items'),
                                style: GoogleFonts.poppins(
                                  color: ProjectsDashboardTheme.greyPanel,
                                  fontSize: 13.tsp,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                16.tw,
                                0,
                                16.tw,
                                24.th,
                              ),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 10.th),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _GroupListTile(
                                  item: item,
                                  subtitle: _titleForMode(_mode),
                                  onTap: () => widget.onItemTap(item, _mode, _filters),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupByBadgeRow extends StatelessWidget {
  const _GroupByBadgeRow({
    required this.selected,
    required this.onSelected,
    required this.filtersActive,
    required this.onFilterTap,
    this.onFilterClear,
  });

  final ProjectsGroupByMode selected;
  final ValueChanged<ProjectsGroupByMode> onSelected;
  final bool filtersActive;
  final VoidCallback onFilterTap;
  final VoidCallback? onFilterClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _GroupBadge(
                  label: translate('projects_dashboard.group_by_pm'),
                  icon: Icons.badge_rounded,
                  selected: selected == ProjectsGroupByMode.projectManager,
                  onTap: () => onSelected(ProjectsGroupByMode.projectManager),
                ),
                SizedBox(width: 8.tw),
                _GroupBadge(
                  label: translate('projects_dashboard.group_by_client'),
                  icon: Icons.business_rounded,
                  selected: selected == ProjectsGroupByMode.client,
                  onTap: () => onSelected(ProjectsGroupByMode.client),
                ),
                SizedBox(width: 8.tw),
                _GroupBadge(
                  label: translate('projects_dashboard.group_by_city'),
                  icon: Icons.location_city_rounded,
                  selected: selected == ProjectsGroupByMode.city,
                  onTap: () => onSelected(ProjectsGroupByMode.city),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.tw),
        ProjectsHubFilterButton(
          active: filtersActive,
          onTap: onFilterTap,
          onClear: onFilterClear,
        ),
      ],
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.tr),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected
                ? ProjectsDashboardTheme.maroonAccentGradient
                : LinearGradient(
                    colors: [
                      ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.25),
                      ProjectsDashboardTheme.navy.withValues(alpha: 0.35),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20.tr),
            border: Border.all(
              color: selected
                  ? ProjectsDashboardTheme.white.withValues(alpha: 0.55)
                  : ProjectsDashboardTheme.white.withValues(alpha: 0.22),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.tsp, color: ProjectsDashboardTheme.white),
              SizedBox(width: 6.tw),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w600,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupListTile extends StatelessWidget {
  const _GroupListTile({
    required this.item,
    required this.subtitle,
    required this.onTap,
  });

  final ProjectManagerFilterItem item;
  final String subtitle;
  final VoidCallback onTap;

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return translate('projects_dashboard.last_update_recent');
    }
    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) {
      return translate('projects_dashboard.last_update_recent');
    }
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          padding: EdgeInsets.all(12.tw),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 16),
          child: Row(
            children: [
              _PickerAvatar(name: item.name, photoUrl: item.photoUrl),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15.tsp,
                        fontWeight: FontWeight.w700,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                    SizedBox(height: 2.th),
                    Text(
                      '$subtitle · ${_lastUpdateText(item.lastUpdate)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: ProjectsDashboardTheme.greyPanel,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
                decoration: BoxDecoration(
                  gradient: ProjectsDashboardTheme.maroonAccentGradient,
                  borderRadius: BorderRadius.circular(12.tr),
                  border: Border.all(
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${item.projectCount}',
                  style: GoogleFonts.koulen(
                    fontSize: 16.tsp,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerAvatar extends StatelessWidget {
  const _PickerAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: ProjectsCachedImage(
          url: photoUrl!,
          width: 52.tw,
          height: 52.tw,
          fit: BoxFit.cover,
        ),
      );
    }

    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 26.tr,
      backgroundColor: ProjectsDashboardTheme.navy.withValues(alpha: 0.85),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: ProjectsDashboardTheme.white,
        ),
      ),
    );
  }
}
