import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_documents_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_drill_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Files uploaded by [uploader] within a single project.
class ProjectDocumentsUploaderProjectFilesScreen extends StatefulWidget {
  const ProjectDocumentsUploaderProjectFilesScreen({
    super.key,
    required this.uploader,
    required this.projectId,
    required this.projectName,
    this.breadcrumbs,
  });

  final ProjectDocumentsUploaderItem uploader;
  final int projectId;
  final String projectName;
  final List<ProjectDocumentsBreadcrumb>? breadcrumbs;

  @override
  State<ProjectDocumentsUploaderProjectFilesScreen> createState() =>
      _ProjectDocumentsUploaderProjectFilesScreenState();
}

class _ProjectDocumentsUploaderProjectFilesScreenState
    extends State<ProjectDocumentsUploaderProjectFilesScreen> {
  final _repo = ProjectDocumentsRepository(ProjectDocumentsRemoteDataSource());

  bool _loading = true;
  String? _error;
  List<ProjectDocumentFileItem> _files = const [];
  bool _hasMore = false;

  List<ProjectDocumentsBreadcrumb> get _trail =>
      widget.breadcrumbs ??
      projectDocumentsTrailForUploaderProject(
        uploaderName: widget.uploader.name,
        projectName: widget.projectName,
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
      final offset = reset ? 0 : _files.length;
      final result = await _repo.getFiles(
        filters: cubit.state.hubFilters,
        projectId: widget.projectId,
        uploaderId: widget.uploader.employeeId,
        limit: 30,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        _files = reset ? result.files : [..._files, ...result.files];
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
        _error = 'Failed to load files';
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
              title: widget.projectName,
              breadcrumbs: _trail,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _files.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
      );
    }
    if (_error != null && _files.isEmpty) {
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
    if (_files.isEmpty) {
      return Center(
        child: Text(
          'No files from ${widget.uploader.name}',
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
          padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 16.th),
          itemCount: _files.length + (_loading ? 1 : 0),
          separatorBuilder: (_, __) => SizedBox(height: 12.th),
          itemBuilder: (context, index) {
            if (index >= _files.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              );
            }
            final file = _files[index];
            final updated = formatDocumentDateLabel(file.updatedAt);
            return ProjectDocumentsFileRow(
              fileName: file.name,
              subtitle: file.kind.title,
              updatedLabel: updated != '—' ? 'Updated $updated' : null,
              kind: file.kind,
              showChevron: false,
              onTap: () async {
                if (file.url.isEmpty) return;
                await openProjectFileInApp(
                  context,
                  rawUrl: file.url,
                  fileName: file.name,
                  attachmentId: parseProjectAttachmentId(file.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
