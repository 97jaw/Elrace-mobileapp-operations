import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_site_location_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Mini map card (same footprint as a home stat card): non-interactive map at
/// the foreman's GPS, label for resolved / not-located site, reload + tap.
class TmForemanSiteLocationCard extends StatelessWidget {
  const TmForemanSiteLocationCard({
    super.key,
    required this.location,
    required this.loading,
    required this.onReload,
    required this.onOpen,
    this.minHeight = 118,
  });

  final TmForemanSiteLocation? location;
  final bool loading;
  final VoidCallback onReload;
  final VoidCallback onOpen;
  final double minHeight;

  static const _warn = Color(0xFFE6A700);
  static const _card = TimesheetModuleColors.glassSurface;
  static const _border = Color(0xFFE4DCCB);
  static const _ink = Color(0xFF2A2A2A);
  static const _orange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final located = location?.isLocated == true;
    final projectTitle = located
        ? (location!.matched!.name)
        : null;
    final label = located ? 'You are here' : 'Project not located';
    final position = location?.position;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: minHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (position != null)
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          position.latitude,
                          position.longitude,
                        ),
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        AppMapTiles.streets(),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                position.latitude,
                                position.longitude,
                              ),
                              width: 28,
                              height: 28,
                              child: Icon(
                                Icons.my_location,
                                size: 22,
                                color: located ? _orange : _warn,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    ColoredBox(
                      color: TimesheetModuleColors.bgGradientEnd,
                      child: Center(
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: _orange,
                                ),
                              )
                            : Icon(
                                PhosphorIcons.mapTrifold(),
                                size: 28,
                                color: TimesheetModuleColors.warmMuted,
                              ),
                      ),
                    ),
                  // Scrim so labels stay readable over tiles.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x00000000),
                          Color(0x99000000),
                        ],
                        stops: [0, 0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Icon(
                        located
                            ? PhosphorIcons.mapPin(PhosphorIconsStyle.fill)
                            : PhosphorIcons.warning(PhosphorIconsStyle.fill),
                        size: 18,
                        color: located ? _orange : _warn,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 40,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (projectTitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            projectTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: loading ? null : onReload,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(
                            child: loading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: _ink,
                                    ),
                                  )
                                : Icon(
                                    PhosphorIcons.arrowClockwise(),
                                    size: 16,
                                    color: _ink,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
