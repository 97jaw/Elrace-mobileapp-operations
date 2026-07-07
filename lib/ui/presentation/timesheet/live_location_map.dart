import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LiveLocationMap extends ConsumerStatefulWidget {
  const LiveLocationMap({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  ConsumerState<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends ConsumerState<LiveLocationMap> {
  bool _sharingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(timesheetProjectProvider(widget.projectId));

    return TmScaffold(
      appBar: AppBar(
        title: Text('Live Site Map', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: projectAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) => const TimesheetErrorState(
          message: 'Could not load live map',
        ),
        data: (project) {
          final center = LatLng(project.geofenceLat, project.geofenceLon);
          final workers = [
            center,
            LatLng(center.latitude + 0.0012, center.longitude - 0.001),
            LatLng(center.latitude - 0.0009, center.longitude + 0.0013),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface,
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  boxShadow: TimesheetModuleShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.broadcast(),
                      color: TimesheetModuleColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Foreman live location sharing',
                        style: TimesheetModuleTypography.body(),
                      ),
                    ),
                    Switch(
                      value: _sharingEnabled,
                      activeThumbColor: TimesheetModuleColors.primary,
                      onChanged: (value) =>
                          setState(() => _sharingEnabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusLg,
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.elrace.app',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: center,
                            radius: project.geofenceRadiusM,
                            useRadiusInMeter: true,
                            color: TimesheetModuleColors.primary
                                .withValues(alpha: 0.12),
                            borderStrokeWidth: 2,
                            borderColor: TimesheetModuleColors.primary,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 46,
                            height: 46,
                            child: Icon(
                              PhosphorIcons.flagBanner(),
                              color: TimesheetModuleColors.primary,
                              size: 38,
                            ),
                          ),
                          for (final worker in workers)
                            Marker(
                              point: worker,
                              width: 42,
                              height: 42,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: TimesheetModuleColors.navy,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.hardHat(),
                                  color: TimesheetModuleColors.surface,
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
