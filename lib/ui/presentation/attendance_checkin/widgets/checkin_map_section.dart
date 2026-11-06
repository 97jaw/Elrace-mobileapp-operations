import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_distance_formatter.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_geofence_ring.dart';
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
    this.bottomOverlayPadding = 0,
    this.topOverlayPadding = 0,
  });

  final Position? userPosition;
  final CheckinAllowedProject? selectedProject;
  final bool isInsideGeofence;
  final double? distanceMeters;
  final List<LatLng> routePoints;
  final bool routeLoading;

  /// Space reserved for the bottom sheet so recenter sits above it.
  final double bottomOverlayPadding;

  /// Space reserved for back/search + project banner above the zone.
  final double topOverlayPadding;

  @override
  State<CheckinMapSection> createState() => _CheckinMapSectionState();
}

class _CheckinMapSectionState extends State<CheckinMapSection>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  int? _lastProjectId;
  bool _mapReady = false;

  @override
  bool get wantKeepAlive => true;

  LatLng get _mapCenter {
    final project = widget.selectedProject;
    if (project != null && project.hasCoordinates) {
      return LatLng(project.lat, project.lng);
    }
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
      _fitGeofenceExpanded();
    } else if (oldWidget.bottomOverlayPadding != widget.bottomOverlayPadding ||
        oldWidget.topOverlayPadding != widget.topOverlayPadding) {
      // Sheet / banner insets settled — re-fit so the zone stays ~75% wide.
      if (widget.selectedProject?.hasCoordinates == true) {
        _fitGeofenceExpanded();
      }
    }
  }

  void _onMapReady() {
    _mapReady = true;
    _lastProjectId = widget.selectedProject?.projectId;
    if (widget.selectedProject != null &&
        widget.selectedProject!.hasCoordinates) {
      _fitGeofenceExpanded();
    } else if (widget.userPosition != null) {
      _centerOnUser();
    }
  }

  /// Fit the geofence so the circle fills ~45–55% of the map width.
  void _fitGeofenceExpanded() {
    final project = widget.selectedProject;
    if (project == null || !project.hasCoordinates || !_mapReady) return;

    final center = LatLng(project.lat, project.lng);
    final ring = CheckinGeofenceRing.circlePoints(
      center: center,
      radiusM: project.geofenceRadiusM,
      segments: 64,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final mapWidth = MediaQuery.sizeOf(context).width;
      // ~25% pad each side → circle diameter ≈ 50% of map width.
      final sidePad = mapWidth * 0.25;
      final topPad = math.max(88.h, widget.topOverlayPadding + 12.h);
      final bottomPad = math.max(88.h, widget.bottomOverlayPadding + 28.h);
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: ring,
          padding: EdgeInsets.fromLTRB(sidePad, topPad, sidePad, bottomPad),
          maxZoom: 18,
        ),
      );
    });
  }

  void _centerOnUser() {
    final user = widget.userPosition;
    if (user == null || !_mapReady) return;
    final point = LatLng(user.latitude, user.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, 15);
    });
  }

  void _onRecenter() {
    final project = widget.selectedProject;
    if (!_mapReady) return;

    if (project != null && project.hasCoordinates) {
      _fitGeofenceExpanded();
      return;
    }
    _centerOnUser();
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
    final hasProjectCoords = project != null && project.hasCoordinates;
    final center = _mapCenter;

    final projectPoint =
        hasProjectCoords ? LatLng(project.lat, project.lng) : null;
    final userPoint =
        user != null ? LatLng(user.latitude, user.longitude) : null;
    const radiusColor = HomeGlassTheme.bottleGreen;

    final routePoints = projectPoint != null && widget.routePoints.length >= 2
        ? widget.routePoints
        : (userPoint != null && projectPoint != null
            ? [userPoint, projectPoint]
            : <LatLng>[]);

    final dashed = projectPoint != null
        ? CheckinGeofenceRing.dashedSegments(
            center: projectPoint,
            radiusM: project!.geofenceRadiusM,
          )
        : const <List<LatLng>>[];

    final awayText =
        CheckinDistanceFormatter.formatAway(widget.distanceMeters);
    final radiusLabel = project != null
        ? 'Allowed Zone ${project.geofenceRadiusM.round()} m'
        : '';
    final northEdge = projectPoint != null
        ? CheckinGeofenceRing.northEdge(
            center: projectPoint,
            radiusM: project!.geofenceRadiusM,
          )
        : null;

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
                      color: radiusColor.withValues(alpha: 0.13),
                      borderColor: Colors.transparent,
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              if (dashed.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final segment in dashed)
                      Polyline(
                        points: segment,
                        color: radiusColor.withValues(alpha: 0.9),
                        strokeWidth: 2.5,
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
                  if (northEdge != null)
                    Marker(
                      point: northEdge,
                      width: 150.w,
                      height: 36.h,
                      alignment: Alignment.bottomCenter,
                      child: _AllowedZonePill(label: radiusLabel),
                    ),
                  if (projectPoint != null)
                    Marker(
                      point: projectPoint,
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.location_on,
                        color: HomeGlassTheme.bottleGreen,
                        size: 28.sp,
                      ),
                    ),
                  if (userPoint != null) ...[
                    Marker(
                      point: userPoint,
                      width: 40.w,
                      height: 40.w,
                      alignment: Alignment.center,
                      child: _UserDot(headingDegrees: user!.heading),
                    ),
                    if (hasProjectCoords)
                      Marker(
                        point: userPoint,
                        width: 110.w,
                        height: 28.h,
                        alignment: const Alignment(0, 1.8),
                        child: _AwayPill(label: awayText),
                      ),
                  ],
                ],
              ),
            ],
          ),
          Positioned(
            right: 14.w,
            bottom: math.max(16.h, widget.bottomOverlayPadding + 12.h),
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
        ],
      ),
    );
  }
}

class _AllowedZonePill extends StatelessWidget {
  const _AllowedZonePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: HomeGlassTheme.bottleGreen,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          width: 6.w,
          height: 6.w,
          decoration: const BoxDecoration(
            color: HomeGlassTheme.bottleGreen,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _AwayPill extends StatelessWidget {
  const _AwayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: HomeGlassTheme.textPrimary,
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.headingDegrees});

  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    final hasHeading =
        !headingDegrees.isNaN && headingDegrees >= 0 && headingDegrees <= 360;

    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasHeading)
            Transform.rotate(
              angle: headingDegrees * math.pi / 180,
              child: CustomPaint(
                size: Size(36.w, 36.w),
                painter: _HeadingConePainter(),
              ),
            ),
          Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * 0.72, size.height * 0.42)
      ..lineTo(size.width * 0.28, size.height * 0.42)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
