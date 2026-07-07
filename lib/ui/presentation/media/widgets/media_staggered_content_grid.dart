import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/content_model.dart';
import 'media_content_grid_tile.dart';

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
    return pattern[index % pattern.length].h;
  }

  @override
  Widget build(BuildContext context) {
    final leftItems = <Widget>[];
    final rightItems = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final tile = Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: SizedBox(
          height: tileHeightForIndex(i),
          child: MediaContentGridTile(
            content: item,
            imageHeaders: imageHeaders,
            onTap: () => onItemTap(item),
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
