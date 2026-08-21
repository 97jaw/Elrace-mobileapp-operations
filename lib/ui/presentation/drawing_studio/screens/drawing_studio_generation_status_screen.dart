import 'dart:async';

import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Polls `GET /projects/{id}` every ~2.5s; shows server `progress` until done.
class DrawingStudioGenerationStatusScreen extends StatefulWidget {
  const DrawingStudioGenerationStatusScreen({
    super.key,
    required this.projectId,
    this.title,
    this.initialProgress,
  });

  final String projectId;
  final String? title;
  final DrawingStudioProgress? initialProgress;

  @override
  State<DrawingStudioGenerationStatusScreen> createState() =>
      _DrawingStudioGenerationStatusScreenState();
}

class _DrawingStudioGenerationStatusScreenState
    extends State<DrawingStudioGenerationStatusScreen> {
  final _api = DrawingStudioApiClient();
  Timer? _timer;
  bool _pollInFlight = false;

  String _status = 'processing';
  String? _error;
  DrawingStudioProject? _project;
  DrawingStudioProgress? _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _poll();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final project = await _api.getProject(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _status = project.status;
        if (project.progress != null) {
          _progress = project.progress;
        }
        _error = null;
      });

      final lower = project.status.toLowerCase();
      if (lower == 'completed') {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          DrawingStudioRouteNames.projectDetail,
          arguments: project,
        );
      } else if (lower == 'failed') {
        _timer?.cancel();
        setState(
          () => _error = 'Generation failed. You can retry from the form.',
        );
      }
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to refresh status.');
    } finally {
      _pollInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? _project?.title ?? 'Generating';
    final processing = _status.toLowerCase() == 'processing' ||
        _status.toLowerCase() == 'pending' ||
        _status.toLowerCase() == 'in_progress';
    final progress = _progress;
    // Only use server percent — never invent a fake value.
    final hasPercent = progress != null;
    final percent = progress?.percent ?? 0;
    final barValue = hasPercent ? (percent / 100.0).clamp(0.0, 1.0) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          const DrawingStudioChromeHeader(),
          DrawingStudioHeadingCard(title: title),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.uh, 20.w, 28.uh),
              children: [
                if (processing) ...[
                  Container(
                    padding: EdgeInsets.fromLTRB(16.w, 18.uh, 16.w, 18.uh),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.ur),
                      border: Border.all(color: const Color(0xFFE4E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Now building…',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.usp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7A849C),
                                ),
                              ),
                            ),
                            if (hasPercent)
                              Text(
                                '$percent%',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.usp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A2A4F),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8.uh),
                        Text(
                          progress?.nowBuildingLabel ??
                              'Creating your drawing package…',
                          style: GoogleFonts.poppins(
                            fontSize: 15.usp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A2A4F),
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 14.uh),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.ur),
                          child: LinearProgressIndicator(
                            value: barValue,
                            minHeight: 10.uh,
                            backgroundColor: const Color(0xFFE8ECF3),
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(height: 8.uh),
                        Text(
                          'This can take several minutes. We’ll open the folder when ready.',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5.usp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9AA5B5),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (progress != null && progress.completed.isNotEmpty) ...[
                    SizedBox(height: 18.uh),
                    Text('Done', style: _sectionTitle),
                    SizedBox(height: 8.uh),
                    ...progress.completed.map(
                      (step) => _StepRow(
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF0D9488),
                        label: step.label,
                        muted: true,
                      ),
                    ),
                  ],
                  if (progress != null && progress.queue.isNotEmpty) ...[
                    SizedBox(height: 18.uh),
                    Text('Upcoming', style: _sectionTitle),
                    SizedBox(height: 8.uh),
                    ...progress.queue.map(
                      (step) => _StepRow(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFF9AA5B5),
                        label: step.label,
                      ),
                    ),
                  ],
                ] else if (_error != null) ...[
                  SizedBox(height: 40.uh),
                  Icon(
                    Icons.error_outline_rounded,
                    size: 42.usp,
                    color: const Color(0xFFE63946),
                  ),
                  SizedBox(height: 12.uh),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13.usp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5A6A82),
                    ),
                  ),
                  SizedBox(height: 16.uh),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Go back'),
                  ),
                ],
                SizedBox(height: 20.uh),
                Text(
                  'Status: $_status',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11.usp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9AA5B5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _sectionTitle => GoogleFonts.poppins(
        fontSize: 13.usp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A2A4F),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.muted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.uh),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.usp, color: iconColor),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5.usp,
                fontWeight: FontWeight.w500,
                color: muted
                    ? const Color(0xFF5A6A82)
                    : const Color(0xFF1A2A4F),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
