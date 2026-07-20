import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/media_theme.dart';

/// Instagram-style dark tabs with optional list/grid view toggle.
class MediaFilterTabs extends StatelessWidget {
  const MediaFilterTabs({
    super.key,
    required this.activeIndex,
    required this.videoCount,
    required this.photoCount,
    required this.view360Count,
    required this.onTabSelected,
    this.showProjectVideos = false,
    this.projectVideoCount = 0,
    this.isGridView = false,
    this.onToggleView,
  });

  final int activeIndex;
  final int videoCount;
  final int photoCount;
  final int view360Count;
  final ValueChanged<int> onTabSelected;
  final bool showProjectVideos;
  final int projectVideoCount;
  final bool isGridView;
  final VoidCallback? onToggleView;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: MediaTheme.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                if (showProjectVideos)
                  _TabItem(
                    index: 0,
                    activeIndex: activeIndex,
                    icon: Icons.star_outline_rounded,
                    label: 'Projects',
                    count: projectVideoCount,
                    onTap: () => onTabSelected(0),
                  ),
                _TabItem(
                  index: showProjectVideos ? 1 : 0,
                  activeIndex: activeIndex,
                  icon: Icons.videocam_outlined,
                  label: 'Videos',
                  count: videoCount,
                  onTap: () => onTabSelected(showProjectVideos ? 1 : 0),
                ),
                _TabItem(
                  index: showProjectVideos ? 2 : 1,
                  activeIndex: activeIndex,
                  icon: Icons.photo_library_outlined,
                  label: 'Photos',
                  count: photoCount,
                  onTap: () => onTabSelected(showProjectVideos ? 2 : 1),
                ),
                _TabItem(
                  index: showProjectVideos ? 3 : 2,
                  activeIndex: activeIndex,
                  icon: Icons.threesixty_outlined,
                  label: '360°',
                  count: view360Count,
                  onTap: () => onTabSelected(showProjectVideos ? 3 : 2),
                ),
              ],
            ),
          ),
        ),
        if (onToggleView != null)
          SizedBox(
            width: 40.w,
            height: 40.w,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onToggleView,
              tooltip: isGridView ? 'List view' : 'Grid view',
              icon: Icon(
                isGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                color: MediaTheme.white,
                size: 20.sp,
              ),
            ),
          ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final int index;
  final int activeIndex;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeIndex;
    final color = isActive ? MediaTheme.white : MediaTheme.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14.sp, color: color),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? MediaTheme.textSecondary
                          : MediaTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator sits on the shared hairline, per-tab width.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: isActive ? MediaTheme.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
