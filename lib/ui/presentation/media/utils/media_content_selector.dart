import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/content_model.dart';

abstract final class MediaContentSelector {
  static ContentModel? selectHero(List<ContentModel> items) {
    if (items.isEmpty) return null;
    final sorted = List<ContentModel>.from(items);
    sorted.sort((a, b) {
      final ad = a.dateCreated;
      final bd = b.dateCreated;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return sorted.first;
  }

  static List<ContentModel> remainingItems(
    List<ContentModel> items,
    int heroIndex,
  ) {
    if (items.length <= 1) return const [];
    return [
      for (var i = 0; i < items.length; i++)
        if (i != heroIndex) items[i],
    ];
  }

  static int indexOf(List<ContentModel> items, ContentModel item) {
    return items.indexWhere((e) => e.id == item.id);
  }
}
