import '../data/media_model.dart';

/// Picks the hero trailer video from the media list.
abstract final class MediaHeroSelector {
  /// Optional featured id from backend — set when API supports it.
  static String? featuredVideoId;

  static MediaModel? selectHeroVideo(List<MediaModel> videos) {
    final videoItems = videos.where((v) => v.isVideo).toList();
    if (videoItems.isEmpty) return null;

    if (featuredVideoId != null && featuredVideoId!.isNotEmpty) {
      for (final v in videoItems) {
        if (v.id == featuredVideoId) return v;
      }
    }

    videoItems.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return videoItems.first;
  }

  static List<MediaModel> remainingVideos(
    List<MediaModel> videos,
    MediaModel? hero,
  ) {
    if (hero == null) {
      return videos.where((v) => v.isVideo).toList()
        ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    }
    return videos
        .where((v) => v.isVideo && v.id != hero.id)
        .toList()
      ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
  }
}
