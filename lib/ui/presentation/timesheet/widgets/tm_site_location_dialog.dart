import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_employee_avatar.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_submit_geofence_dialog.dart'
    show kTmDefaultSubmitThresholdM;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Result of resolving the foreman's current site from GPS + in-progress list.
class TmForemanSiteLocation {
  const TmForemanSiteLocation({
    this.position,
    this.matched,
    this.matchedThresholdM,
    this.nearest,
    this.nearestDistanceM,
    this.nearestThresholdM,
  });

  final Position? position;

  /// In-progress project within its threshold (nearest if several).
  final Project? matched;
  final double? matchedThresholdM;

  /// Closest in-progress project with coordinates (even if outside threshold).
  final Project? nearest;
  final double? nearestDistanceM;
  final double? nearestThresholdM;

  bool get isLocated => matched != null;
  bool get hasGps => position != null;

  Project? get mapProject => matched ?? nearest;

  double get mapThresholdM =>
      matchedThresholdM ??
      nearestThresholdM ??
      kTmDefaultSubmitThresholdM;

  /// GPS once + nearest in-progress project within its Odoo threshold
  /// (same distance service as submit geofence). Default threshold 50 m.
  static Future<TmForemanSiteLocation> resolve({
    required List<Project> inProgress,
    required Future<double?> Function(String projectId) loadThresholdM,
    required Future<Position?> Function() readGps,
  }) async {
    final position = await readGps();
    if (position == null) {
      return const TmForemanSiteLocation();
    }
    const geo = TimesheetGeofenceService();
    final withCoords = [
      for (final p in inProgress)
        if (p.hasSiteCoordinates) p,
    ];
    if (withCoords.isEmpty) {
      return TmForemanSiteLocation(position: position);
    }

    final thresholds = await Future.wait<double?>([
      for (final p in withCoords)
        () async {
          try {
            return await loadThresholdM(p.id);
          } catch (_) {
            return null;
          }
        }(),
    ]);

    Project? nearest;
    double? nearestDist;
    double? nearestThreshold;
    Project? matched;
    double? matchedDist;
    double? matchedThreshold;

    for (var i = 0; i < withCoords.length; i++) {
      final project = withCoords[i];
      final raw = thresholds[i];
      final threshold = raw != null && raw > 0
          ? raw
          : kTmDefaultSubmitThresholdM;
      final dist = geo.distanceMeters(
        TimesheetGeoPoint(lat: position.latitude, lon: position.longitude),
        TimesheetGeoPoint(
          lat: project.geofenceLat,
          lon: project.geofenceLon,
        ),
      );
      if (nearestDist == null || dist < nearestDist) {
        nearest = project;
        nearestDist = dist;
        nearestThreshold = threshold;
      }
      if (dist <= threshold &&
          (matchedDist == null || dist < matchedDist)) {
        matched = project;
        matchedDist = dist;
        matchedThreshold = threshold;
      }
    }

    return TmForemanSiteLocation(
      position: position,
      matched: matched,
      matchedThresholdM: matchedThreshold,
      nearest: nearest,
      nearestDistanceM: nearestDist,
      nearestThresholdM: nearestThreshold,
    );
  }
}

/// Same visual language as [TmTimesheetSubmitDialog] (warm card), with map +
/// user + site circle. Used for Site location card and when walk-up capture
/// has no resolved project.
abstract final class TmSiteLocationDialog {
  static Future<void> show(
    BuildContext context, {
    required TmForemanSiteLocation location,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Site location',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _TmSiteLocationDialog(location: location),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _TmSiteLocationDialog extends StatelessWidget {
  const _TmSiteLocationDialog({required this.location});

  final TmForemanSiteLocation location;

  static const _green = Color(0xFF2E9E5B);
  static const _warn = Color(0xFFE6A700);

  @override
  Widget build(BuildContext context) {
    final located = location.isLocated;
    final accent = located ? _green : _warn;
    final project = location.mapProject;
    final title = located
        ? (project?.name ?? 'You are here')
        : 'Project not located';
    final detail = located ? null : _notLocatedDetail(location);
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final mapHeight = (size.height * 0.32).clamp(140.0, 220.0);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: width > 560 ? 440 : width - 32),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: TimesheetModuleColors.warmGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(
                      accent: accent,
                      title: title,
                      detail: detail,
                      located: located,
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: mapHeight,
                        child: _map(accent: accent, project: project),
                      ),
                    ),
                    if (project != null) ...[
                      const SizedBox(height: 12),
                      _legend(
                        accent: accent,
                        project: project,
                        distanceM: located
                            ? _distanceTo(location, project)
                            : location.nearestDistanceM,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: TimesheetModuleColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _notLocatedDetail(TmForemanSiteLocation location) {
    if (!location.hasGps) {
      return "Couldn't get your current location. Turn on location and try again.";
    }
    final nearest = location.nearest;
    final d = location.nearestDistanceM;
    if (nearest == null || d == null) {
      return 'No active site coordinates available.';
    }
    return 'Nearest: ${nearest.name} · ${_formatDistance(d)}';
  }

  static double? _distanceTo(TmForemanSiteLocation location, Project project) {
    final p = location.position;
    if (p == null || !project.hasSiteCoordinates) return null;
    return const TimesheetGeofenceService().distanceMeters(
      TimesheetGeoPoint(lat: p.latitude, lon: p.longitude),
      TimesheetGeoPoint(lat: project.geofenceLat, lon: project.geofenceLon),
    );
  }

  static String _formatDistance(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km'
      : '${m.round()} m';

  Widget _header({
    required Color accent,
    required String title,
    required String? detail,
    required bool located,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            located
                ? PhosphorIcons.mapPin(PhosphorIconsStyle.fill)
                : PhosphorIcons.warning(PhosphorIconsStyle.fill),
            color: accent,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TimesheetModuleTypography.h2().copyWith(
                  color: located
                      ? TimesheetModuleColors.ink
                      : TimesheetModuleColors.danger,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _map({required Color accent, required Project? project}) {
    final position = location.position;
    final user =
        position == null ? null : LatLng(position.latitude, position.longitude);
    final site = project != null && project.hasSiteCoordinates
        ? LatLng(project.geofenceLat, project.geofenceLon)
        : null;
    final thresholdM = location.mapThresholdM;
    final fence = location.isLocated ? _green : TimesheetModuleColors.danger;

    if (site == null && user == null) {
      return ColoredBox(
        color: TimesheetModuleColors.bgGradientEnd,
        child: Center(
          child: Text(
            'No map position',
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.warmMuted,
            ),
          ),
        ),
      );
    }

    const distance = Distance();
    final boundsPoints = <LatLng>[
      if (site != null) ...[
        for (final bearing in const [0.0, 90.0, 180.0, 270.0])
          distance.offset(site, thresholdM, bearing),
        site,
      ],
      if (user != null) user,
    ];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(boundsPoints),
          padding: const EdgeInsets.all(28),
        ),
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        AppMapTiles.streets(),
        if (site != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: site,
                radius: thresholdM,
                useRadiusInMeter: true,
                color: fence.withValues(alpha: 0.14),
                borderColor: fence.withValues(alpha: 0.85),
                borderStrokeWidth: 2.5,
              ),
            ],
          ),
        if (user != null && site != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [user, site],
                color: accent.withValues(alpha: 0.7),
                strokeWidth: 2.5,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (site != null)
              Marker(
                point: site,
                width: 36,
                height: 36,
                alignment: Alignment.bottomCenter,
                child: Icon(Icons.location_on, color: fence, size: 36),
              ),
            if (user != null)
              Marker(
                point: user,
                width: 46,
                height: 46,
                child: CheckinEmployeeAvatar.marker(size: 46),
              ),
          ],
        ),
      ],
    );
  }

  Widget _legend({
    required Color accent,
    required Project project,
    required double? distanceM,
  }) {
    return Row(
      children: [
        Icon(
          PhosphorIcons.buildings(),
          size: 16,
          color: TimesheetModuleColors.warmMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (distanceM != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _formatDistance(distanceM),
              style: TimesheetModuleTypography.caption().copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}
