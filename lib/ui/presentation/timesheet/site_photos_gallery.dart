import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/services/timesheet_offline_queue_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SitePhotosGallery extends StatefulWidget {
  const SitePhotosGallery({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  State<SitePhotosGallery> createState() => _SitePhotosGalleryState();
}

class _SitePhotosGalleryState extends State<SitePhotosGallery> {
  String _filter = 'all';
  final _queueService = TimesheetOfflineQueueService();

  static const _photos = [
    ('Progress', 'Tower slab progress', '11 May 2026'),
    ('Safety', 'Harness inspection', '11 May 2026'),
    ('Delivery', 'Concrete delivery', '10 May 2026'),
    ('Issue', 'Blocked access path', '10 May 2026'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _photos
        : _photos.where((item) => item.$1.toLowerCase() == _filter).toList();

    return TmScaffold(
      appBar: AppBar(
        title: Text('Site Photos', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TmFilterChipRow(
            options: [
              TmFilterOption(
                  id: 'all', label: 'All', icon: PhosphorIcons.images()),
              TmFilterOption(
                id: 'progress',
                label: 'Progress',
                icon: PhosphorIcons.chartLineUp(),
              ),
              TmFilterOption(
                id: 'safety',
                label: 'Safety',
                icon: PhosphorIcons.shieldCheck(),
              ),
              TmFilterOption(
                id: 'issue',
                label: 'Issue',
                icon: PhosphorIcons.warningCircle(),
              ),
            ],
            selectedId: _filter,
            onChanged: (id) => setState(() => _filter = id),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Expanded(
            child: GridView.builder(
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: TimesheetModuleLayout.cardSpacing,
                crossAxisSpacing: TimesheetModuleLayout.cardSpacing,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) {
                final photo = filtered[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  onTap: () => _showViewer(context, photo),
                  child: Container(
                    decoration: BoxDecoration(
                      color: TimesheetModuleColors.surface,
                      borderRadius: BorderRadius.circular(
                        TimesheetModuleLayout.cardRadiusMd,
                      ),
                      boxShadow: TimesheetModuleShadows.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: TimesheetModuleColors.navyTint,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(
                                  TimesheetModuleLayout.cardRadiusMd,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.imageSquare(),
                                color: TimesheetModuleColors.navy,
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(photo.$1,
                                  style: TimesheetModuleTypography.cardTitle()),
                              const SizedBox(height: 4),
                              Text(photo.$2,
                                  style: TimesheetModuleTypography.caption()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmPrimaryButton(
            label: 'Capture Site Photo',
            icon: PhosphorIcons.camera(),
            onPressed: _captureSitePhoto,
          ),
        ],
      ),
    );
  }

  Future<void> _captureSitePhoto() async {
    await _queueService.enqueue(timesheetMockSitePhotoItem(widget.projectId));
    final pendingCount = await _queueService.pendingCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Site photo queued. Pending extras: $pendingCount')),
    );
  }

  void _showViewer(BuildContext context, (String, String, String) photo) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.navyTint,
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                ),
                child: Center(
                  child: Icon(
                    PhosphorIcons.imageSquare(),
                    size: 72,
                    color: TimesheetModuleColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              Text(photo.$2, style: TimesheetModuleTypography.h2()),
              Text(photo.$3, style: TimesheetModuleTypography.caption()),
            ],
          ),
        ),
      ),
    );
  }
}
