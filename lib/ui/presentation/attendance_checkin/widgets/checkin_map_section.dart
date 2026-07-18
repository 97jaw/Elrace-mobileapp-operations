import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_distance_formatter.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Default center (Dubai) when GPS / project are not ready yet.
const _kDefaultMapCenter = LatLng(25.2048, 55.2708);

class CheckinMapSection extends StatefulWidget {
  const CheckinMapSection({
    super.key,
    required this.userPosition,
    required this.selectedProject,
    required this.isInsideGeofence,
    required this.distanceMeters,
    required this.routePoints,
    this.routeLoading = false,
  });

  final Position? userPosition;
  final CheckinAllowedProject? selectedProject;
  final bool isInsideGeofence;
  final double? distanceMeters;
  final List<LatLng> routePoints;
  final bool routeLoading;

  @override
  State<CheckinMapSection> createState() => _CheckinMapSectionState();
}

class _CheckinMapSectionState extends State<CheckinMapSection>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  bool _followUser = true;
  int? _lastProjectId;
  bool _mapReady = false;

  @override
  bool get wantKeepAlive => true;

  LatLng get _mapCenter {
    final project = widget.selectedProject;
    if (project != null) return LatLng(project.lat, project.lng);
    final user = widget.userPosition;
    if (user != null) return LatLng(user.latitude, user.longitude);
    return _kDefaultMapCenter;
  }

  @override
  void didUpdateWidget(covariant CheckinMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final projectId = widget.selectedProject?.projectId;
    if (projectId != null && projectId != _lastProjectId) {
      _lastProjectId = projectId;
      _followUser = true;
      _moveToProject(animate: _mapReady);
    } else if (_followUser &&
        oldWidget.userPosition != widget.userPosition &&
        widget.userPosition != null) {
      _centerOnUser();
    }
  }

  void _onMapReady() {
    _mapReady = true;
    if (widget.selectedProject != null) {
      _moveToProject(animate: false);
    }
  }

  void _moveToProject({required bool animate}) {
    final project = widget.selectedProject;
    if (project == null || !_mapReady) return;

    final point = LatLng(project.lat, project.lng);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animate) {
        _mapController.move(point, 15);
      } else {
        _mapController.move(point, 15);
      }
    });
  }

  void _centerOnUser() {
    final user = widget.userPosition;
    if (user == null || !_mapReady) return;
    final point = LatLng(user.latitude, user.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, _mapController.camera.zoom);
    });
  }

  void _onRecenter() {
    setState(() => _followUser = false);
    final project = widget.selectedProject;
    final user = widget.userPosition;
    if (project == null || !_mapReady) return;

    final projectPoint = LatLng(project.lat, project.lng);
    final points = <LatLng>[projectPoint];
    if (user != null) {
      points.add(LatLng(user.latitude, user.longitude));
    }
    if (points.length == 1) {
      _mapController.move(projectPoint, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: EdgeInsets.fromLTRB(32.w, 70.h, 32.w, 80.h),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final project = widget.selectedProject;
    final user = widget.userPosition;
    final hasGps = user != null;
    final center = _mapCenter;

    final projectPoint =
        project != null ? LatLng(project.lat, project.lng) : null;
    final userPoint =
        user != null ? LatLng(user.latitude, user.longitude) : null;
    const radiusColor = HomeGlassTheme.bottleGreen;

    final routePoints = projectPoint != null && widget.routePoints.length >= 2
        ? widget.routePoints
        : (userPoint != null && projectPoint != null
            ? [userPoint, projectPoint]
            : <LatLng>[]);

    final proximity = CheckinDistanceFormatter.proximityLabel(
      isInside: widget.isInsideGeofence,
      hasGps: hasGps && project != null,
    );
    final distanceText =
        CheckinDistanceFormatter.formatDistance(widget.distanceMeters);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: _onMapReady,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) _followUser = false;
              },
            ),
            children: [
              AppMapTiles.streets(),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('© CARTO'),
                ],
              ),
              if (projectPoint != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: projectPoint,
                      radius: project!.geofenceRadiusM,
                      useRadiusInMeter: true,
                      color: radiusColor.withValues(alpha: 0.14),
                      borderColor: radiusColor.withValues(alpha: 0.85),
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.8),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (projectPoint != null)
                    Marker(
                      point: projectPoint,
                      width: 36,
                      height: 36,
                      alignment: Alignment.bottomCenter,
                      child: Icon(
                        Icons.location_on,
                        color: HomeGlassTheme.bottleGreen,
                        size: 36.sp,
                      ),
                    ),
                  if (userPoint != null)
                    Marker(
                      point: userPoint,
                      width: 36,
                      height: 36,
                      alignment: Alignment.bottomCenter,
                      child: Icon(
                        Icons.location_on,
                        color: const Color(0xFF2563EB),
                        size: 36.sp,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (project == null)
            IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Text(
                  'Select a project',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: HomeGlassTheme.textSecondary,
                  ),
                ),
              ),
            ),
          if (project != null)
            Positioned(
              right: 14.w,
              bottom: 72.h,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                elevation: 3,
                shadowColor: Colors.black26,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _onRecenter,
                  child: Padding(
                    padding: EdgeInsets.all(11.w),
                    child: Icon(
                      Icons.my_location,
                      color: HomeGlassTheme.textPrimary,
                      size: 22.sp,
                    ),
                  ),
                ),
              ),
            ),
          if (project != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _FadedDistanceBanner(
                proximity: proximity,
                distanceText: distanceText,
                isNear: widget.isInsideGeofence,
                hasGps: hasGps,
                routeLoading: widget.routeLoading,
              ),
            ),
        ],
      ),
    );
  }
}

class _FadedDistanceBanner extends StatelessWidget {
  const _FadedDistanceBanner({
    required this.proximity,
    required this.distanceText,
    required this.isNear,
    required this.hasGps,
    required this.routeLoading,
  });

  final String proximity;
  final String distanceText;
  final bool isNear;
  final bool hasGps;
  final bool routeLoading;

  @override
  Widget build(BuildContext context) {
    final accent = isNear && hasGps
        ? HomeGlassTheme.bottleGreen
        : HomeGlassTheme.accentRed;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            proximity,
            style: GoogleFonts.poppins(
              fontSize: 30.sp,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Padding(
            padding: EdgeInsets.only(bottom: 3.h),
            child: Text(
              distanceText,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 6),
                ],
              ),
            ),
          ),
          if (routeLoading) ...[
            SizedBox(width: 8.w),
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
