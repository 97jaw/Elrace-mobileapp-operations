import 'dart:typed_data';

import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/report_pdf_templates.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/data/services/pdf_service.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_report_pdf_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_report_format_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_report_generation_sheet.dart';
import 'package:flutter/material.dart';

/// View PDF: pick format (default = saved) → open saved link or preview another layout.
class TmSiteReportViewPdf {
  TmSiteReportViewPdf._();

  static Future<void> open(
    BuildContext context, {
    required ReportProvider provider,
    required ReportModel report,
    required FolderModel folder,
    required String projectName,
    String? projectId,
  }) async {
    final detail = await provider.fetchReportDetailFromApi(report.id);
    final photoCount = detail?.reportItems.length ?? 0;

    final choice = await TmReportFormatSheet.show(
      context,
      photoCount: photoCount,
      initialTemplateId: _defaultTemplate(report),
      mode: TmReportFormatMode.view,
      hasSavedPdf: report.hasGeneratedPdf,
    );
    if (choice == null || !context.mounted) return;

    if (choice.openSavedPdf) {
      final link = report.reportLink?.trim() ?? '';
      if (link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved PDF on server')),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TmSiteReportPdfScreen(
            url: link,
            title: report.name,
            reportId: report.id,
            projectId: projectId,
            projectName: projectName,
          ),
        ),
      );
      return;
    }

    if (detail == null || detail.reportItems.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add photos before previewing a format')),
      );
      return;
    }

    Uint8List? bytes;
    final ok = await TmReportGenerationSheet.run(
      context,
      work: (notify) async {
        notify(
          progress: 0.2,
          status: 'Loading photos…',
          visual: TmReportGenerationVisual.preparing,
        );
        notify(
          progress: 0.55,
          status: 'Building PDF preview…',
          visual: TmReportGenerationVisual.generatingPdf,
        );
        bytes = await PdfService().generateReportPdf(
          report: detail,
          projectName: projectName,
          companyName: CompanyRepository.company?.companyName,
          templateType: choice.templateId,
        );
        notify(
          progress: 1,
          status: 'Ready',
          visual: TmReportGenerationVisual.done,
        );
        return true;
      },
    );

    if (!context.mounted || !ok || bytes == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TmSiteReportPdfScreen(
          pdfBytes: bytes,
          title: '${report.name} · ${choice.templateId}',
          reportId: report.id,
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    );
  }

  static String _defaultTemplate(ReportModel report) {
    final t = report.reportType?.trim();
    if (t != null &&
        t.isNotEmpty &&
        ReportPdfTemplates.options.any((o) => o.id == t)) {
      return t;
    }
    return ReportPdfTemplates.defaultId;
  }
}
