import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

import '../data/content_model.dart';
import '../utils/media_layout.dart';
import 'media_content_grid_tile.dart';

/// Masonry-style photo / 360° grid. Two columns on phones, more when the
/// available width allows (tablet sheets).
class MediaStaggeredContentGrid extends StatelessWidget {
  const MediaStaggeredContentGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.imageHeaders,
  });

  final List<ContentModel> items;
  final void Function(ContentModel item) onItemTap;
  final Map<String, String>? imageHeaders;

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

        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          columns[i % columnCount].add(
            Padding(
              padding: EdgeInsets.only(bottom: 14.th),
              child: SizedBox(
                height: tileHeightForIndex(i),
                child: MediaContentGridTile(
                  content: item,
                  imageHeaders: imageHeaders,
                  onTap: () => onItemTap(item),
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
