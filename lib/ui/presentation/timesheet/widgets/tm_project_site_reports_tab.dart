import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_folder_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_new_site_report_folder_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_site_report_folder_card.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

/// Step 1 — report folders for this project (`x_project_id`).
class TmProjectSiteReportsTab extends StatefulWidget {
  const TmProjectSiteReportsTab({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<TmProjectSiteReportsTab> createState() =>
      _TmProjectSiteReportsTabState();
}

class _TmProjectSiteReportsTabState extends State<TmProjectSiteReportsTab> {
  final ReportProvider _reportProvider = ReportProvider();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _search = '';
  List<FolderModel> _folders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reportProvider.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CompanyRepository().getCompany();
      await _reportProvider.init(base: 'https://erp.elrace.com');
      _folders =
          await _reportProvider.fetchFoldersForProject(widget.projectId);
      if (mounted) {
        final urls = _folders.expand((f) => f.latestItemImages).take(18);
        await TmFastNetworkImage.precacheUrls(context, urls, max: 18, memCacheWidth: 120);
      }
    } catch (_) {
      _error = 'Could not load report folders';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _openFolder(
    FolderModel folder, {
    TmFolderEntryAction entryAction = TmFolderEntryAction.none,
  }) {
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReportProvider>.value(
          value: _reportProvider,
          child: TmSiteReportFolderScreen(
            folder: folder,
            projectId: widget.projectId,
            projectName: widget.projectName,
            entryAction: entryAction,
          ),
        ),
      ),
    )
        .then((_) => _load());
  }

  Future<void> _createFolder() async {
    final name = await TmNewSiteReportFolderSheet.show(
      context,
      projectName: widget.projectName,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await _reportProvider.createFolderForProject(
        projectId: widget.projectId,
        title: name.trim(),
      );
      await _reportProvider.fetchFoldersForProject(widget.projectId);
      FolderModel? created;
      for (final f in _reportProvider.folders) {
        if (f.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          created = f;
          break;
        }
      }
      created ??=
          _reportProvider.folders.isNotEmpty ? _reportProvider.folders.first : null;

      if (!mounted || created == null) return;
      _openFolder(created, entryAction: TmFolderEntryAction.openNewReport);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<FolderModel> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _folders;
    return _folders
        .where(
          (f) =>
              f.name.toLowerCase().contains(q) ||
              f.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TimesheetLoadingState(
        style: TimesheetLoadingStyle.folders,
        itemCount: 3,
      );
    }
    if (_error != null) {
      return TimesheetErrorState(message: _error!, onRetry: _load);
    }

    final folders = _filtered;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
      ),
      child: Stack(
        children: [
          Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FoldersHeader(
              projectName: widget.projectName,
              folderCount: _folders.length,
              onCreateFolder: _busy ? null : _createFolder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TimesheetModuleLayout.screenPaddingH,
                TimesheetModuleLayout.cardSpacing,
                TimesheetModuleLayout.screenPaddingH,
                0,
              ),
              child: TmSearchField(
                hintText: 'Search folders',
                onDebouncedChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            Expanded(
              child: _busy
                  ? const TimesheetLoadingState(
                      style: TimesheetLoadingStyle.folders,
                      itemCount: 2,
                    )
                  : RefreshIndicator(
                      color: TimesheetModuleColors.primary,
                      onRefresh: _load,
                      child: folders.isEmpty
                          ? _EmptyFolders(onCreate: _createFolder)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                bottom: TimesheetModuleLayout.sectionGap,
                              ),
                              itemCount: folders.length,
                              separatorBuilder: (_, __) => const SizedBox(
                                height: TimesheetModuleLayout.cardSpacing,
                              ),
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                return SizedBox(
                                  width: double.infinity,
                                  child: TmSiteReportFolderCard(
                                    folder: folder,
                                    onTap: () => _openFolder(folder),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
          if (!_busy && folders.isNotEmpty)
            Positioned(
              right: 0,
              bottom: TimesheetModuleLayout.cardSpacing,
              child: FloatingActionButton(
                backgroundColor: TimesheetModuleColors.primary,
                foregroundColor: TimesheetModuleColors.surface,
                onPressed: _createFolder,
                child: Icon(PhosphorIcons.folderPlus()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoldersHeader extends StatelessWidget {
  const _FoldersHeader({
    required this.projectName,
    required this.folderCount,
    required this.onCreateFolder,
  });

  final String projectName;
  final int folderCount;
  final VoidCallback? onCreateFolder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: TimesheetModuleLayout.cardSpacing),
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TimesheetModuleColors.navy,
            Color(0xFF284D7D),
            TimesheetModuleColors.primaryGradientEnd,
          ],
        ),
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        boxShadow: TimesheetModuleShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site report folders',
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.surface
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$folderCount',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmPrimaryButton(
            label: 'New folder',
            icon: PhosphorIcons.folderPlus(),
            onPressed: onCreateFolder,
          ),
        ],
      ),
    );
  }
}

class _EmptyFolders extends StatelessWidget {
  const _EmptyFolders({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
        vertical: TimesheetModuleLayout.sectionGap,
      ),
      children: [
        const TimesheetEmptyState(
          message:
              'No report folders for this project yet.\nCreate a folder, then add photos and generate PDFs inside.',
        ),
        const SizedBox(height: TimesheetModuleLayout.sectionGap),
        TmPrimaryButton(
          label: 'Create first folder',
          icon: PhosphorIcons.folderPlus(),
          onPressed: onCreate,
        ),
      ],
    );
  }
}
