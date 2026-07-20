import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Monitoring tab: construction camera card + location map.
class SmMonitoringTab extends StatefulWidget {
  const SmMonitoringTab({super.key, required this.project});

  final ProjectModel project;

  @override
  State<SmMonitoringTab> createState() => _SmMonitoringTabState();
}

class _SmMonitoringTabState extends State<SmMonitoringTab> {
  bool _videoMode = false;

  /// UAE geographic center used when a project has no coordinates.
  static const LatLng _uaeFallback = LatLng(24.4539, 54.3773);

  LatLng get _center {
    final lat = widget.project.latitude;
    final lng = widget.project.longitude;
    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      return LatLng(lat, lng);
    }
    return _uaeFallback;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _cameraCard(),
        const SizedBox(height: TimesheetModuleLayout.sectionGap),
        _locationCard(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _cameraCard() {
    return Container(
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: smGlassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmSectionHeader(
            title: 'Construction camera',
            subtitle: 'Live site view',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _cameraFrame(fullscreen: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraFrame({required bool fullscreen}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder site feed image (real CCTV feed to be wired later).
        const Image(
          image: AssetImage('assets/newapp/site_monitor_camera.png'),
          fit: BoxFit.cover,
        ),
        // Live badge.
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5A5A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Photo / video toggle.
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            children: [
              _iconButton(
                icon: PhosphorIcons.camera(),
                active: !_videoMode,
                onTap: () => setState(() => _videoMode = false),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: PhosphorIcons.videoCamera(),
                active: _videoMode,
                onTap: () => setState(() => _videoMode = true),
              ),
            ],
          ),
        ),
        // Fullscreen expand.
        Positioned(
          bottom: 10,
          right: 10,
          child: _iconButton(
            icon: fullscreen
                ? PhosphorIcons.arrowsIn()
                : PhosphorIcons.arrowsOut(),
            active: false,
            onTap: () {
              if (fullscreen) {
                Navigator.of(context).maybePop();
              } else {
                _openFullscreen();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active
              ? TimesheetModuleColors.accent
              : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _cameraFrame(fullscreen: true),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: smGlassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmSectionHeader(
            title: 'Location',
            subtitle: widget.project.cityName?.isNotEmpty == true
                ? widget.project.cityName
                : 'Project site',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 14,
                ),
                children: [
                  AppMapTiles.streets(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 46,
                        height: 46,
                        child: Icon(
                          PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          color: TimesheetModuleColors.accent,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
