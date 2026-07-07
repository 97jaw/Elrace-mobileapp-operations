import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/media_model.dart';
import 'media_video_grid_tile.dart';

/// Two-column masonry-style grid with varied tile heights.
class MediaStaggeredVideoGrid extends StatelessWidget {
  const MediaStaggeredVideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
  });

  final List<MediaModel> videos;
  final void Function(MediaModel media) onVideoTap;

  static double tileHeightForIndex(int index) {
    const pattern = [168.0, 212.0, 152.0, 228.0, 184.0, 196.0, 160.0, 220.0];
    return pattern[index % pattern.length].h;
  }

  @override
  Widget build(BuildContext context) {
    final leftItems = <Widget>[];
    final rightItems = <Widget>[];

    for (var i = 0; i < videos.length; i++) {
      final media = videos[i];
      final tile = Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: SizedBox(
          height: tileHeightForIndex(i),
          child: MediaVideoGridTile(
            media: media,
            onTap: () => onVideoTap(media),
          ),
        ),
      );

      if (i.isEven) {
        leftItems.add(tile);
      } else {
        rightItems.add(tile);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftItems)),
        SizedBox(width: 12.w),
        Expanded(child: Column(children: rightItems)),
      ],
    );
  }
}
