import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

extension TimesheetProjectCoordinates on Project {
  bool get hasSiteCoordinates =>
      geofenceLat.abs() > 1e-6 &&
      geofenceLon.abs() > 1e-6 &&
      geofenceLat >= -90 &&
      geofenceLat <= 90 &&
      geofenceLon >= -180 &&
      geofenceLon <= 180;

  LatLng get siteLatLng => LatLng(geofenceLat, geofenceLon);
}

/// Map preview + full-screen popup (directions + share location).
class TmProjectLocationSection extends StatelessWidget {
  const TmProjectLocationSection({
    super.key,
    required this.project,
    this.expand = false,
  });

  final Project project;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (!project.hasSiteCoordinates) {
      final placeholder = DecoratedBox(
        decoration: BoxDecoration(
          color: TimesheetModuleColors.bgGradientEnd,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          border: Border.all(color: TimesheetModuleColors.divider),
        ),
        child: Center(
          child: Text(
            'No coordinates set',
            style: TimesheetModuleTypography.body().copyWith(
              color: TimesheetModuleColors.mutedText.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      if (expand) {
        return Expanded(
          child: SizedBox(
            width: double.infinity,
            child: placeholder,
          ),
        );
      }
      return SizedBox(height: 120, width: double.infinity, child: placeholder);
    }

    final point = project.siteLatLng;
    final mapStack = Stack(
      fit: StackFit.expand,
      children: _mapStackChildren(point),
    );
    final mapPreview = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        onTap: () => _openMapPopup(context, project),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          child: expand
              ? mapStack
              : SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: mapStack,
                ),
        ),
      ),
    );
    if (expand) {
      return Expanded(child: mapPreview);
    }
    return mapPreview;
  }

  List<Widget> _mapStackChildren(LatLng point) {
    return [
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  AppMapTiles.basic(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 36,
                        height: 36,
                        child: Icon(
                          PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          color: TimesheetModuleColors.primary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TimesheetModuleColors.surface
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.mapTrifold(),
                        size: 16,
                        color: TimesheetModuleColors.navy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to open map',
                        style: TimesheetModuleTypography.caption().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    ];
  }

  static Future<void> _openMapPopup(BuildContext context, Project project) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimesheetModuleColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProjectMapPopup(project: project),
    );
  }
}

class _ProjectMapPopup extends StatefulWidget {
  const _ProjectMapPopup({required this.project});

  final Project project;

  @override
  State<_ProjectMapPopup> createState() => _ProjectMapPopupState();
}

class _ProjectMapPopupState extends State<_ProjectMapPopup> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserLocation();
      _fitCamera();
    });
  }

  Future<void> _loadUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _locating = false;
      });
      _fitCamera();
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fitCamera() {
    final site = widget.project.siteLatLng;
    final points = <LatLng>[site];
    if (_userLocation != null) points.add(_userLocation!);
    if (points.length == 1) {
      _mapController.move(site, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Future<void> _openDirections() async {
    final site = widget.project.siteLatLng;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${site.latitude},${site.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareLocation() async {
    final site = widget.project.siteLatLng;
    final link =
        'https://www.google.com/maps?q=${site.latitude},${site.longitude}';
    await SharePlus.instance.share(
      ShareParams(
        text: '${widget.project.name}\n$link',
        subject: widget.project.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.project.siteLatLng;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.h2(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(PhosphorIcons.x()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openDirections,
                      icon: Icon(PhosphorIcons.navigationArrow()),
                      label: const Text('Directions'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareLocation,
                      icon: Icon(PhosphorIcons.shareNetwork()),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: site,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      AppMapTiles.basic(),
                      if (widget.project.geofenceRadiusM > 0)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: site,
                              radius: widget.project.geofenceRadiusM,
                              useRadiusInMeter: true,
                              color: TimesheetModuleColors.primary
                                  .withValues(alpha: 0.12),
                              borderColor: TimesheetModuleColors.primary,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: site,
                            width: 40,
                            height: 40,
                            child: Icon(
                              PhosphorIcons.flagBanner(PhosphorIconsStyle.fill),
                              color: TimesheetModuleColors.primary,
                              size: 34,
                            ),
                          ),
                          if (_userLocation != null)
                            Marker(
                              point: _userLocation!,
                              width: 36,
                              height: 36,
                              child: Icon(
                                PhosphorIcons.navigationArrow(
                                  PhosphorIconsStyle.fill,
                                ),
                                color: TimesheetModuleColors.navy,
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_locating)
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
