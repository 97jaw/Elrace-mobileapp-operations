import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Full-screen slide-up viewer for one gallery photo + description.
class TmSiteImageViewerSheet {
  TmSiteImageViewerSheet._();

  static Future<void> show(
    BuildContext context, {
    required List<TmGalleryViewerItem> items,
    required int initialIndex,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TmSiteImageViewerBody(
        items: items,
        initialIndex: initialIndex,
      ),
    );
  }
}

class TmGalleryViewerItem {
  const TmGalleryViewerItem({
    required this.imageUrl,
    this.description = '',
    this.location = '',
  });

  final String imageUrl;
  final String description;
  final String location;
}

class _TmSiteImageViewerBody extends StatefulWidget {
  const _TmSiteImageViewerBody({
    required this.items,
    required this.initialIndex,
  });

  final List<TmGalleryViewerItem> items;
  final int initialIndex;

  @override
  State<_TmSiteImageViewerBody> createState() => _TmSiteImageViewerBodyState();
}

class _TmSiteImageViewerBodyState extends State<_TmSiteImageViewerBody> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TimesheetModuleColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      '${_index + 1} / ${widget.items.length}',
                      style: TimesheetModuleTypography.caption().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(PhosphorIcons.x(), color: TimesheetModuleColors.text),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, pageIndex) {
                    final photo = widget.items[pageIndex];
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            TimesheetModuleLayout.cardRadiusMd,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: photo.imageUrl.isEmpty
                                ? Center(
                                    child: Icon(
                                      PhosphorIcons.imageBroken(),
                                      size: 48,
                                      color: TimesheetModuleColors.mutedText,
                                    ),
                                  )
                                : InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 4,
                                    child: TmFastNetworkImage(
                                      url: photo.imageUrl,
                                      fit: BoxFit.contain,
                                      memCacheWidth: 1200,
                                    ),
                                  ),
                          ),
                        ),
                        if (photo.location.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Location',
                            style: TimesheetModuleTypography.caption().copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            photo.location.trim(),
                            style: TimesheetModuleTypography.body(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'Description',
                          style: TimesheetModuleTypography.caption().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          photo.description.trim().isEmpty
                              ? 'No description'
                              : photo.description.trim(),
                          style: TimesheetModuleTypography.body(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: bottom),
            ],
          ),
        );
      },
    );
  }
}
