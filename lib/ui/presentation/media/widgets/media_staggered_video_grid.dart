import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

import '../data/media_model.dart';
import '../utils/media_layout.dart';
import 'media_video_grid_tile.dart';

/// Masonry-style grid with varied tile heights. Two columns on phones, more
/// when the available width allows (tablet sheets).
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
    return pattern[index % pattern.length].th;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = MediaLayout.gridColumns(constraints.maxWidth);
        final columns = List.generate(columnCount, (_) => <Widget>[]);

        for (var i = 0; i < videos.length; i++) {
          final media = videos[i];
          columns[i % columnCount].add(
            Padding(
              padding: EdgeInsets.only(bottom: 14.th),
              child: SizedBox(
                height: tileHeightForIndex(i),
                child: MediaVideoGridTile(
                  media: media,
                  onTap: () => onVideoTap(media),
                ),
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columnCount; c++) ...[
              if (c > 0) SizedBox(width: 12.tw),
              Expanded(child: Column(children: columns[c])),
            ],
          ],
        );
      },
    );
  }
}
