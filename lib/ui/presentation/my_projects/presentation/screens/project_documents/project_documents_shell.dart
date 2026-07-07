import 'package:flutter_translate/flutter_translate.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_dashboard_view.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_files_view.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_folder_projects_view.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_uploaded_by_view.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_coming_soon.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_drill_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_search_bar.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_documents_glass_bottom_bar.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProjectDocumentsShell extends StatefulWidget {
  const ProjectDocumentsShell({
    super.key,
    this.initialProjectId,
    this.initialProjectTitle,
    this.initialKind,
  });

  final int? initialProjectId;
  final String? initialProjectTitle;
  final ProjectDocumentHubKind? initialKind;

  static Future<void> open(
    BuildContext context, {
    int? initialProjectId,
    String? initialProjectTitle,
    ProjectDocumentHubKind? initialKind,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDocumentsShell(
          initialProjectId: initialProjectId,
          initialProjectTitle: initialProjectTitle,
          initialKind: initialKind,
        ),
      ),
    );
  }

  @override
  State<ProjectDocumentsShell> createState() => _ProjectDocumentsShellState();
}

class _ProjectDocumentsShellState extends State<ProjectDocumentsShell> {
  late final ProjectDocumentsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ProjectDocumentsCubit(
      initialProjectId: widget.initialProjectId,
      initialProjectTitle: widget.initialProjectTitle,
      initialKind: widget.initialKind,
    )..initialize();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _title(ProjectDocumentsState state) {
    if (widget.initialProjectTitle != null &&
        widget.initialProjectTitle!.trim().isNotEmpty &&
        state.activeView == ProjectDocumentsView.folderProjects) {
      return widget.initialProjectTitle!.trim();
    }
    return switch (state.activeView) {
      ProjectDocumentsView.dashboard => 'Project Documents',
      ProjectDocumentsView.folderProjects => state.selectedKind.title,
      ProjectDocumentsView.files => 'All files',
      ProjectDocumentsView.uploadedBy => 'Uploaded by',
    };
  }

  String _searchHint(ProjectDocumentsState state) => switch (state.activeView) {
        ProjectDocumentsView.dashboard => 'Search projects…',
        ProjectDocumentsView.folderProjects => 'Search projects…',
        ProjectDocumentsView.files => 'Search files…',
        ProjectDocumentsView.uploadedBy => 'Search staff…',
      };

  ProjectDocumentHubKind? _headerKind(ProjectDocumentsState state) {
    if (state.activeView != ProjectDocumentsView.folderProjects) return null;
    if (widget.initialProjectTitle != null &&
        widget.initialProjectTitle!.trim().isNotEmpty) {
      return null;
    }
    return state.selectedKind;
  }

  void _onBottomBarTap(BuildContext context, int index) {
    if (index == 4) {
      showProjectsComingSoonSnackBar(
        context,
        featureLabel: translate('projects_dashboard.ai_assistant'),
      );
      return;
    }
    context.read<ProjectDocumentsCubit>().onBottomBarTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<ProjectDocumentsCubit, ProjectDocumentsState>(
        builder: (context, state) {
          return PopScope(
            canPop: state.activeView != ProjectDocumentsView.folderProjects,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              context.read<ProjectDocumentsCubit>().backToDashboard();
            },
            child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            bottomNavigationBar: ProjectsDocumentsGlassBottomBar(
              activeIndex: state.bottomBarIndex,
              onItemTap: (index) => _onBottomBarTap(context, index),
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: ProjectsDashboardTheme.screenGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProjectsGlassChromeHeader(
                    scrimTopOpacity: 0.07,
                    transparentGlassBar: true,
                  ),
                  ProjectDocumentsDrillHeader(
                    title: _title(state),
                    kind: _headerKind(state),
                    breadcrumbs: projectDocumentsTrailForShell(state),
                    onBack: () {
                      if (state.activeView == ProjectDocumentsView.folderProjects) {
                        context.read<ProjectDocumentsCubit>().backToDashboard();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  ProjectDocumentsSearchBar(
                    key: ValueKey('search-${state.activeView.name}'),
                    hint: _searchHint(state),
                    hasActiveFilters: state.hasDocumentScopeFilters,
                    initialFilters: state.hubFilters,
                    initialQuery: state.searchQuery,
                    onSearchChanged: (q) =>
                        context.read<ProjectDocumentsCubit>().setSearchQuery(q),
                    onFiltersApplied: (filters) => context
                        .read<ProjectDocumentsCubit>()
                        .setDocumentFilters(filters),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        IndexedStack(
                          index: state.stackIndex,
                          children: const [
                            ProjectDocumentsDashboardView(),
                            ProjectDocumentsFolderProjectsView(),
                            ProjectDocumentsFilesView(),
                            ProjectDocumentsUploadedByView(),
                          ],
                        ),
                        if (state.showTabLoadingOverlay)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.12),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: ProjectsDashboardTheme.white,
                                  strokeWidth: 2.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
