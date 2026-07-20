import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_layout.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_section_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsFolderProjectsView extends StatelessWidget {
  const ProjectDocumentsFolderProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectDocumentsCubit, ProjectDocumentsState>(
      builder: (context, state) => _ProjectList(state: state),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.state});

  final ProjectDocumentsState state;

  @override
  Widget build(BuildContext context) {
    if (state.error != null &&
        state.folderProjects.isEmpty &&
        !state.showTabLoadingOverlay) {
      return Center(
        child: Text(
          state.error!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.white,
          ),
        ),
      );
    }
    if (state.folderProjects.isEmpty && !state.showTabLoadingOverlay) {
      return Center(
        child: Text(
          'No projects with ${state.selectedKind.title} documents',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.greyPanel,
          ),
        ),
      );
    }
    if (state.folderProjects.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCloud = state.selectedKind == ProjectDocumentHubKind.cloud;

    return RefreshIndicator(
      color: ProjectsDashboardTheme.maroon,
      onRefresh: () =>
          context.read<ProjectDocumentsCubit>().loadFolderProjects(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 120 &&
              state.folderHasMore &&
              !state.folderLoading) {
            context.read<ProjectDocumentsCubit>().loadFolderProjects();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: ProjectDocumentsLayout.listPadding(context),
          itemCount: state.folderProjects.length + (state.folderLoading ? 1 : 0),
          separatorBuilder: (_, __) => SizedBox(height: 10.th),
          itemBuilder: (context, index) {
            if (index >= state.folderProjects.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              );
            }
            final project = state.folderProjects[index];
            final trail = projectDocumentsTrailForProject(
              kind: state.selectedKind,
              projectName: project.name,
            );
            return ProjectDocumentsSectionTile(
              title: project.name,
              kind: state.selectedKind,
              fileCount: project.fileCount,
              iconSize: 50,
              variant: ProjectDocumentsTileVariant.sub,
              subtitle: project.woRefNo.isNotEmpty ? project.woRefNo : null,
              fileCountLabel: isCloud && project.fileCount == 0
                  ? 'SharePoint site'
                  : null,
              lastUpdatedLabel: formatDocumentDateLabel(project.lastUpdated),
              updatedBy: project.updatedBy,
              showMeta: true,
              onTap: () {
                pushProjectDocumentsProjectFiles(
                  context,
                  projectId: project.projectId,
                  projectName: project.name,
                  kind: state.selectedKind,
                  breadcrumbs: trail,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
