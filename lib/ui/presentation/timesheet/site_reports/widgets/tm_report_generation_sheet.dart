import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum TmReportGenerationVisual {
  preparing,
  uploadingPhotos,
  generatingPdf,
  uploadingCloud,
  done,
  error,
}

typedef TmReportGenerationNotifier = void Function({
  required double progress,
  required String status,
  required TmReportGenerationVisual visual,
});

/// Slide-up sheet with step-specific animation while generating a site report.
class TmReportGenerationSheet {
  TmReportGenerationSheet._();

  /// Runs [work] while showing progress. Returns `true` on success.
  static Future<bool> run(
    BuildContext context, {
    required Future<bool> Function(TmReportGenerationNotifier notify) work,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TmReportGenerationSheetHost(work: work),
    );
    return result ?? false;
  }
}

class _TmReportGenerationSheetHost extends StatefulWidget {
  const _TmReportGenerationSheetHost({required this.work});

  final Future<bool> Function(TmReportGenerationNotifier notify) work;

  @override
  State<_TmReportGenerationSheetHost> createState() =>
      _TmReportGenerationSheetHostState();
}

class _TmReportGenerationSheetHostState extends State<_TmReportGenerationSheetHost>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  String _status = 'Preparing…';
  TmReportGenerationVisual _visual = TmReportGenerationVisual.preparing;
  bool _done = false;
  bool _failed = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _notify({
    required double progress,
    required String status,
    required TmReportGenerationVisual visual,
  }) {
    if (!mounted) return;
    setState(() {
      _progress = progress.clamp(0.0, 1.0);
      _status = status;
      _visual = visual;
    });
  }

  Future<void> _run() async {
    try {
      final ok = await widget.work(_notify);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _done = true;
          _visual = TmReportGenerationVisual.done;
          _status = 'Report ready';
          _progress = 1;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _failed = true;
          _visual = TmReportGenerationVisual.error;
          _status = 'Something went wrong';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _visual = TmReportGenerationVisual.error;
        _status = 'Generation failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _AnimatedVisual(visual: _visual, pulse: _pulse),
          const SizedBox(height: 24),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TimesheetModuleTypography.h2(),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).round()}%',
            style: TimesheetModuleTypography.caption().copyWith(
              fontWeight: FontWeight.w800,
              color: TimesheetModuleColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: TimesheetModuleColors.divider,
              color: _failed
                  ? TimesheetModuleColors.danger
                  : TimesheetModuleColors.primary,
            ),
          ),
          if (_failed && !_done) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedVisual extends StatelessWidget {
  const _AnimatedVisual({
    required this.visual,
    required this.pulse,
  });

  final TmReportGenerationVisual visual;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _buildIcon(key: ValueKey(visual)),
    );
  }

  Widget _buildIcon({required Key key}) {
    final (IconData icon, Color color) = switch (visual) {
      TmReportGenerationVisual.preparing => (
          PhosphorIcons.folderOpen(),
          TimesheetModuleColors.navy,
        ),
      TmReportGenerationVisual.uploadingPhotos => (
          PhosphorIcons.images(),
          TimesheetModuleColors.primary,
        ),
      TmReportGenerationVisual.generatingPdf => (
          PhosphorIcons.filePdf(),
          const Color(0xFFE6A700),
        ),
      TmReportGenerationVisual.uploadingCloud => (
          PhosphorIcons.cloudArrowUp(),
          TimesheetModuleColors.primary,
        ),
      TmReportGenerationVisual.done => (
          PhosphorIcons.checkCircle(),
          const Color(0xFF3DDC84),
        ),
      TmReportGenerationVisual.error => (
          PhosphorIcons.warningCircle(),
          TimesheetModuleColors.danger,
        ),
    };

    return ScaleTransition(
      key: key,
      scale: Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 44, color: color),
      ),
    );
  }
}
