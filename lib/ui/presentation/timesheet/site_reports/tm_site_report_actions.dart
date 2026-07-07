import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Rename / delete dialogs wired to legacy report APIs.
class TmSiteReportActions {
  TmSiteReportActions._();

  static Future<String?> _promptName(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TimesheetModuleColors.surface,
        title: Text(title, style: TimesheetModuleTypography.h2()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static Future<bool> renameReport(
    BuildContext context, {
    required ReportProvider provider,
    required ReportModel report,
  }) async {
    final name = await _promptName(
      context,
      title: 'Rename report',
      hint: 'Report name',
      initial: report.name,
    );
    if (name == null || name.isEmpty || name == report.name) return false;
    await provider.updateReport(name: name, reportId: report.id);
    return true;
  }

  static Future<bool> deleteReport(
    BuildContext context, {
    required ReportProvider provider,
    required ReportModel report,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TimesheetModuleColors.surface,
        title: Text('Delete report?', style: TimesheetModuleTypography.h2()),
        content: Text(
          'Report #${report.id} and its photos will be removed.',
          style: TimesheetModuleTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: TimesheetModuleColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await provider.deleteReport(reportId: report.id);
    return true;
  }

  static Future<bool> renamePdf(
    BuildContext context, {
    required ReportProvider provider,
    required String reportId,
    required String currentName,
  }) async {
    final name = await _promptName(
      context,
      title: 'Rename PDF',
      hint: 'File name',
      initial: currentName.replaceAll('.pdf', ''),
    );
    if (name == null || name.isEmpty) return false;
    return provider.renameReportPdf(
      fileId: reportId,
      newFileName: name.endsWith('.pdf') ? name : '$name.pdf',
    );
  }

  static Future<bool> deletePdf(
    BuildContext context, {
    required ReportProvider provider,
    required String reportId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TimesheetModuleColors.surface,
        title: Text('Delete PDF?', style: TimesheetModuleTypography.h2()),
        content: Text(
          'The generated PDF file will be removed from this report.',
          style: TimesheetModuleTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: TimesheetModuleColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    return provider.deleteReportPdf(fileId: reportId);
  }

  static Future<void> showReportMenu(
    BuildContext context, {
    required ReportProvider provider,
    required ReportModel report,
    required VoidCallback onChanged,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TimesheetModuleColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(PhosphorIcons.pencilSimple()),
              title: const Text('Rename report'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(PhosphorIcons.trash(), color: TimesheetModuleColors.danger),
              title: Text(
                'Delete report',
                style: TextStyle(color: TimesheetModuleColors.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'rename') {
      if (await renameReport(context, provider: provider, report: report)) {
        onChanged();
      }
    } else if (action == 'delete') {
      if (await deleteReport(context, provider: provider, report: report)) {
        onChanged();
      }
    }
  }
}
