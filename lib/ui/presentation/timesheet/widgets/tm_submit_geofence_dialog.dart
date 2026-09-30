import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/core/widgets/map/app_map_tiles.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_employee_avatar.dart';
import 'package:el_race/ui/presentation/home_screen/repository/location_reop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Default when Odoo `project.threshold` can't be read.
const double kTmDefaultSubmitThresholdM = 800;

/// Confirm & submit gate: the foreman must be within the project threshold
/// (Odoo `project.threshold`, all sides) of the site coordinates. Outside →
/// "Submission failed" and the record is **not** created. Inside → the
/// record is created and the popup reports the real server result.
abstract final class TmSubmitGeofenceGate {
  /// Resolves true only when the timesheet was actually created.
  static Future<bool> run(
    BuildContext context, {
    required Project project,
    required Future<double?> Function() loadThresholdM,
    required Future<TimesheetSubmitResult> Function() submit,
  }) async {
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Submission',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _TmSubmitGeofenceDialog(
        project: project,
        loadThresholdM: loadThresholdM,
        submit: submit,
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curved),
              child: child),
        );
      },
    );
    return ok ?? false;
  }
}

enum _Stage { locating, submitting, success, outside, noLocation, serverFailed }

class _TmSubmitGeofenceDialog extends StatefulWidget {
  const _TmSubmitGeofenceDialog({
    required this.project,
    required this.loadThresholdM,
    required this.submit,
  });

  final Project project;
  final Future<double?> Function() loadThresholdM;
  final Future<TimesheetSubmitResult> Function() submit;

  @override
  State<_TmSubmitGeofenceDialog> createState() =>
      _TmSubmitGeofenceDialogState();
}

class _TmSubmitGeofenceDialogState extends State<_TmSubmitGeofenceDialog> {
  static const _green = Color(0xFF2E9E5B);

  _Stage _stage = _Stage.locating;
  double _thresholdM = kTmDefaultSubmitThresholdM;
  Position? _position;
  double? _distanceM;
  String? _serverMessage;
  Timer? _autoClose;

  LatLng get _site =>
      LatLng(widget.project.geofenceLat, widget.project.geofenceLon);

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    final results = await Future.wait<Object?>([
      widget.loadThresholdM().catchError((_) => null),
      LocationRepo()
          .getCurrentLocation(timeLimit: const Duration(seconds: 12))
          .then<Position?>((p) => p)
          .catchError((_) => null),
    ]);
    if (!mounted) return;
    final threshold = results[0] as double?;
    final position = results[1] as Position?;
    _thresholdM = threshold != null && threshold > 0
        ? threshold
        : kTmDefaultSubmitThresholdM;

    if (position == null) {
      setState(() => _stage = _Stage.noLocation);
      return;
    }
    final distance = const TimesheetGeofenceService().distanceMeters(
      TimesheetGeoPoint(lat: position.latitude, lon: position.longitude),
      TimesheetGeoPoint(
        lat: widget.project.geofenceLat,
        lon: widget.project.geofenceLon,
      ),
    );
    debugPrint(
      'SubmitGeofence: project=${widget.project.id} distance='
      '${distance.toStringAsFixed(0)}m threshold=${_thresholdM.toStringAsFixed(0)}m',
    );
    setState(() {
      _position = position;
      _distanceM = distance;
      _stage = distance <= _thresholdM ? _Stage.submitting : _Stage.outside;
    });
    if (_stage != _Stage.submitting) return;

    TimesheetSubmitResult result;
    try {
      result = await widget.submit();
    } catch (e) {
      result = TimesheetSubmitResult(success: false, message: '$e');
    }
    if (!mounted) return;
    setState(() {
      _serverMessage = result.message;
      _stage = result.success ? _Stage.success : _Stage.serverFailed;
    });
    if (result.success) {
      _autoClose = Timer(const Duration(milliseconds: 2200), _close);
    }
  }

  void _close() {
    if (!mounted) return;
    _autoClose?.cancel();
    Navigator.of(context).pop(_stage == _Stage.success);
  }

  bool get _busy => _stage == _Stage.locating || _stage == _Stage.submitting;
  bool get _failed =>
      _stage == _Stage.outside ||
      _stage == _Stage.noLocation ||
      _stage == _Stage.serverFailed;

  String get _title => switch (_stage) {
        _Stage.locating => 'Checking your location…',
        _Stage.submitting => 'Submitting…',
        _Stage.success => 'Submission success',
        _ => 'Submission failed',
      };

  String get _detail {
    final limit = _formatDistance(_thresholdM);
    final d = _distanceM;
    return switch (_stage) {
      _Stage.locating => 'Verifying you are within $limit of the site',
      _Stage.submitting =>
        'You are ${_formatDistance(d ?? 0)} from site — within $limit',
      _Stage.success => _serverMessage?.trim().isNotEmpty == true
          ? _serverMessage!.trim()
          : 'Timesheet recorded for ${widget.project.name}',
      _Stage.outside =>
        'You are ${_formatDistance(d ?? 0)} from the site. You must be within '
            '$limit to submit. Nothing was submitted.',
      _Stage.noLocation =>
        "Couldn't get your current location. Turn on location and try again. "
            'Nothing was submitted.',
      _Stage.serverFailed => _serverMessage?.trim().isNotEmpty == true
          ? _serverMessage!.trim()
          : 'The server rejected the submission.',
    };
  }

  static String _formatDistance(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km'
      : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final accent = _failed
        ? TimesheetModuleColors.danger
        : _stage == _Stage.success
            ? _green
            : TimesheetModuleColors.accent;
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
                      color: accent.withValues(alpha: 0.55), width: 1.5),
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
                    _header(accent),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(height: mapHeight, child: _map(accent)),
                    ),
                    const SizedBox(height: 12),
                    _legend(accent),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _close,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _failed ? TimesheetModuleColors.ink : _green,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : _failed
                                  ? 'Close'
                                  : 'Done',
                          style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _header(Color accent) {
    final icon = _busy
        ? SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: accent),
          )
        : Icon(
            _failed
                ? PhosphorIcons.xCircle(PhosphorIconsStyle.fill)
                : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: accent,
            size: 30,
          );
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
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TimesheetModuleTypography.h2().copyWith(
                  color: _failed
                      ? TimesheetModuleColors.danger
                      : TimesheetModuleColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _detail,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.warmMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _map(Color accent) {
    final position = _position;
    final user =
        position == null ? null : LatLng(position.latitude, position.longitude);
    final fence = _failed && _stage != _Stage.serverFailed
        ? TimesheetModuleColors.danger
        : _green;
    const distance = Distance();
    final boundsPoints = <LatLng>[
      for (final bearing in const [0.0, 90.0, 180.0, 270.0])
        distance.offset(_site, _thresholdM, bearing),
      if (user != null) user,
    ];
    return FlutterMap(
      key: ValueKey('fit-${user?.latitude}-${user?.longitude}-$_thresholdM'),
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
        CircleLayer(
          circles: [
            CircleMarker(
              point: _site,
              radius: _thresholdM,
              useRadiusInMeter: true,
              color: fence.withValues(alpha: 0.14),
              borderColor: fence.withValues(alpha: 0.85),
              borderStrokeWidth: 2.5,
            ),
          ],
        ),
        if (user != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [user, _site],
                color: accent.withValues(alpha: 0.7),
                strokeWidth: 2.5,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _site,
              width: 36,
              height: 36,
              alignment: Alignment.bottomCenter,
              child: Icon(
                Icons.location_on,
                color: fence,
                size: 36,
              ),
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

  Widget _legend(Color accent) {
    final d = _distanceM;
    return Row(
      children: [
        Icon(PhosphorIcons.buildings(),
            size: 16, color: TimesheetModuleColors.warmMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (d != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_formatDistance(d)} / ${_formatDistance(_thresholdM)}',
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
