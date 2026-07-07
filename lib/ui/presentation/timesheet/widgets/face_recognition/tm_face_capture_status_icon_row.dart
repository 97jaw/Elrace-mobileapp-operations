import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Compact one-row status: liveness · embedding · face DB · geofence.
class TmFaceCaptureStatusIconRow extends StatelessWidget {
  const TmFaceCaptureStatusIconRow({
    super.key,
    required this.embeddingOn,
    required this.faceDbReady,
    required this.geofenceOk,
    this.canCapture = false,
    this.faceDbTemplateCount,
    this.onRefreshFaceDb,
    this.refreshingFaceDb = false,
    this.livenessPhase = LivenessGatePhase.idle,
    this.livenessMessage,
    this.onRetryLiveness,
  });

  final bool embeddingOn;
  final bool faceDbReady;
  final bool geofenceOk;
  final bool canCapture;
  final int? faceDbTemplateCount;
  final VoidCallback? onRefreshFaceDb;
  final bool refreshingFaceDb;
  final LivenessGatePhase livenessPhase;
  final String? livenessMessage;
  final VoidCallback? onRetryLiveness;

  static const Color _ok = Color(0xFF3DDC84);
  static const Color _warn = Color(0xFFFFB74D);
  static const Color _danger = Color(0xFFE57373);
  static const Color _idleColor = Color(0xFFB0BEC5);

  String get _faceDbTooltip {
    final count = faceDbTemplateCount;
    final countSuffix = count != null && count > 0 ? ' · $count templates' : '';
    if (faceDbReady) {
      return 'Face DB ready$countSuffix · tap ↻ to reload from server';
    }
    return 'Face DB unavailable$countSuffix · tap ↻ to sync';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LivenessStatusDot(
          phase: livenessPhase,
          message: livenessMessage,
          onRetry: onRetryLiveness,
        ),
        const SizedBox(width: 14),
        _StatusDot(
          icon: PhosphorIcons.fingerprint(PhosphorIconsStyle.fill),
          active: embeddingOn,
          tooltip: embeddingOn ? 'Embedding match on' : 'Embedding match off',
          accent: _ok,
        ),
        const SizedBox(width: 14),
        _FaceDbStatusCluster(
          active: faceDbReady,
          tooltip: _faceDbTooltip,
          onRefresh: onRefreshFaceDb,
          refreshing: refreshingFaceDb,
        ),
        const SizedBox(width: 14),
        _StatusDot(
          icon: PhosphorIcons.mapPin(),
          active: geofenceOk,
          tooltip: geofenceOk ? 'Inside geofence' : 'Outside geofence',
          accent: canCapture && geofenceOk ? _ok : _warn,
        ),
      ],
    );
  }
}

class _LivenessStatusDot extends StatelessWidget {
  const _LivenessStatusDot({
    required this.phase,
    this.message,
    this.onRetry,
  });

  final LivenessGatePhase phase;
  final String? message;
  final VoidCallback? onRetry;

  bool get _isBlocked =>
      phase == LivenessGatePhase.blocked ||
      phase == LivenessGatePhase.onDeviceSpoof;

  bool get _isVerifying => phase == LivenessGatePhase.verifying;

  bool get _isPassed => phase == LivenessGatePhase.fullyPassed;

  String get _tooltip {
    if (message != null && message!.trim().isNotEmpty) return message!.trim();
    if (_isPassed) return 'Liveness verified';
    if (_isVerifying) return 'Verifying liveness…';
    if (_isBlocked) return 'Liveness blocked — tap to retry';
    return 'Center face to verify';
  }

  Color get _accent {
    if (_isPassed) return TmFaceCaptureStatusIconRow._ok;
    if (_isBlocked) return TmFaceCaptureStatusIconRow._danger;
    if (_isVerifying) return Colors.white;
    return TmFaceCaptureStatusIconRow._idleColor;
  }

  @override
  Widget build(BuildContext context) {
    final child = _isVerifying
        ? const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(
            _isPassed
                ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                : (_isBlocked
                    ? PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.shieldCheck()),
            size: 18,
            color: _accent,
          );

    final dot = Tooltip(
      message: _tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: _isPassed || _isBlocked || _isVerifying
                ? _accent.withValues(alpha: 0.85)
                : TmFaceCaptureStatusIconRow._idleColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );

    if (_isBlocked && onRetry != null) {
      return GestureDetector(onTap: onRetry, child: dot);
    }
    return dot;
  }
}

class _FaceDbStatusCluster extends StatelessWidget {
  const _FaceDbStatusCluster({
    required this.active,
    required this.tooltip,
    this.onRefresh,
    this.refreshing = false,
  });

  final bool active;
  final String tooltip;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _StatusDot(
          icon: PhosphorIcons.database(),
          active: active,
          tooltip: tooltip,
          accent: TmFaceCaptureStatusIconRow._ok,
        ),
        if (onRefresh != null)
          Positioned(
            right: -5,
            bottom: -5,
            child: _FaceDbRefreshButton(
              onPressed: refreshing ? null : onRefresh,
              refreshing: refreshing,
            ),
          ),
      ],
    );
  }
}

class _FaceDbRefreshButton extends StatelessWidget {
  const _FaceDbRefreshButton({
    required this.onPressed,
    required this.refreshing,
  });

  final VoidCallback? onPressed;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: refreshing ? 'Syncing face DB…' : 'Reload face DB from server',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TmFaceCaptureStatusIconRow._ok,
              border: Border.all(color: Colors.black87, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: refreshing
                ? const Padding(
                    padding: EdgeInsets.all(3),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                    size: 11,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.accent,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = active ? accent : TmFaceCaptureStatusIconRow._idleColor;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: active
                ? fg.withValues(alpha: 0.85)
                : TmFaceCaptureStatusIconRow._idleColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}
