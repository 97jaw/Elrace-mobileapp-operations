import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/media_theme.dart';

/// Shared draggable sheet shell: fixed handle + tabs, scrollable body below.
class MediaGallerySheet extends StatelessWidget {
  const MediaGallerySheet({
    super.key,
    required this.scrollController,
    required this.onHandleTap,
    required this.filterTabs,
    required this.bodySlivers,
  });

  final ScrollController scrollController;
  final VoidCallback onHandleTap;
  final Widget filterTabs;
  final List<Widget> bodySlivers;

  @override
  Widget build(BuildContext context) {
    return MediaTheme.glassSheetBackground(
      child: Column(
        children: [
          GestureDetector(
            onTap: onHandleTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                SizedBox(height: 10.h),
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: MediaTheme.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                SizedBox(height: 6.h),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 4.w, 4.h),
            child: filterTabs,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: MediaTheme.white.withValues(alpha: 0.10),
          ),
          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                ...bodySlivers,
                SliverToBoxAdapter(child: SizedBox(height: 32.h)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
