import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/services/timesheet_offline_queue_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SiteReportForm extends StatefulWidget {
  const SiteReportForm({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  State<SiteReportForm> createState() => _SiteReportFormState();
}

class _SiteReportFormState extends State<SiteReportForm> {
  final _summaryController = TextEditingController();
  final _weatherController = TextEditingController(text: 'Sunny, 34C');
  final _manpowerController = TextEditingController(text: '124');
  final _issuesController = TextEditingController();
  final _queueService = TimesheetOfflineQueueService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _weatherController.dispose();
    _manpowerController.dispose();
    _issuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      appBar: AppBar(
        title: Text('Daily Site Report', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: ${widget.projectId}',
                style: TimesheetModuleTypography.caption()),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            _Field(
              controller: _summaryController,
              label: 'Work summary',
              maxLines: 4,
            ),
            _Field(controller: _weatherController, label: 'Weather'),
            _Field(controller: _manpowerController, label: 'Manpower count'),
            _Field(
              controller: _issuesController,
              label: 'Issues / blockers',
              maxLines: 3,
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(title: 'Attachments'),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            Row(
              children: [
                Expanded(
                  child: _AttachmentCard(
                    icon: PhosphorIcons.images(),
                    title: 'Photos',
                    subtitle: '4 linked',
                  ),
                ),
                const SizedBox(width: TimesheetModuleLayout.cardSpacing),
                Expanded(
                  child: _AttachmentCard(
                    icon: PhosphorIcons.filePdf(),
                    title: 'PDF Draft',
                    subtitle: 'Preview',
                  ),
                ),
              ],
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(title: 'Foreman Signature'),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            Container(
              height: 132,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.surface,
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusMd,
                ),
                border: Border.all(color: TimesheetModuleColors.divider),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.signature(),
                      color: TimesheetModuleColors.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text('Tap to sign',
                        style: TimesheetModuleTypography.body()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmPrimaryButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit Report',
              icon: PhosphorIcons.paperPlaneTilt(),
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    await _queueService.enqueue(
      timesheetMockSiteReportItem(
        projectId: widget.projectId,
        summary: _summaryController.text.trim(),
        weather: _weatherController.text.trim(),
        manpower: _manpowerController.text.trim(),
        issues: _issuesController.text.trim(),
      ),
    );
    final pendingCount = await _queueService.pendingCount();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report queued. Pending extras: $pendingCount')),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TimesheetModuleLayout.cardSpacing),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: TimesheetModuleColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              TimesheetModuleLayout.cardRadiusMd,
            ),
            borderSide: const BorderSide(color: TimesheetModuleColors.divider),
          ),
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        boxShadow: TimesheetModuleShadows.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: TimesheetModuleColors.navy, size: 34),
          const SizedBox(height: 8),
          Text(title, style: TimesheetModuleTypography.cardTitle()),
          Text(subtitle, style: TimesheetModuleTypography.caption()),
        ],
      ),
    );
  }
}
