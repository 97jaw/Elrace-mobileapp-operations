import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/models/tm_site_photo_draft.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Horizontal sliding editor: one photo per page with description field.
class TmSitePhotoDescriptionCarousel extends StatefulWidget {
  const TmSitePhotoDescriptionCarousel({
    super.key,
    required this.drafts,
    required this.projectName,
    required this.onRemove,
    this.initialIndex = 0,
  });

  final List<TmSitePhotoDraft> drafts;
  final String projectName;
  final void Function(int index) onRemove;
  final int initialIndex;

  @override
  State<TmSitePhotoDescriptionCarousel> createState() =>
      _TmSitePhotoDescriptionCarouselState();
}

class _TmSitePhotoDescriptionCarouselState
    extends State<TmSitePhotoDescriptionCarousel> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.drafts.length - 1);
    _pageController = PageController(
      initialPage: _current,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    if (index < 0 || index >= widget.drafts.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final described = widget.drafts.where((d) => d.hasDescription).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TimesheetModuleLayout.screenPaddingH,
          ),
          child: Row(
            children: [
              Text(
                'Add descriptions',
                style: TimesheetModuleTypography.cardTitle(),
              ),
              const Spacer(),
              Text(
                '$described / ${widget.drafts.length}',
                style: TimesheetModuleTypography.caption().copyWith(
                  fontWeight: FontWeight.w800,
                  color: described == widget.drafts.length
                      ? const Color(0xFF3DDC84)
                      : TimesheetModuleColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.drafts.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final draft = widget.drafts[index];
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(
                  left: index == 0 ? 12 : 6,
                  right: 6,
                  top: 4,
                  bottom: 8,
                ),
                child: _PhotoCard(
                  draft: draft,
                  index: index,
                  highlightMissing: !draft.hasDescription,
                  onRemove: () => widget.onRemove(index),
                  onChanged: () => setState(() {}),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TimesheetModuleLayout.screenPaddingH,
            ),
            itemCount: widget.drafts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final draft = widget.drafts[index];
              final selected = index == _current;
              return GestureDetector(
                onTap: () => _jumpTo(index),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? TimesheetModuleColors.primary
                          : (draft.hasDescription
                              ? const Color(0xFF3DDC84)
                              : const Color(0xFFE6A700)),
                      width: selected ? 2.5 : 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumb(draft),
                      if (!draft.hasDescription)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Icon(
                            PhosphorIcons.warning(),
                            size: 14,
                            color: const Color(0xFFE6A700),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _thumb(TmSitePhotoDraft draft) {
    if (draft.localFile != null) {
      return Image.file(draft.localFile!, fit: BoxFit.cover);
    }
    final url = draft.networkImageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return TmFastNetworkImage(url: url, fit: BoxFit.cover, memCacheWidth: 120);
    }
    return ColoredBox(
      color: TimesheetModuleColors.navyTint,
      child: Icon(PhosphorIcons.image(), color: TimesheetModuleColors.mutedText),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.draft,
    required this.index,
    required this.highlightMissing,
    required this.onRemove,
    required this.onChanged,
  });

  final TmSitePhotoDraft draft;
  final int index;
  final bool highlightMissing;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TimesheetModuleColors.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius:
          BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  draft.isServer ? 'Photo ${index + 1} (saved)' : 'Photo ${index + 1}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: Icon(
                    PhosphorIcons.trash(),
                    size: 20,
                    color: TimesheetModuleColors.danger,
                  ),
                ),
              ],
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusMd,
                ),
                child: _image(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.descriptionController,
              maxLines: 3,
              onChanged: (_) => onChanged(),
              style: TimesheetModuleTypography.body(),
              decoration: InputDecoration(
                hintText: 'Enter description…',
                hintStyle: TimesheetModuleTypography.body().copyWith(
                  color: TimesheetModuleColors.mutedText,
                ),
                filled: true,
                fillColor: TimesheetModuleColors.bgGradientEnd,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusSm,
                  ),
                  borderSide: BorderSide(
                    color: highlightMissing
                        ? const Color(0xFFE6A700)
                        : TimesheetModuleColors.divider,
                    width: highlightMissing ? 1.5 : 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusSm,
                  ),
                  borderSide: BorderSide(
                    color: highlightMissing
                        ? const Color(0xFFE6A700)
                        : TimesheetModuleColors.divider,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    if (draft.localFile != null) {
      return Image.file(draft.localFile!, width: double.infinity, fit: BoxFit.cover);
    }
    final url = draft.networkImageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return TmFastNetworkImage(url: url, fit: BoxFit.cover, memCacheWidth: 600);
    }
    return ColoredBox(
      color: TimesheetModuleColors.navyTint,
      child: Center(
        child: Icon(PhosphorIcons.imageBroken(), color: TimesheetModuleColors.mutedText),
      ),
    );
  }
}
