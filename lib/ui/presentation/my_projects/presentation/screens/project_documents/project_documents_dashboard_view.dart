import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_layout.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_document_folder_tile.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsDashboardView extends StatelessWidget {
  const ProjectDocumentsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectDocumentsCubit, ProjectDocumentsState>(
      builder: (context, state) {
        if (state.error != null && state.dashboard == null && !state.showTabLoadingOverlay) {
          return _ErrorBody(message: state.error!);
        }
        final dashboard = state.dashboard;
        if (dashboard == null) {
          if (state.dashboardLoading || state.showTabLoadingOverlay) {
            return const Center(
              child: CircularProgressIndicator(
                color: ProjectsDashboardTheme.white,
                strokeWidth: 2.6,
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final folders = dashboard.folders.map((f) => f.toHubFolderItem()).toList();

        return RefreshIndicator(
          color: ProjectsDashboardTheme.maroon,
          onRefresh: () => context.read<ProjectDocumentsCubit>().loadDashboard(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: ProjectDocumentsLayout.listPadding(context),
            children: [
              if (state.error != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    state.error!,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              Text(
                '${dashboard.totalProjectsInScope} projects in scope',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
              ),
              SizedBox(height: 8.h),
              for (var i = 0; i < folders.length; i++) ...[
                ProjectDocumentFolderTile(
                  item: folders[i],
                  onTap: () => context
                      .read<ProjectDocumentsCubit>()
                      .openFolderFromDashboard(folders[i].kind),
                ),
                SizedBox(height: 10.h),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 8.h),
                child: Text(
                  'Recent files',
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ),
              if (dashboard.recentFiles.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Center(
                    child: Text(
                      'No recent files',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: ProjectsDashboardTheme.greyPanel,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < dashboard.recentFiles.length; i++) ...[
                  ProjectDocumentsFileRow(
                    fileName: dashboard.recentFiles[i].name,
                    subtitle: dashboard.recentFiles[i].projectName.isNotEmpty
                        ? dashboard.recentFiles[i].projectName
                        : dashboard.recentFiles[i].kind.title,
                    updatedLabel: dashboard.recentFiles[i].updatedAt != null
                        ? 'Updated ${formatDocumentDateLabel(dashboard.recentFiles[i].updatedAt)}'
                        : null,
                    kind: dashboard.recentFiles[i].kind,
                    onTap: () => _openFile(context, dashboard.recentFiles[i]),
                  ),
                  SizedBox(height: 8.h),
                ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFile(BuildContext context, ProjectDocumentFileItem file) async {
    if (file.url.isEmpty) {
      if (file.isCloud && file.projectId > 0) {
        pushProjectDocumentsProjectFiles(
          context,
          projectId: file.projectId,
          projectName: file.projectName,
          kind: ProjectDocumentHubKind.cloud,
        );
      }
      return;
    }
    await openProjectFileInApp(
      context,
      rawUrl: file.url,
      fileName: file.name,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            color: ProjectsDashboardTheme.white,
          ),
        ),
      ),
    );
  }
}
