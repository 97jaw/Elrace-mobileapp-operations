import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class FaceCaptureSandbox extends StatefulWidget {
  const FaceCaptureSandbox({super.key});

  @override
  State<FaceCaptureSandbox> createState() => _FaceCaptureSandboxState();
}

class _FaceCaptureSandboxState extends State<FaceCaptureSandbox> {
  final TimesheetFaceCaptureService _service = TimesheetFaceCaptureService();
  TimesheetFaceDetectionResult? _result;
  String _permissionLabel = 'Not requested';

  @override
  void initState() {
    super.initState();
    _result = _service.createMockPassResult();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return TmScaffold(
      appBar: AppBar(
        title: Text('F.7 Face Capture', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.navy,
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusLg,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      PhosphorIcons.userFocus(),
                      color: TimesheetModuleColors.surface.withValues(
                        alpha: 0.34,
                      ),
                      size: 96,
                    ),
                  ),
                  if (result != null)
                    for (final box in result.faceBoxes)
                      Positioned(
                        left: box.left,
                        top: box.top,
                        width: box.width,
                        height: box.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: TimesheetModuleColors.success,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                  Positioned(
                    left: TimesheetModuleLayout.cardPadding,
                    right: TimesheetModuleLayout.cardPadding,
                    bottom: TimesheetModuleLayout.cardPadding,
                    child: Text(
                      result?.quality.message ?? 'Ready',
                      textAlign: TextAlign.center,
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'Permissions: $_permissionLabel',
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          Text(
            'Mock crop target: ${TimesheetFaceCaptureService.cropSizePx} x ${TimesheetFaceCaptureService.cropSizePx}',
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Row(
            children: [
              Expanded(
                child: TmSecondaryButton(
                  label: 'Permissions',
                  icon: PhosphorIcons.lockKey(),
                  onPressed: _requestPermissions,
                ),
              ),
              const SizedBox(width: TimesheetModuleLayout.cardSpacing),
              Expanded(
                child: TmPrimaryButton(
                  label: 'Shutter',
                  icon: PhosphorIcons.camera(),
                  onPressed: () => setState(
                    () => _result = _service.createMockPassResult(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final permissions = await _service.requestCameraPermissions();
    if (!mounted) return;
    setState(() {
      _permissionLabel = permissions.canOpenCamera
          ? 'Camera + location granted'
          : 'Camera/location permission needed';
    });
  }
}
