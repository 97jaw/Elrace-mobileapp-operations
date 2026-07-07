import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_layout.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_uploader_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsUploadedByView extends StatelessWidget {
  const ProjectDocumentsUploadedByView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectDocumentsCubit, ProjectDocumentsState>(
      builder: (context, state) {
        if (state.error != null && state.uploaders.isEmpty && !state.showTabLoadingOverlay) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                state.error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
            ),
          );
        }
        if (state.uploaders.isEmpty && !state.showTabLoadingOverlay) {
          return Center(
            child: Text(
              'No upload activity found',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: ProjectsDashboardTheme.greyPanel,
              ),
            ),
          );
        }
        if (state.uploaders.isEmpty) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          color: ProjectsDashboardTheme.maroon,
          onRefresh: () =>
              context.read<ProjectDocumentsCubit>().loadUploaders(reset: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 120 &&
                  state.uploadersHasMore &&
                  !state.uploadersLoading) {
                context.read<ProjectDocumentsCubit>().loadUploaders();
              }
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: ProjectDocumentsLayout.listPadding(context),
              itemCount: state.uploaders.length + (state.uploadersLoading ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                if (index >= state.uploaders.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  );
                }
                final uploader = state.uploaders[index];
                return ProjectDocumentsUploaderCard(
                  uploader: uploader,
                  onTap: () => pushUploaderProjects(
                    context,
                    uploader: uploader,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
