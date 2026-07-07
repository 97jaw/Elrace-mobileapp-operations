import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Cached network image tuned for report thumbnails and gallery grids.
class TmFastNetworkImage extends StatelessWidget {
  const TmFastNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 320,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int memCacheWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _error(),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: TimesheetModuleColors.navyTint,
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: TimesheetModuleColors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _error() {
    return Container(
      width: width,
      height: height,
      color: TimesheetModuleColors.navyTint,
      alignment: Alignment.center,
      child: Icon(
        PhosphorIcons.imageBroken(),
        color: TimesheetModuleColors.mutedText,
        size: 22,
      ),
    );
  }

  /// Warm the cache for a list of URLs (e.g. after gallery API load).
  static Future<void> precacheUrls(
    BuildContext context,
    Iterable<String> urls, {
    int max = 12,
    int memCacheWidth = 480,
  }) async {
    var count = 0;
    for (final raw in urls) {
      if (count >= max) break;
      final u = raw.trim();
      if (u.isEmpty || !u.startsWith('http')) continue;
      count++;
      try {
        await precacheImage(
          CachedNetworkImageProvider(u, maxWidth: memCacheWidth),
          context,
        );
      } catch (_) {}
    }
  }
}
