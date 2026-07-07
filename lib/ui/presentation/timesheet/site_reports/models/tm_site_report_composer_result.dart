/// Returned when a site report PDF was generated successfully.
class TmSiteReportComposerResult {
  const TmSiteReportComposerResult({
    required this.reportId,
    required this.pdfUrl,
    required this.pdfTitle,
    required this.templateId,
  });

  final String reportId;
  final String pdfUrl;
  final String pdfTitle;
  final String templateId;
}
