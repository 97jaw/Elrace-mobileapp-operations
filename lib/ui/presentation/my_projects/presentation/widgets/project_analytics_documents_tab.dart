import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_documents_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Documents tab — flat list of project files (work order + estimation).
class ProjectAnalyticsDocumentsTab extends StatefulWidget {
  const ProjectAnalyticsDocumentsTab({super.key, required this.projectId});

  final int projectId;

  @override
  State<ProjectAnalyticsDocumentsTab> createState() =>
      _ProjectAnalyticsDocumentsTabState();
}

class _ProjectAnalyticsDocumentsTabState
    extends State<ProjectAnalyticsDocumentsTab> {
  final _repo = ProjectDocumentsRepository(ProjectDocumentsRemoteDataSource());
  bool _loading = true;
  String? _error;
  List<({ProjectDocumentFileItem file, ProjectDocumentHubKind kind})> _files =
      const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getProjectFiles(
          projectId: widget.projectId,
          kind: ProjectDocumentHubKind.workOrder,
        ),
        _repo.getProjectFiles(
          projectId: widget.projectId,
          kind: ProjectDocumentHubKind.estimation,
        ),
      ]);
      if (!mounted) return;
      final merged = <({ProjectDocumentFileItem file, ProjectDocumentHubKind kind})>[];
      for (final kind in [
        ProjectDocumentHubKind.workOrder,
        ProjectDocumentHubKind.estimation,
      ]) {
        final page = results[kind == ProjectDocumentHubKind.workOrder ? 0 : 1];
        for (final file in page.files) {
          merged.add((file: file, kind: kind));
        }
      }
      merged.sort((a, b) {
        final aDate = a.file.updatedAt ?? '';
        final bDate = b.file.updatedAt ?? '';
        return bDate.compareTo(aDate);
      });
      setState(() {
        _files = merged;
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
        _error = 'Failed to load documents';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.tw),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
              SizedBox(height: 16.th),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(
        child: Text(
          'No documents for this project',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            color: ProjectsDashboardTheme.greyPanel,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: ProjectsDashboardTheme.white,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 16.th),
        itemCount: _files.length,
        separatorBuilder: (_, __) => SizedBox(height: 14.th),
        itemBuilder: (context, index) {
          final entry = _files[index];
          final file = entry.file;
          final kind = entry.kind;
          final updated = formatDocumentDateLabel(file.updatedAt);
          final by = file.updatedBy?.trim();
          final subtitleParts = <String>[
            kind.title,
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
                attachmentId: parseProjectAttachmentId(file.id),
              );
            },
          );
        },
      ),
    );
  }
}
