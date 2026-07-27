import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_layout.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsFilesView extends StatelessWidget {
  const ProjectDocumentsFilesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectDocumentsCubit, ProjectDocumentsState>(
      builder: (context, state) {
        if (state.error != null && state.files.isEmpty && !state.showTabLoadingOverlay) {
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
        if (state.files.isEmpty && !state.showTabLoadingOverlay) {
          return Center(
            child: Text(
              'No files found',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: ProjectsDashboardTheme.greyPanel,
              ),
            ),
          );
        }
        if (state.files.isEmpty) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          color: ProjectsDashboardTheme.maroon,
          onRefresh: () =>
              context.read<ProjectDocumentsCubit>().loadFiles(reset: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 120 &&
                  state.filesHasMore &&
                  !state.filesLoading) {
                context.read<ProjectDocumentsCubit>().loadFiles();
              }
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: ProjectDocumentsLayout.listPadding(context),
              itemCount: state.files.length + (state.filesLoading ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 12.th),
              itemBuilder: (context, index) {
                if (index >= state.files.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  );
                }
                final file = state.files[index];
                return ProjectDocumentsFileRow(
                  fileName: file.name,
                  subtitle: file.projectName.isNotEmpty ? file.projectName : null,
                  updatedLabel: file.updatedAt != null
                      ? 'Updated ${formatDocumentDateLabel(file.updatedAt)}'
                      : null,
                  kind: file.kind,
                  onTap: () => _onTap(context, file),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context, ProjectDocumentFileItem file) async {
    if (file.isCloud && file.url.isEmpty) {
      pushProjectDocumentsProjectFiles(
        context,
        projectId: file.projectId,
        projectName: file.projectName,
        kind: ProjectDocumentHubKind.cloud,
      );
      return;
    }
    if (file.url.isEmpty) return;
    await openProjectFileInApp(
      context,
      rawUrl: file.url,
      fileName: file.name,
      attachmentId: parseProjectAttachmentId(file.id),
    );
  }
}
