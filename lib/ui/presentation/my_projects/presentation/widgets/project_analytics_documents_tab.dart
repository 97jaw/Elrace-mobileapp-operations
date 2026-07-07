import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/cloud_documents_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Documents tab: Work order / Estimations / Cloud sub-tabs.
class ProjectAnalyticsDocumentsTab extends StatefulWidget {
  const ProjectAnalyticsDocumentsTab({super.key, required this.projectId});

  final int projectId;

  @override
  State<ProjectAnalyticsDocumentsTab> createState() =>
      _ProjectAnalyticsDocumentsTabState();
}

class _ProjectAnalyticsDocumentsTabState extends State<ProjectAnalyticsDocumentsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Container(
            padding: EdgeInsets.all(3.w),
            decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
            child: TabBar(
              controller: _subTabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: ProjectsDashboardTheme.maroonAccentGradient,
                borderRadius: BorderRadius.circular(10.r),
              ),
              labelColor: ProjectsDashboardTheme.white,
              unselectedLabelColor:
                  ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.95),
              labelStyle: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Work order'),
                Tab(text: 'Estimations'),
                Tab(text: 'Cloud'),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _AttachmentsSubTab(
                projectId: widget.projectId,
                folderType: 'wo',
              ),
              _AttachmentsSubTab(
                projectId: widget.projectId,
                folderType: 'estimation',
              ),
              _CloudSubTab(projectId: widget.projectId),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentsSubTab extends StatefulWidget {
  const _AttachmentsSubTab({
    required this.projectId,
    required this.folderType,
  });

  final int projectId;
  final String folderType;

  @override
  State<_AttachmentsSubTab> createState() => _AttachmentsSubTabState();
}

class _AttachmentsSubTabState extends State<_AttachmentsSubTab> {
  late final ProjectListBloc _bloc;

  @override
  void initState() {
    super.initState();
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    _bloc = ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
    );
    _bloc.add(GetProjectAttachmentsEvent(
      '${widget.projectId}',
      folderType: widget.folderType,
    ));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProjectListBloc, ProjectListState>(
        builder: (context, state) {
          if (state is ProjectAttachmentsLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: ProjectsDashboardTheme.white,
              ),
            );
          }
          if (state is ProjectAttachmentsError) {
            return Center(
              child: Text(
                state.message,
                style: GoogleFonts.poppins(
                  color: ProjectsDashboardTheme.white,
                  fontSize: 12.sp,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          final list = _bloc.projectAttacmentList;
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No attachments',
                style: GoogleFonts.poppins(
                  color: ProjectsDashboardTheme.greyPanel,
                  fontSize: 13.sp,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final a = list[index];
              return _AttachmentTile(attachment: a);
            },
          );
        },
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (attachment.url.isEmpty) return;
          await openProjectFileInApp(
            context,
            rawUrl: attachment.url,
            fileName: attachment.name,
          );
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 12),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                color: ProjectsDashboardTheme.white,
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  attachment.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: ProjectsDashboardTheme.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudSubTab extends StatefulWidget {
  const _CloudSubTab({required this.projectId});

  final int projectId;

  @override
  State<_CloudSubTab> createState() => _CloudSubTabState();
}

class _CloudSubTabState extends State<_CloudSubTab> {
  final ProjectRemoteDataSource _ds = ProjectRemoteDataSource();
  bool _loading = true;
  String? _error;
  List<ProjectDocumentItem> _items = const [];

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
      final response = await _ds.fetchProjectDocuments(widget.projectId);
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
        child: Text(
          _error!,
          style: GoogleFonts.poppins(
            color: ProjectsDashboardTheme.white,
            fontSize: 12.sp,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No documents',
          style: GoogleFonts.poppins(
            color: ProjectsDashboardTheme.greyPanel,
            fontSize: 13.sp,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      itemCount: _items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (item.isFolder) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CloudDocumentsScreen(
                      projectId: widget.projectId,
                      folderId: item.id,
                      folderName: item.name,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: ProjectsDashboardTheme.frostedPanel(radius: 12),
              child: Row(
                children: [
                  Icon(
                    item.isFolder
                        ? Icons.folder_outlined
                        : Icons.cloud_outlined,
                    color: ProjectsDashboardTheme.white,
                    size: 22.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: ProjectsDashboardTheme.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
