import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Liveness messaging over the capture preview (burst PAD or optional AWS).
class TmLivenessOverlay extends StatelessWidget {
  const TmLivenessOverlay({
    super.key,
    required this.snapshot,
    this.onRetrySpoof,
    this.onStartAws,
  });

  final LivenessGateSnapshot snapshot;
  final VoidCallback? onRetrySpoof;
  final VoidCallback? onStartAws;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DeterrentNotice(),
        if (snapshot.showSpoofWarning) ...[
          const SizedBox(height: 8),
          TmLivenessBlockedBanner(
            message: snapshot.statusMessage,
            onRetry: onRetrySpoof,
          ),
        ] else if (snapshot.needsAwsStep) ...[
          const SizedBox(height: 8),
          _AwsBanner(
            message: snapshot.statusMessage,
            onStart: onStartAws,
          ),
        ] else if (snapshot.isVerifying) ...[
          const SizedBox(height: 8),
          _VerifyingBanner(message: snapshot.statusMessage),
        ] else if (snapshot.phase == LivenessGatePhase.onDeviceRunning ||
            snapshot.phase == LivenessGatePhase.awsRunning) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: PhosphorIcons.shieldCheck(),
            message: snapshot.statusMessage,
          ),
        ] else if (snapshot.phase == LivenessGatePhase.fullyPassed) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: PhosphorIcons.checkCircle(),
            message: snapshot.statusMessage,
          ),
        ] else ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: PhosphorIcons.userFocus(),
            message: snapshot.statusMessage,
          ),
        ],
      ],
    );
  }
}

class _DeterrentNotice extends StatelessWidget {
  const _DeterrentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Live face verification on every check-in. '
        'Photos and screen replays are blocked.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.3,
            ),
      ),
    );
  }
}

class _VerifyingBanner extends StatelessWidget {
  const _VerifyingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class TmLivenessBlockedBanner extends StatelessWidget {
  const TmLivenessBlockedBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.danger.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.warningCircle(), color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check-in blocked',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  height: 1.35,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AwsBanner extends StatelessWidget {
  const _AwsBanner({required this.message, this.onStart});

  final String message;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (onStart != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onStart,
              style: TextButton.styleFrom(
                foregroundColor: TimesheetModuleColors.primary,
                backgroundColor: Colors.white,
              ),
              child: const Text('Start AWS Face Liveness'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
