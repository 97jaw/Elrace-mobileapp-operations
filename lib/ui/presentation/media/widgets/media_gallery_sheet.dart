import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';

import '../theme/media_theme.dart';
import '../utils/media_layout.dart';

/// Shared draggable sheet shell: fixed handle + tabs, scrollable body below.
///
/// Also used as the fixed side panel of the tablet split view, where there is
/// nothing to drag and [showHandle] is false.
class MediaGallerySheet extends StatelessWidget {
  const MediaGallerySheet({
    super.key,
    required this.scrollController,
    required this.onHandleTap,
    required this.filterTabs,
    required this.bodySlivers,
    this.showHandle = true,
  });

  final ScrollController scrollController;
  final VoidCallback onHandleTap;
  final Widget filterTabs;
  final List<Widget> bodySlivers;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return MediaTheme.glassSheetBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = MediaLayout.centeredInset(
            constraints.maxWidth,
            MediaLayout.galleryMaxWidth,
          );
          return Column(
            children: [
              if (showHandle)
                GestureDetector(
                  onTap: onHandleTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      SizedBox(height: 10.th),
                      Container(
                        width: 40.tw,
                        height: 4.th,
                        decoration: BoxDecoration(
                          color: MediaTheme.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      SizedBox(height: 6.th),
                    ],
                  ),
                )
              else
                SafeArea(
                  bottom: false,
                  left: false,
                  child: SizedBox(height: 12.th),
                ),
              Padding(
                padding:
                    EdgeInsets.fromLTRB(12.tw + inset, 0, 4.tw + inset, 4.th),
                child: filterTabs,
              ),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    for (final sliver in bodySlivers)
                      inset == 0
                          ? sliver
                          : SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: inset),
                              sliver: sliver,
                            ),
                    SliverToBoxAdapter(child: SizedBox(height: 32.th)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
