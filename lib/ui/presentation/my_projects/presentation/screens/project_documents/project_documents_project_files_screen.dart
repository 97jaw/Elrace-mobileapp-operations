import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_documents_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/cloud_documents_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_drill_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsProjectFilesScreen extends StatefulWidget {
  const ProjectDocumentsProjectFilesScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.kind,
    this.breadcrumbs,
  });

  final int projectId;
  final String projectName;
  final ProjectDocumentHubKind kind;
  final List<ProjectDocumentsBreadcrumb>? breadcrumbs;

  @override
  State<ProjectDocumentsProjectFilesScreen> createState() =>
      _ProjectDocumentsProjectFilesScreenState();
}

class _ProjectDocumentsProjectFilesScreenState
    extends State<ProjectDocumentsProjectFilesScreen> {
  final _repo = ProjectDocumentsRepository(ProjectDocumentsRemoteDataSource());
  bool _loading = true;
  String? _error;
  List<ProjectDocumentFileItem> _files = const [];

  @override
  void initState() {
    super.initState();
    if (widget.kind == ProjectDocumentHubKind.cloud) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getProjectFiles(
        projectId: widget.projectId,
        kind: widget.kind,
      );
      if (!mounted) return;
      setState(() {
        _files = result.files;
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

  List<ProjectDocumentsBreadcrumb> get _trail =>
      widget.breadcrumbs ??
      projectDocumentsTrailForProject(
        kind: widget.kind,
        projectName: widget.projectName,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.kind == ProjectDocumentHubKind.cloud) {
      return CloudDocumentsScreen(
        projectId: widget.projectId,
        folderName: widget.projectName,
        breadcrumbs: _trail,
      );
    }

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
              kind: widget.kind,
              breadcrumbs: _trail,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.white,
          ),
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(
        child: Text(
          'No files',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.greyPanel,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 16.th),
      itemCount: _files.length,
      separatorBuilder: (_, __) => SizedBox(height: 14.th),
      itemBuilder: (context, index) {
        final file = _files[index];
        final updated = formatDocumentDateLabel(file.updatedAt);
        final by = file.updatedBy?.trim();
        final subtitleParts = <String>[
          widget.kind.title,
          if (by != null && by.isNotEmpty) 'By $by',
        ];
        return ProjectDocumentsFileRow(
          fileName: file.name,
          subtitle: subtitleParts.join(' · '),
          updatedLabel: updated != '—' ? 'Updated $updated' : null,
          kind: file.kind,
          showChevron: false,
          onTap: () async {
            if (file.url.isEmpty) return;
            await openProjectFileInApp(
              context,
              rawUrl: file.url,
              fileName: file.name,
            );
          },
        );
      },
    );
  }
}
