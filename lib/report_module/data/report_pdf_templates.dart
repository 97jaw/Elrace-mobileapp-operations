/// PDF layout templates for site reports (`PdfService.templateType`).
class ReportPdfTemplates {
  ReportPdfTemplates._();

  static const String defaultId = 'template1';

  static const List<ReportPdfTemplateOption> options = [
    ReportPdfTemplateOption(
      id: 'template1',
      asset: 'assets/newapp/IMAGE TEMPLATE.png',
      isTall: true,
    ),
    ReportPdfTemplateOption(
      id: 'template2',
      asset: 'assets/newapp/IMAGE TEMPLATE 2 .png',
      isTall: false,
    ),
    ReportPdfTemplateOption(
      id: 'template3',
      asset: 'assets/newapp/image template 3.png',
      isTall: true,
    ),
    ReportPdfTemplateOption(
      id: 'template4',
      asset: 'assets/newapp/image template 4.png',
      isTall: false,
    ),
  ];
}

class ReportPdfTemplateOption {
  const ReportPdfTemplateOption({
    required this.id,
    required this.asset,
    required this.isTall,
  });

  final String id;
  final String asset;
  final bool isTall;
}
