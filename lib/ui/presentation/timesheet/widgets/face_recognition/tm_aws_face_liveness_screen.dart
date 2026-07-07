import 'dart:io';

import 'package:el_race/core/site_management/face_recognition/antispoof/aws_face_liveness_service.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/aws_liveness_constants.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:face_liveness_detector/face_liveness_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmAwsFaceLivenessResult {
  const TmAwsFaceLivenessResult({
    required this.sessionId,
    required this.confidence,
    required this.live,
  });

  final String sessionId;
  final double confidence;
  final bool live;
}

/// Step 2 — native AWS Amplify Face Liveness + Firebase getSessionResults.
class TmAwsFaceLivenessScreen extends StatefulWidget {
  const TmAwsFaceLivenessScreen({
    super.key,
    this.service,
  });

  final AwsFaceLivenessService? service;

  @override
  State<TmAwsFaceLivenessScreen> createState() => _TmAwsFaceLivenessScreenState();
}

class _TmAwsFaceLivenessScreenState extends State<TmAwsFaceLivenessScreen> {
  final AwsFaceLivenessService _service = AwsFaceLivenessService();

  bool _loadingSession = true;
  String? _error;
  AwsFaceLivenessSession? _session;
  bool _fetchingResults = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() {
          _error =
              'Camera permission is required for AWS Face Liveness. Enable it in Settings.';
          _loadingSession = false;
        });
        return;
      }
    }
    await _startSession();
  }

  Future<void> _startSession() async {
    setState(() {
      _loadingSession = true;
      _error = null;
    });
    try {
      final session = await (widget.service ?? _service).createSession();
      if (!mounted) return;
      setState(() {
        _session = session;
        _loadingSession = false;
      });
    } catch (e, st) {
      debugPrint('AWS createSession error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSession = false;
      });
    }
  }

  Future<void> _onNativeComplete() async {
    final session = _session;
    if (session == null || _fetchingResults) return;

    setState(() => _fetchingResults = true);
    try {
      final AwsFaceLivenessResult results;
      if (session.mockMode) {
        results = await (widget.service ?? _service).getSessionResults(
          session.sessionId,
        );
      } else {
        results = await (widget.service ?? _service).pollSessionResults(
          session.sessionId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        TmAwsFaceLivenessResult(
          sessionId: results.sessionId,
          confidence: results.confidence,
          live: results.live,
        ),
      );
    } catch (e, st) {
      debugPrint('AWS poll results error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _fetchingResults = false;
        _error = 'Could not verify liveness: $e';
      });
    }
  }

  void _onNativeError(dynamic code) {
    debugPrint('FaceLivenessDetector error: $code');
    if (!mounted) return;
    setState(() {
      _error = _livenessErrorMessage(code?.toString() ?? 'error');
    });
  }

  String _livenessErrorMessage(String code) {
    switch (code) {
      case 'accessDenied':
        return 'AWS denied liveness (accessDenied). '
            'Add rekognition:StartFaceLivenessSession to the Cognito '
            'unauthenticated role. Check PoolId in amplifyconfiguration.json.';
      case 'cameraPermissionDenied':
        return 'Camera permission denied for AWS liveness. Enable camera in Settings.';
      case 'sessionNotFound':
        return 'Liveness session expired or not found. Retry from Step 1.';
      case 'sessionTimedOut':
        return 'AWS liveness timed out. Retry with good lighting and hold still in the oval.';
      case 'invalidRegion':
        return 'AWS region mismatch ($code). Session and widget must use ap-south-1.';
      case 'invalidSignature':
        return 'AWS signature invalid — set device date/time to automatic and retry.';
      case 'userCancelled':
        return 'AWS liveness cancelled.';
      case 'error':
      default:
        return 'AWS liveness failed ($code). '
            'Common fixes: PoolId must be ap-south-1:uuid (not ap-south-1:ap-south-1:...), '
            'guest access enabled on Identity Pool, StartFaceLivenessSession on unauth role. '
            'See doc/AWS_COGNITO_AMPLIFY_SETUP.md';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AWS Face Liveness'),
        backgroundColor: TimesheetModuleColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingSession) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Starting secure liveness session…',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _MessagePane(
        icon: PhosphorIcons.warningCircle(),
        title: 'Liveness unavailable',
        message: _error!,
        primaryLabel: 'Retry',
        onPrimary: () {
          setState(() {
            _error = null;
            _loadingSession = true;
          });
          _prepare();
        },
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    final session = _session;
    if (session == null) {
      return const Center(child: Text('No session', style: TextStyle(color: Colors.white)));
    }

    if (_fetchingResults) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Verifying liveness with AWS…',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (session.mockMode) {
      return _MessagePane(
        icon: PhosphorIcons.info(),
        title: 'Development mode',
        message:
            'AWS server credentials are not configured. '
            'Tap below to simulate a passed liveness check.',
        primaryLabel: 'Simulate pass',
        onPrimary: _onNativeComplete,
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return _MessagePane(
        icon: PhosphorIcons.deviceMobile(),
        title: 'Mobile only',
        message: 'AWS Face Liveness requires a physical Android or iOS device.',
        secondaryLabel: 'Go back',
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Follow the oval — move your face naturally. '
            'Region: $kAwsRekognitionRegion',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ),
        Expanded(
          child: FaceLivenessDetector(
            sessionId: session.sessionId,
            region: kAwsRekognitionRegion,
            onComplete: _onNativeComplete,
            onError: _onNativeError,
          ),
        ),
      ],
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
          ),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: TimesheetModuleColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(primaryLabel!),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
