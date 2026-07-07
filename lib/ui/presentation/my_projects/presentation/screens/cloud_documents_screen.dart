import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_drill_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_navigation.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_section_tile.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// SharePoint folders and files for a project.
class CloudDocumentsScreen extends StatefulWidget {
  const CloudDocumentsScreen({
    super.key,
    required this.projectId,
    this.folderId,
    this.folderName,
    this.folderType,
    this.breadcrumbs = const [],
  });

  final int projectId;
  final String? folderId;
  final String? folderName;
  final String? folderType;
  final List<ProjectDocumentsBreadcrumb> breadcrumbs;

  @override
  State<CloudDocumentsScreen> createState() => _CloudDocumentsScreenState();
}

class _CloudDocumentsScreenState extends State<CloudDocumentsScreen> {
  final ProjectRemoteDataSource _dataSource = ProjectRemoteDataSource();

  bool _isLoading = true;
  String? _error;
  List<ProjectDocumentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.folderId != null) {
        final response = await _dataSource.fetchFolderContents(
          widget.projectId,
          widget.folderId!,
        );
        _items = response.items;
      } else {
        final response = await _dataSource.fetchProjectDocuments(
          widget.projectId,
          folderType: widget.folderType,
        );
        _items = response.items;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onFolderTap(ProjectDocumentItem folder) {
    final nextTrail = [
      ..._trail,
      ProjectDocumentsBreadcrumb.sharePointFolder(folder.name),
    ];
    pushCloudDocumentsFolder(
      context,
      projectId: widget.projectId,
      folderId: folder.id,
      folderName: folder.name,
      folderType: widget.folderType,
      breadcrumbs: nextTrail,
    );
  }

  Future<void> _onFileTap(ProjectDocumentItem file) async {
    var isLoadingDialogVisible = false;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: ProjectsDashboardTheme.white),
        ),
      );
      isLoadingDialogVisible = true;

      final response = await _dataSource.fetchFileDetails(
        widget.projectId,
        file.id,
      );

      if (mounted && isLoadingDialogVisible) {
        Navigator.pop(context);
        isLoadingDialogVisible = false;
      }

      final resolvedUrl = response.viewUrl.isNotEmpty
          ? response.viewUrl
          : (response.downloadUrl.isNotEmpty
              ? response.downloadUrl
              : (file.downloadUrl ?? ''));

      if (resolvedUrl.isEmpty) {
        throw Exception('No file URL returned from server');
      }

      if (!mounted) return;

      await openProjectFileInApp(
        context,
        rawUrl: resolvedUrl,
        fileName: response.name.isNotEmpty ? response.name : file.name,
      );
    } catch (e) {
      if (mounted && isLoadingDialogVisible) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: ProjectsDashboardTheme.maroonDark,
        ),
      );
    }
  }

  String get _headerTitle => widget.folderName ?? 'SharePoint';

  List<ProjectDocumentsBreadcrumb> get _trail {
    if (widget.breadcrumbs.isNotEmpty) return widget.breadcrumbs;
    return [
      ProjectDocumentsBreadcrumb.home,
      ProjectDocumentsBreadcrumb.kind(ProjectDocumentHubKind.cloud),
      if (widget.folderName != null)
        ProjectDocumentsBreadcrumb.project(widget.folderName!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final folders = _items.where((i) => i.isFolder).toList();
    final files = _items.where((i) => i.isFile).toList();

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
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 4.h, 8.w, 8.h),
              child: ProjectDocumentsDrillHeader(
                title: _headerTitle,
                kind: ProjectDocumentHubKind.cloud,
                breadcrumbs: _trail,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ProjectsDashboardTheme.white,
                      ),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadData)
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'No documents found',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: ProjectsDashboardTheme.greyPanel,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: ProjectsDashboardTheme.maroon,
                              onRefresh: _loadData,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                                children: [
                                  if (folders.isNotEmpty) ...[
                                    for (final folder in folders)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 14.h),
                                        child: ProjectDocumentsSectionTile(
                                          title: folder.name,
                                          kind: ProjectDocumentHubKind.cloud,
                                          isFolder: true,
                                          fileCount: 0,
                                          variant: ProjectDocumentsTileVariant.sub,
                                          subtitle: 'SharePoint folder',
                                          fileCountLabel: 'Folder',
                                          iconSize: 48,
                                          showMeta: false,
                                          onTap: () => _onFolderTap(folder),
                                        ),
                                      ),
                                  ],
                                  if (files.isNotEmpty) ...[
                                    for (final file in files)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 14.h),
                                        child: ProjectDocumentsFileRow(
                                          fileName: file.name,
                                          showChevron: false,
                                          onTap: () => _onFileTap(file),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading SharePoint documents',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: ProjectsDashboardTheme.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: ProjectsDashboardTheme.greyPanel,
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: ProjectsDashboardTheme.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
