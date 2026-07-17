import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/projects_dashboard_summary_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_projects_response.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/projects_portfolio_map_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents_hub_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/agreements_panel_controller.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_agreements_expandable_panel.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/client_in_progress_grouper.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/client_in_progress_bar_chart.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_metallic_kpi_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_assistant_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_group_hub_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_status_filter_section.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_section_frame.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_toolbar_icons_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_view_switch_row.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ShaderCallback? shaderCallback;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.shaderCallback,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollNeeded();
    });
  }

  void _checkIfScrollNeeded() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _needsScrolling = true;
      });
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    while (mounted && _needsScrolling) {
      // Scroll to end slowly
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(
            milliseconds: (widget.text.length * 120).clamp(4000, 15000)),
        curve: Curves.linear,
      );

      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;

      // Jump back to start instantly (no animation)
      _scrollController.jumpTo(0);

      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      widget.text,
      style: widget.style,
      textAlign: widget.textAlign,
    );

    final scrollableText = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: textWidget,
    );

    if (widget.shaderCallback != null) {
      return ShaderMask(
        shaderCallback: widget.shaderCallback!,
        child: scrollableText,
      );
    }

    return scrollableText;
  }
}

class MyProject extends StatefulWidget {
  const MyProject({super.key});

  @override
  State<MyProject> createState() => _MyProjectState();
}

class _MyProjectState extends State<MyProject> {
  final AgreementsPanelController _agreementsPanelController =
      AgreementsPanelController();
  bool _agreementsBackdropVisible = false;

  bool _isLoading = false;
  bool _chartLoading = false;
  bool _showContent = false;
  String? _error;
  List<UserProjectModel> _projects = [];
  List<ProjectEntity> _inProgressProjects = [];
  ProjectsDashboardSummaryModel? _dashboardSummary;
  ProjectsViewMode _viewMode = ProjectsViewMode.dashboard;
  int? _selectedYear;

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  Future<void> _openGroupByHub() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (hubContext) => ProjectsGroupHubScreen(
          initialMode: ProjectsGroupByMode.projectManager,
          onHome: () => Navigator.of(hubContext).pop(),
          onItemTap: (item, mode, hubFilters) {
            final listContext = switch (mode) {
              ProjectsGroupByMode.projectManager =>
                ProjectsListContext.projectManager,
              ProjectsGroupByMode.client => ProjectsListContext.client,
              ProjectsGroupByMode.city => ProjectsListContext.city,
            };
            final projectManagerId = mode == ProjectsGroupByMode.projectManager &&
                    item.id > 0
                ? item.id
                : null;
            final partnerId = mode == ProjectsGroupByMode.client && item.id > 0
                ? item.id
                : null;
            final cityId =
                mode == ProjectsGroupByMode.city && item.id > 0 ? item.id : null;
            final bucketName = item.id <= 0 ? item.name : null;
            _openGroupedProjectList(
              projectManagerId: projectManagerId,
              partnerId: partnerId,
              cityId: cityId,
              title: item.name,
              photoUrl: item.photoUrl,
              listContext: listContext,
              hubFilters: hubFilters,
              bucketName: bucketName,
            );
          },
        ),
      ),
    );
  }

  void _openProjectDocumentsHub() {
    ProjectDocumentsHubScreen.open(
      context,
      fromPortfolioHub: true,
    );
  }

  void _openAiAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProjectsAiAssistantScreen(),
      ),
    );
  }

  void _openGroupedProjectList({
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    required String title,
    String? photoUrl,
    required ProjectsListContext listContext,
    ProjectsGroupHubFilters? hubFilters,
    String? bucketName,
    String? initialKeyword,
  }) {
    final bloc = _buildProjectsBloc();
    final dashboardContext = context;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (listRouteContext) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            partnerId: partnerId,
            projectManagerId: projectManagerId,
            cityId: cityId,
            partnerName: title,
            partnerPhoto: photoUrl ?? '',
            listContext: listContext,
            hubFilters: hubFilters,
            bucketName: bucketName,
            initialKeyword: initialKeyword,
            onHome: () {
              Navigator.of(listRouteContext).pop();
              Navigator.of(dashboardContext).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openPortfolioMapScreen() async {
    if (!mounted) return;
    setState(() => _viewMode = ProjectsViewMode.maps);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const ProjectsPortfolioMapScreen(),
      ),
    );
    if (mounted) {
      setState(() => _viewMode = ProjectsViewMode.dashboard);
    }
  }

  Map<String, dynamic>? get _widgetRecordMap {
    final data = SharedPref.getLoginData().result?.data?.defaultWidgets?.data;
    return data?.myProjectsWidget?.recordMap;
  }

  /// Agreements from `clients/list` — domain is applied server-side from the
  /// auth token (v2 portfolio: management sees all; staff sees project access).
  List<UserProjectModel> get _domainAgreements => _projects;

  ProjectsDashboardBoxStats get _boxStats =>
      ProjectsDashboardAggregator.resolveBoxStats(
        agreements: _domainAgreements,
        domainProjects: _inProgressProjects,
        summary: _dashboardSummary,
        widgetRecordMap: _widgetRecordMap,
      );

  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final p in _inProgressProjects) {
      final y = _projectYear(p);
      if (y != null) years.add(y);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  int? _projectYear(ProjectEntity p) {
    for (final raw in [p.dateStart, p.date]) {
      if (raw.isEmpty) continue;
      final d = DateTime.tryParse(raw);
      if (d != null) return d.year;
    }
    return null;
  }

  List<ProjectEntity> get _projectsForSelectedYear {
    if (_selectedYear == null) return _inProgressProjects;
    return _inProgressProjects.where((p) {
      final y = _projectYear(p);
      return y == null || y == _selectedYear;
    }).toList();
  }

  List<ClientInProgressBarData> get _clientBars =>
      ClientInProgressGrouper.group(
        _projectsForSelectedYear,
        agreements: _domainAgreements,
      );

  ProjectsDashboardStripStats? get _statusStats =>
      ProjectsDashboardAggregator.resolveStripStats(
        domainProjects: _inProgressProjects,
        summary: _dashboardSummary,
      );

  /// Hide status section when user has no domain agreement/project access.
  bool get _showProjectStatusSection =>
      _isLoading ||
      _chartLoading ||
      (ProjectsDashboardAccess.bypassesDomainScope
          ? _inProgressProjects.isNotEmpty
          : _domainAgreements.isNotEmpty);

  void _openStatusFilter(ProjectsStatusFilterKind kind) {
    if (kind == ProjectsStatusFilterKind.invoiced) return;

    final labels = ProjectsStatusFilterLabels(
      inProgress: translate('projects_dashboard.in_progress'),
      completed: translate('projects_dashboard.completed'),
    );

    final title = switch (kind) {
      ProjectsStatusFilterKind.inProgress => labels.inProgress,
      ProjectsStatusFilterKind.completed => labels.completed,
      ProjectsStatusFilterKind.invoiced => labels.completed,
    };

    final statusCompute = switch (kind) {
      ProjectsStatusFilterKind.inProgress => 'in_progress',
      ProjectsStatusFilterKind.completed => 'completed',
      ProjectsStatusFilterKind.invoiced => 'completed',
    };

    final bloc = _buildProjectsBloc();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            partnerName: title,
            listContext: ProjectsListContext.general,
            hubFilters: ProjectsGroupHubFilters(
              projectStatusCompute: statusCompute,
            ),
          ),
        ),
      ),
    );
  }

  void _openAgreement(UserProjectModel project) {
    final bloc = _buildProjectsBloc();
    final agreementId = project.agreementId ?? project.projectId;
    final name = (project.agreementName?.trim().isNotEmpty == true)
        ? project.agreementName!.trim()
        : project.projectName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            agreementId: agreementId,
            partnerName: name,
            partnerPhoto: project.photoUrl ?? '',
            agreementNo: project.agreementNo,
            listContext: ProjectsListContext.agreement,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _chartLoading = true;
      _showContent = false;
      _error = null;
    });

    final ds = ProjectRemoteDataSource();

    try {
      final clientsFuture = ds.fetchClientsList();
      final summaryFuture = ds.fetchProjectsDashboardSummary();

      final UserProjectsResponse response = await clientsFuture;
      ProjectsDashboardSummaryModel? summary;
      try {
        summary = await summaryFuture;
      } catch (_) {
        summary = null;
      }

      if (!mounted) return;
      setState(() {
        _projects = response.projects;
        _dashboardSummary = summary;
        _isLoading = false;
      });

      if (!mounted) return;
      setState(() => _showContent = true);

      // Defer chart fetch so group-by / list screens are not competing for connections.
      unawaited(_loadChartProjects(ds));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _chartLoading = false;
      });
    }
  }

  Future<void> _loadChartProjects(ProjectRemoteDataSource ds) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    try {
      final isManagement = ProjectsDashboardAccess.bypassesDomainScope;
      final maxItems = isManagement
          ? kProjectsDashboardManagementMaxProjects
          : kProjectsDashboardMaxProjects;
      final projects = await ds.fetchDashboardChartProjects(
        maxItems: maxItems,
        projectStatusCompute: 'in_progress',
      );
      if (!mounted) return;
      final visible = projects.where((p) => !p.isGeneralWo).toList();
      setState(() {
        if (ProjectsDashboardAccess.shouldApplyDomainScope &&
            !ds.projectsHubV2Available) {
          _inProgressProjects =
              ProjectsDashboardAggregator.filterProjectsForAccessibleAgreements(
            projects: visible,
            agreements: _domainAgreements,
          );
        } else {
          _inProgressProjects = visible;
        }
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inProgressProjects = [];
        _chartLoading = false;
      });
    }
  }

  Widget _buildDashboardBody() {
    final agreementsCount = _domainAgreements.length;
    final panelCollapsedH = ProjectsAgreementsExpandablePanel.collapsedHeight(
      context,
      hasAgreements: agreementsCount > 0 || _isLoading,
      agreementCount: agreementsCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProjectsGlassChromeHeader(
          transparentGlassBar: true,
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  color: ProjectsDashboardTheme.maroon,
                  backgroundColor: ProjectsDashboardTheme.greyPanel,
                  onRefresh: _loadDashboard,
                  child: ListView(
                    physics: _agreementsBackdropVisible
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                    // Keep content clear of the pinned agreements panel.
                    padding: EdgeInsets.only(bottom: panelCollapsedH + 8.th),
                    children: [
                      AnimatedOpacity(
                        opacity: _showContent ? 1 : 0.88,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProjectsSectionFrame(
                              child: ProjectsToolbarIconsRow(
                                viewMode: _viewMode,
                                onDashboardTap: () => setState(
                                  () =>
                                      _viewMode = ProjectsViewMode.dashboard,
                                ),
                                onMapsTap: _openPortfolioMapScreen,
                                onGroupByTap: _openGroupByHub,
                                onDocumentsTap: _openProjectDocumentsHub,
                                onAiTap: _openAiAssistant,
                              ),
                            ),
                            SizedBox(height: 10.th),
                            ProjectsMetallicKpiRow(
                              stats: _boxStats,
                              isLoading: _isLoading,
                              agreementsLabel: translate(
                                'projects_dashboard.agreements',
                              ),
                              totalProjectsLabel: translate(
                                'projects_dashboard.total_projects',
                              ),
                            ),
                            ClientInProgressBarChart(
                              clients: _clientBars,
                              isLoading: _chartLoading || _isLoading,
                              title: translate(
                                'projects_dashboard.client_engagement',
                              ),
                              yearPickerTitle: translate(
                                'projects_dashboard.select_year',
                              ),
                              yearAllLabel: translate(
                                'projects_dashboard.filter_all',
                              ),
                              selectedYear: _selectedYear,
                              availableYears: _availableYears,
                              onYearChanged: (y) =>
                                  setState(() => _selectedYear = y),
                            ),
                            if (_showProjectStatusSection)
                              ProjectsStatusFilterSection(
                                stats: _statusStats,
                                isLoading: _chartLoading || _isLoading,
                                labels: ProjectsStatusFilterLabels(
                                  inProgress: translate(
                                    'projects_dashboard.in_progress',
                                  ),
                                  completed: translate(
                                    'projects_dashboard.completed',
                                  ),
                                ),
                                onFilterTap: _openStatusFilter,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_agreementsBackdropVisible,
                  child: AnimatedOpacity(
                    opacity: _agreementsBackdropVisible ? 1 : 0,
                    duration: DeviceUiCapability.adaptiveDuration(
                      const Duration(milliseconds: 220),
                    ),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: _agreementsPanelController.collapse,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              ),
              // Pinned to bottom (outside scroll) so header drag / arrow toggle work.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ProjectsAgreementsExpandablePanel(
                  agreements: _domainAgreements,
                  controller: _agreementsPanelController,
                  onAgreementTap: _openAgreement,
                  title: translate('projects_dashboard.agreements_section'),
                  emptyMessage: translate('projects_dashboard.no_agreements'),
                  isLoading: _isLoading,
                  onExpansionChanged: (expanded) {
                    if (expanded != _agreementsBackdropVisible) {
                      setState(() => _agreementsBackdropVisible = expanded);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: ProjectsDashboardTheme.screenGradient,
        ),
        child: _error != null && !_isLoading
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.tw),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              color: ProjectsDashboardTheme.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16.th),
                          TextButton(
                            onPressed: _loadDashboard,
                            child: Text(
                              translate('projects_dashboard.retry'),
                              style: GoogleFonts.poppins(
                                color: ProjectsDashboardTheme.greyPanel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildDashboardBody(),
      ),
    );
  }
}

//
// ------------- CARD — EXACT MATCH TO REFERENCE ----------------
//

Widget buildProjectCard({
  required String id,
  required String name,
  required String photoUrl,
  required int projectsCount,
  required double amountAed,
  String location = '',
  String cityId = '',
}) {
  String? normalizedPhotoUrl = photoUrl.trim();
  if (normalizedPhotoUrl.isEmpty) normalizedPhotoUrl = null;
  if (normalizedPhotoUrl != null &&
      normalizedPhotoUrl.contains('erp.elrace.compublic')) {
    normalizedPhotoUrl = normalizedPhotoUrl.replaceAll(
        'erp.elrace.compublic', 'erp.elrace.com/public');
  }

  final formattedAmount = NumberFormat('#,##0.##', 'en').format(amountAed);
  const cardDataGray = Color(0xB8484848);

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 7.th),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22.tr),
      border: Border.all(color: const Color(0xFF2C2F36), width: 1),
      gradient: const LinearGradient(
        colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22.tr),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/newapp/for_attachments.png',
                  width: 150.tw,
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.tw, 14.th, 18.tw, 12.th),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18.th,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          DateFormat('MM/dd/yyyy').format(DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 10.tsp,
                            fontWeight: FontWeight.w600,
                            color: cardDataGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.th),
                Text(
                  id.isNotEmpty ? id : '-',
                  style: GoogleFonts.inter(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10.th),
                Text(
                  name.trim().isNotEmpty ? name.trim() : '-',
                  style: GoogleFonts.inter(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 14.th),
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: 'Work Order# '),
                            TextSpan(
                              text: '$projectsCount',
                              style: GoogleFonts.inter(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w600,
                                color: cardDataGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10.tw),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12.tsp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(text: 'Amount# '),
                              TextSpan(
                                text: formattedAmount,
                                style: GoogleFonts.inter(
                                  fontSize: 12.tsp,
                                  fontWeight: FontWeight.w600,
                                  color: cardDataGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.th),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16.tw, color: red),
                    SizedBox(width: 4.tw),
                    Flexible(
                      child: Text(
                        cityId.trim().isNotEmpty
                            ? cityId.trim()
                            : location.trim().isNotEmpty
                                ? location.trim()
                                : '-',
                        style: GoogleFonts.inter(
                          fontSize: 11.5.tsp,
                          fontWeight: FontWeight.w700,
                          color: cardDataGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 10.tw,
            top: 10.th,
            child: Container(
              width: 34.tw,
              height: 34.tw,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: normalizedPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        normalizedPhotoUrl,
                        fit: BoxFit.contain,
                        headers: {
                          'Accept': 'image/*',
                          'Authorization':
                              'Bearer ${SharedPref.getLoginData().result?.token ?? ''}',
                        },
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business,
                          size: 18.tw,
                          color: appFontColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.business,
                      size: 18.tw,
                      color: appFontColor,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProjectManagersScreen extends StatefulWidget {
  const _ProjectManagersScreen();

  @override
  State<_ProjectManagersScreen> createState() => _ProjectManagersScreenState();
}

class _ProjectManagersScreenState extends State<_ProjectManagersScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _managers = const [];

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource().fetchProjectManagersList();
      if (!mounted) return;
      setState(() {
        _managers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openManagerProjects(ProjectManagerFilterItem manager) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            projectManagerId: manager.id,
            partnerName: manager.name,
            partnerPhoto: manager.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProjectsGlassShell(
        title: 'Project Manager',
        backgroundColor: const Color(0xFFF2F2F2),
        onLightSurface: true,
        body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.tsp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.tw,
                          right: 14.tw,
                          top: 6.th,
                          bottom: 20.th,
                        ),
                        itemCount: _managers.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.tw,
                          endIndent: 10.tw,
                        ),
                        itemBuilder: (context, index) {
                          final manager = _managers[index];
                          final avatarUrl = manager.photoUrl;

                          return InkWell(
                            onTap: () => _openManagerProjects(manager),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.tw,
                                vertical: 10.th,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27.tr,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 25.tr,
                                      backgroundColor: const Color(0xFFE8E8E8),
                                      backgroundImage: avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? Text(
                                              manager.name.isEmpty
                                                  ? 'M'
                                                  : manager.name[0]
                                                      .toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 18.tsp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF5C5C5C),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 12.tw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.tsp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.th),
                                        Text(
                                          _lastUpdateText(manager.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.tsp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.tw,
                                    height: 54.th,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.tr),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      manager.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.tsp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _ClientsScreen extends StatefulWidget {
  const _ClientsScreen();

  @override
  State<_ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<_ClientsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _clients = const [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource()
          .fetchClientsGroupedList(groupBy: 'client');
      if (!mounted) return;
      setState(() {
        _clients = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openClientProjects(ProjectManagerFilterItem client) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            partnerId: client.id,
            partnerName: client.name,
            partnerPhoto: client.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProjectsGlassShell(
        title: 'Client',
        backgroundColor: const Color(0xFFF2F2F2),
        onLightSurface: true,
        body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.tsp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.tw,
                          right: 14.tw,
                          top: 6.th,
                          bottom: 20.th,
                        ),
                        itemCount: _clients.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.tw,
                          endIndent: 10.tw,
                        ),
                        itemBuilder: (context, index) {
                          final client = _clients[index];
                          final avatarUrl = client.photoUrl;

                          return InkWell(
                            onTap: () => _openClientProjects(client),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.tw,
                                vertical: 10.th,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27.tr,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 25.tr,
                                      backgroundColor: const Color(0xFFE8E8E8),
                                      backgroundImage: avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? Text(
                                              client.name.isEmpty
                                                  ? 'C'
                                                  : client.name[0]
                                                      .toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 18.tsp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF5C5C5C),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 12.tw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.tsp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.th),
                                        Text(
                                          _lastUpdateText(client.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.tsp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.tw,
                                    height: 54.th,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.tr),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      client.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.tsp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _CitiesScreen extends StatefulWidget {
  const _CitiesScreen();

  @override
  State<_CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<_CitiesScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _cities = const [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource()
          .fetchClientsGroupedList(groupBy: 'city');
      if (!mounted) return;
      setState(() {
        _cities = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }

    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  ProjectListBloc _buildProjectsBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  void _openCityProjects(ProjectManagerFilterItem city) {
    final bloc = _buildProjectsBloc();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            cityId: city.id,
            partnerName: city.name,
            partnerPhoto: city.photoUrl ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProjectsGlassShell(
        title: 'City',
        backgroundColor: const Color(0xFFF2F2F2),
        onLightSurface: true,
        body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFBA1719),
                            fontSize: 12.tsp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 14.tw,
                          right: 14.tw,
                          top: 6.th,
                          bottom: 20.th,
                        ),
                        itemCount: _cities.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: const Color(0xFFD5D5D5),
                          thickness: 1,
                          indent: 10.tw,
                          endIndent: 10.tw,
                        ),
                        itemBuilder: (context, index) {
                          final city = _cities[index];

                          return InkWell(
                            onTap: () => _openCityProjects(city),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.tw,
                                vertical: 10.th,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: const Color(0xFFD61518),
                                    size: 40.tsp,
                                  ),
                                  SizedBox(width: 8.tw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          city.name,
                                          maxLines: 5,
                                          style: GoogleFonts.poppins(
                                            fontSize: 21.tsp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3A3A3A),
                                          ),
                                        ),
                                        SizedBox(height: 2.th),
                                        Text(
                                          _lastUpdateText(city.lastUpdate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15.tsp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFA2A2A2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50.tw,
                                    height: 54.th,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.tr),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3C4C80),
                                          Color(0xFF202F5C),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      city.projectCount.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20.tsp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
