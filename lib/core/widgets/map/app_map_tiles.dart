import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Shared, production-safe map tile configuration.
///
/// Why this exists:
/// - The app previously pointed every [FlutterMap] straight at CARTO's/OSM's
///   free demo tile servers with the default (uncached) network provider. On
///   screens like check-in the map requests dozens of tiles in a burst, the
///   demo servers throttle them, and the reset connections surfaced as uncaught
///   `ClientException: Connection reset by peer (errno 54)` spam.
/// - This helper uses MapTiler (keyed, production tier), adds a disk cache (so
///   revisited tiles never hit the network), swallows transient tile errors
///   quietly, and trims the initial request burst via smaller buffers.
class AppMapTiles {
  AppMapTiles._();

  /// MapTiler API key. Restricted by user-agent ([_userAgent]) in the MapTiler
  /// dashboard. Client-side map keys are inherently public (shipped in the
  /// app), so the user-agent restriction is what protects the quota.
  static const String _mapTilerKey = 'NX0QVrxgwhIi4YeVGtSl';

  /// Must match the "Allowed user-agent header" set on the MapTiler key.
  static const String _userAgent = 'ae.elrace.mobile';

  /// MapTiler raster style used across the app (light, CARTO-Voyager-like).
  /// Swap the style id (e.g. `basic-v2`, `dataviz`, `bright-v2`) to restyle
  /// every map at once.
  static const String _style = 'streets-v2';

  static const String _mapTilerUrl =
      'https://api.maptiler.com/maps/$_style/{z}/{x}/{y}{r}.png?key=$_mapTilerKey';

  /// Dedicated disk cache for map tiles, kept separate from the image cache so
  /// tiles don't evict avatars/photos and vice-versa.
  static final CacheManager _tileCache = CacheManager(
    Config(
      'elraceMapTiles',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 2000,
    ),
  );

  /// Primary basemap layer for detailed / interactive maps.
  static TileLayer streets({bool retina = true, int maxZoom = 19}) {
    return _layer(retina: retina, maxZoom: maxZoom);
  }

  /// Alias kept for readability at call sites that show a simple static map.
  static TileLayer basic({int maxZoom = 19}) {
    return _layer(retina: false, maxZoom: maxZoom);
  }

  static TileLayer _layer({required bool retina, required int maxZoom}) {
    return TileLayer(
      urlTemplate: _mapTilerUrl,
      userAgentPackageName: _userAgent,
      tileProvider: _CachedTileProvider(cacheManager: _tileCache),
      retinaMode: retina,
      maxNativeZoom: maxZoom,
      maxZoom: maxZoom.toDouble(),
      // Smaller burst on first paint; still smooth when panning.
      keepBuffer: 1,
      panBuffer: 0,
      // Failed tiles are quietly retried/evicted instead of crashing the frame.
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      errorTileCallback: (tile, error, stackTrace) {
        // Transient CDN resets are expected; only note them while debugging.
        if (kDebugMode) {
          debugPrint('[map] tile failed (${tile.coordinates}): $error');
        }
      },
    );
  }
}

/// [TileProvider] backed by [CachedNetworkImageProvider] so tiles are served
/// from disk after the first fetch.
class _CachedTileProvider extends TileProvider {
  _CachedTileProvider({required this.cacheManager});

  final BaseCacheManager cacheManager;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheManager: cacheManager,
      headers: headers,
    );
  }
}
