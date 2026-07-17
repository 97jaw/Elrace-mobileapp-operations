import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:math' as math;

import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/agreement_list_card.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/agreements_panel_controller.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const int _kAgreementsPageSize = 10;

/// Approximate rendered height of one [AgreementListCard] (incl. margins).
double _agreementCardExtent(BuildContext context) => 132.th;

/// How much of the next card peeks in the collapsed panel.
double _agreementPeekExtent(BuildContext context) => 56.th;

/// Bottom agreements panel — collapsed shows one card + peek; drag header / tap arrow to expand.
class ProjectsAgreementsExpandablePanel extends StatefulWidget {
  const ProjectsAgreementsExpandablePanel({
    super.key,
    required this.agreements,
    required this.onAgreementTap,
    required this.title,
    required this.emptyMessage,
    required this.onExpansionChanged,
    this.controller,
    this.isLoading = false,
  });

  final List<UserProjectModel> agreements;
  final ValueChanged<UserProjectModel> onAgreementTap;
  final String title;
  final String emptyMessage;
  final ValueChanged<bool> onExpansionChanged;
  final AgreementsPanelController? controller;
  final bool isLoading;

  /// Collapsed panel height (header + first card + peek of next when available).
  static double collapsedHeight(
    BuildContext context, {
    required bool hasAgreements,
    int agreementCount = 0,
  }) {
    final headerH = 48.th;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (!hasAgreements) {
      return headerH + bottom + 6.th;
    }
    final cardH = _agreementCardExtent(context);
    final peek = agreementCount > 1 ? _agreementPeekExtent(context) : 0.0;
    return headerH + cardH + peek + bottom + 4.th;
  }

  /// Max panel height when expanded (fills area below greeting header).
  static double expandedHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size.height;
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;
    return (screen - top - bottom - 76.th).clamp(320.0, screen * 0.92);
  }

  @override
  State<ProjectsAgreementsExpandablePanel> createState() =>
      _ProjectsAgreementsExpandablePanelState();
}

class _ProjectsAgreementsExpandablePanelState
    extends State<ProjectsAgreementsExpandablePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _visibleCount = _kAgreementsPageSize;
  bool _lastReportedExpanded = false;

  Duration get _duration => DeviceUiCapability.adaptiveDuration(
        const Duration(milliseconds: 320),
      );

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: _duration,
    );
    _expandController.addListener(_onExpandTick);
    _listController.addListener(_onListScroll);
    _searchController.addListener(_onSearchChanged);
    widget.controller?.bind(collapse);
  }

  void _onSearchChanged() {
    if (!_isExpanded) return;
    setState(() => _visibleCount = _kAgreementsPageSize);
  }

  List<UserProjectModel> get _filteredAgreements {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.agreements;

    return widget.agreements.where((a) {
      final name = a.projectName.toLowerCase();
      final agreementName = (a.agreementName ?? '').toLowerCase();
      final agreementNo = (a.agreementNo ?? '').toLowerCase();
      return name.contains(q) ||
          agreementName.contains(q) ||
          agreementNo.contains(q);
    }).toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant ProjectsAgreementsExpandablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      widget.controller?.bind(collapse);
    }
    if (oldWidget.agreements.length != widget.agreements.length) {
      _visibleCount = _kAgreementsPageSize;
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _expandController.removeListener(_onExpandTick);
    _expandController.dispose();
    _listController.removeListener(_onListScroll);
    _listController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onExpandTick() {
    final expanded = _expandController.value > 0.5;
    if (expanded != _lastReportedExpanded) {
      _lastReportedExpanded = expanded;
      widget.onExpansionChanged(expanded);
    }
    if (!expanded && _visibleCount > _kAgreementsPageSize) {
      _visibleCount = _kAgreementsPageSize;
    }
    setState(() {});
  }

  void _onListScroll() {
    if (_expandController.value < 0.5) return;
    if (!_listController.hasClients) return;
    final pos = _listController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  bool get _isExpanded => _expandController.value > 0.5;

  void _expand() {
    _expandController.animateTo(
      1,
      duration: _duration,
      curve: Curves.easeOutCubic,
    );
  }

  void collapse() {
    _expandController.animateTo(
      0,
      duration: _duration,
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() {
    if (_isExpanded) {
      collapse();
    } else {
      _expand();
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final collapsed = ProjectsAgreementsExpandablePanel.collapsedHeight(
      context,
      hasAgreements: widget.agreements.isNotEmpty,
      agreementCount: widget.agreements.length,
    );
    final expanded = ProjectsAgreementsExpandablePanel.expandedHeight(context);
    final range = expanded - collapsed;
    if (range <= 0) return;
    // Only update the controller — do not setState / swap gesture trees mid-drag.
    _expandController.value =
        (_expandController.value - details.delta.dy / range).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final vy = details.velocity.pixelsPerSecond.dy;
    if (vy < -400) {
      _expand();
    } else if (vy > 400) {
      collapse();
    } else if (_expandController.value > 0.5) {
      _expand();
    } else {
      collapse();
    }
  }

  void _loadMore() {
    final total =
        _isExpanded ? _filteredAgreements.length : widget.agreements.length;
    if (_visibleCount >= total) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + _kAgreementsPageSize,
        total,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = ProjectsAgreementsExpandablePanel.collapsedHeight(
      context,
      hasAgreements: widget.agreements.isNotEmpty || widget.isLoading,
      agreementCount: widget.agreements.length,
    );
    final expanded = ProjectsAgreementsExpandablePanel.expandedHeight(context);

    final source = _isExpanded ? _filteredAgreements : widget.agreements;
    // Collapsed: first card + peek of next when available.
    final displayCount = _isExpanded
        ? math.min(_visibleCount, source.length)
        : math.min(2, widget.agreements.length);
    final hasMore = _isExpanded && displayCount < source.length;

    final height =
        collapsed + (expanded - collapsed) * _expandController.value;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.tr)),
        child: Material(
          color: ProjectsDashboardTheme.greyDeep.withValues(alpha: 0.96),
          elevation: DeviceUiCapability.isLowEnd ? 4 : 12,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag / toggle only on the header — stable gesture tree.
              GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                behavior: HitTestBehavior.opaque,
                child: _PanelHeader(
                  title: widget.title,
                  expanded: _isExpanded,
                  onToggle: _toggle,
                ),
              ),
              if (_isExpanded)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 8.th),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      color: ProjectsDashboardTheme.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search agreements…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        color: ProjectsDashboardTheme.greyPanel
                            .withValues(alpha: 0.85),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: ProjectsDashboardTheme.white
                            .withValues(alpha: 0.9),
                        size: 22.tsp,
                      ),
                      filled: true,
                      fillColor: ProjectsDashboardTheme.greyPanel
                          .withValues(alpha: 0.18),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.tw,
                        vertical: 10.th,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.tr),
                        borderSide: BorderSide(
                          color: ProjectsDashboardTheme.white
                              .withValues(alpha: 0.22),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.tr),
                        borderSide: BorderSide(
                          color: ProjectsDashboardTheme.white
                              .withValues(alpha: 0.22),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.tr),
                        borderSide: BorderSide(
                          color: ProjectsDashboardTheme.maroonLight
                              .withValues(alpha: 0.75),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: widget.isLoading
                    ? const ProjectsAgreementCardShimmer()
                    : widget.agreements.isEmpty
                        ? Center(
                            child: Text(
                              widget.emptyMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13.tsp,
                                color: ProjectsDashboardTheme.greyPanel
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        : _isExpanded && source.isEmpty
                            ? Center(
                                child: Text(
                                  'No agreements match your search',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.tsp,
                                    color: ProjectsDashboardTheme.greyPanel
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _listController,
                                physics: _isExpanded
                                    ? const ClampingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.only(
                                  bottom: _isExpanded ? 8.th : 0,
                                ),
                                itemCount: displayCount + (hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= displayCount) {
                                    return Center(
                                      child: TextButton(
                                        onPressed: _loadMore,
                                        child: Text(
                                          'Load more',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: ProjectsDashboardTheme
                                                .maroonLight,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final agreement = _isExpanded
                                      ? source[index]
                                      : widget.agreements[index];
                                  return AgreementListCard(
                                    agreement: agreement,
                                    onTap: () =>
                                        widget.onAgreementTap(agreement),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 10.th, 4.tw, 4.th),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16.tsp,
                fontWeight: FontWeight.w600,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20.tr),
              child: Padding(
                padding: EdgeInsets.all(8.tw),
                child: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: ProjectsDashboardTheme.white,
                  size: 26.tsp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
