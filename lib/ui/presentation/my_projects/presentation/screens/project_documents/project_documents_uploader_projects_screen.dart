import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_documents_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_drill_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_section_tile.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Projects where [uploader] has uploaded documents.
class ProjectDocumentsUploaderProjectsScreen extends StatefulWidget {
  const ProjectDocumentsUploaderProjectsScreen({
    super.key,
    required this.uploader,
    this.breadcrumbs,
  });

  final ProjectDocumentsUploaderItem uploader;
  final List<ProjectDocumentsBreadcrumb>? breadcrumbs;

  @override
  State<ProjectDocumentsUploaderProjectsScreen> createState() =>
      _ProjectDocumentsUploaderProjectsScreenState();
}

class _ProjectDocumentsUploaderProjectsScreenState
    extends State<ProjectDocumentsUploaderProjectsScreen> {
  final _repo = ProjectDocumentsRepository(ProjectDocumentsRemoteDataSource());

  bool _loading = true;
  String? _error;
  List<ProjectDocumentFolderProject> _projects = const [];
  bool _hasMore = false;

  List<ProjectDocumentsBreadcrumb> get _trail =>
      widget.breadcrumbs ??
      projectDocumentsTrailForUploader(
        widget.uploader.name,
        employeeId: widget.uploader.employeeId,
      );

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cubit = context.read<ProjectDocumentsCubit>();
      final offset = reset ? 0 : _projects.length;
      final result = await _repo.getUploaderProjects(
        employeeId: widget.uploader.employeeId,
        filters: cubit.state.hubFilters,
        keyword: cubit.state.searchQuery,
        limit: 20,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        _projects = reset ? result.projects : [..._projects, ...result.projects];
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ProjectDocumentsApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load projects';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              title: widget.uploader.name,
              breadcrumbs: _trail,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _projects.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
      );
    }
    if (_error != null && _projects.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.tw),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ),
      );
    }
    if (_projects.isEmpty) {
      return Center(
        child: Text(
          'No projects for this staff member',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.greyPanel,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: ProjectsDashboardTheme.maroon,
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 120 &&
              _hasMore &&
              !_loading) {
            _load();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 16.th),
          itemCount: _projects.length + (_loading ? 1 : 0),
          separatorBuilder: (_, __) => SizedBox(height: 10.th),
          itemBuilder: (context, index) {
            if (index >= _projects.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              );
            }
            final project = _projects[index];
            final trail = projectDocumentsTrailForUploaderProject(
              uploaderName: widget.uploader.name,
              projectName: project.name,
              employeeId: widget.uploader.employeeId,
            );
            return ProjectDocumentsSectionTile(
              title: project.name,
              kind: ProjectDocumentHubKind.workOrder,
              fileCount: project.fileCount,
              iconSize: 50,
              variant: ProjectDocumentsTileVariant.sub,
              subtitle: project.woRefNo.isNotEmpty ? project.woRefNo : null,
              lastUpdatedLabel: formatDocumentDateLabel(project.lastUpdated),
              updatedBy: project.updatedBy,
              showMeta: true,
              onTap: () => pushUploaderProjectFiles(
                context,
                uploader: widget.uploader,
                projectId: project.projectId,
                projectName: project.name,
                breadcrumbs: trail,
              ),
            );
          },
        ),
      ),
    );
  }
}
