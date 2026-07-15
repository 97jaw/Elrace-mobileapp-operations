import 'dart:io';
import 'package:image/image.dart' as img;

import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/timesheet/utils/tm_http_url.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../ui/presentation/call_screen/data/repository.dart';

class PdfService {
  Future<Uint8List> generateReportPdf({
    required ReportDetailModel report,
    required String projectName,
    String? companyName,
    String templateType = 'template1',
  }) async {
    final pdf = pw.Document();
    final logoPath = _resolveCompanyLogoPath(
      companyName,
      fallbackPath: CompanyRepository.company?.logo,
    );

    // Run all async operations in parallel
    final results = await Future.wait([
      userRepo.getLoginResponse(),
      loadReportImages(report.reportItems),
      _loadAssetAsBytes(logoPath),
      rootBundle.load("assets/fonts/arbicsupport.ttf"),
    ]);

    final LoginResponseModel? userData = results[0] as LoginResponseModel?;
    final imageMap = results[1] as Map<String, pw.MemoryImage>;
    final Uint8List logo = results[2] as Uint8List;
    // Unicode TTF — must be set as theme base+bold so FontWeight.bold does not
    // fall back to Helvetica-Bold (no Unicode → broken glyphs / load failures).
    final unicodeFont = pw.Font.ttf(results[3] as ByteData);
    final String userName = userData?.result?.data?.name ??
        userData?.result?.data?.username ??
        userData?.result?.data?.emp_name ??
        '';
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin:
              const pw.EdgeInsets.only(left: 32, right: 32, bottom: 20, top: 5),
          theme: pw.ThemeData.withFont(
            base: unicodeFont,
            bold: unicodeFont,
          ),
        ),
        header: (context) =>
            _buildHeader(context, logo, report, projectName, unicodeFont),
        footer: (context) => _buildFooter(context, userName, unicodeFont),
        build: (context) => _buildBody(context, logo, report, imageMap,
            userData, unicodeFont, templateType),
      ),
    );

    return pdf.save();
  }

  String _resolveCompanyLogoPath(String? companyName, {String? fallbackPath}) {
    final normalized = (companyName ?? '').trim().toLowerCase();

    if (normalized == 'colors') {
      return 'assets/newapp/Colors.png';
    }
    if (normalized == 'hcni') {
      return 'assets/newapp/HCNI NBG.png';
    }
    if (normalized == '85 eighty five' ||
        normalized == '85' ||
        normalized == 'eighty five') {
      return 'assets/newapp/png-logo-85.png';
    }

    if (normalized == 'rcc' || normalized.contains('el race')) {
      return 'assets/logo/logo.png';
    }
    if (normalized.contains('al hewar')) {
      return 'assets/logo/logo2.png';
    }

    if (fallbackPath != null && fallbackPath.trim().isNotEmpty) {
      return fallbackPath;
    }
    return 'assets/logo/logo.png';
  }

  _buildHeader(context, logo, ReportDetailModel report, String projectName,
      pw.Font font) {
    CompanyModel companyData = CompanyRepository.company!;
    bool needToShowCover =
        (context.pageNumber == 1 && report.coverPage != null);
    if (needToShowCover) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Logo centered at the top.

        pw.Container(
          child: pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(pw.MemoryImage(logo), height: 90, width: 170),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Report",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "No. ${_getReportNumber(report)}",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Container(height: 1, color: PdfColors.black),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // if (companyData.employeeName != "")
                  // pw.Expanded(
                  //   child: pw.Column(
                  //       mainAxisAlignment: pw.MainAxisAlignment.start,
                  //       children: [
                  //         pw.Text(
                  //           "Subject:",
                  //           textAlign: pw.TextAlign.center,
                  //           style: pw.TextStyle(
                  //             fontSize: 13,
                  //             font: font,
                  //             fontWeight: pw.FontWeight.bold,
                  //           ),
                  //         ),
                  //         pw.SizedBox(height: 3),
                  //         pw.Text(
                  //           subject,
                  //           textAlign: pw.TextAlign.center,
                  //           textDirection:
                  //               RegExp(r'[\u0600-\u06FF]').hasMatch(subject)
                  //                   ? pw.TextDirection.rtl
                  //                   : pw.TextDirection.ltr,
                  //           style: pw.TextStyle(
                  //             fontSize: 13,
                  //             font: font,
                  //             fontWeight: pw.FontWeight.normal,
                  //           ),
                  //         ),
                  //       ]),
                  // ),
                  // pw.Container(width: 1, color: PdfColors.black, height: 44),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.SizedBox(height: 1),
                          pw.Text(
                            "Project Name",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 14,
                              font: font,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          // pw.SizedBox(height: 1),
                          pw.Text(
                            projectName,
                            textAlign: pw.TextAlign.center,
                            textDirection:
                                RegExp(r'[\u0600-\u06FF]').hasMatch(projectName)
                                    ? pw.TextDirection.rtl
                                    : pw.TextDirection.ltr,
                            style: pw.TextStyle(fontSize: 13, font: font),
                          )
                        ]),
                  ),
                  pw.Container(width: 1, color: PdfColors.black, height: 44),
                  pw.Expanded(
                    child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.SizedBox(height: 1),
                          pw.Text(
                            "Date:",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 14,
                              font: font,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          // pw.SizedBox(height: 1),
                          pw.Text(
                            " ${DateFormat("dd//MM/yyyy").format(DateTime.now())}",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 13,
                            ),
                          )
                        ]),
                  ),
                ],
              ),
            ),
          ]),
        ),

        pw.SizedBox(height: 20),
        if (!needToShowCover) _buildTableHeader()
      ],
    );
  }

  Future<Map<String, pw.MemoryImage>> loadReportImages(
      List<ReportItemModel> items) async {
    final imageItems = items.where((item) => item.type == 'image').toList();
    final Map<String, pw.MemoryImage> imageMap = {};

    // Process in batches of 3 to avoid saturating mobile bandwidth
    const batchSize = 3;
    for (int i = 0; i < imageItems.length; i += batchSize) {
      final batch = imageItems.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((item) async {
          try {
            Uint8List imageBytes;
            if (item.image.startsWith('http://') ||
                item.image.startsWith('https://')) {
              imageBytes = await tmFetchUrlBytes(item.image);
            } else {
              imageBytes = await File(item.image).readAsBytes();
            }
            // Resize image to max 800px to reduce PDF size & generation time
            imageBytes = _resizeImage(imageBytes);
            return MapEntry(item.image, pw.MemoryImage(imageBytes));
          } catch (e) {
            print('Error loading image ${item.image}: $e');
            return null;
          }
        }),
      );
      for (final entry in batchResults) {
        if (entry != null) imageMap[entry.key] = entry.value;
      }
    }

    return imageMap;
  }

  Uint8List _resizeImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      if (decoded.width <= 800 && decoded.height <= 800) return bytes;
      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 800 : -1,
        height: decoded.height >= decoded.width ? 800 : -1,
        interpolation: img.Interpolation.linear,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
    } catch (e) {
      return bytes;
    }
  }

  _buildBody(
      pw.Context context,
      logo,
      ReportDetailModel reportDetail,
      Map imageMap,
      LoginResponseModel? userData,
      pw.Font font,
      String templateType) {
    List<pw.Widget> content = [];
    // CompanyModel companyData = CompanyRepository.company!;

    bool needToShowCover = (reportDetail.coverPage != null);

    if (reportDetail.coverPage != null) {
      content.add(pw.SizedBox(
        height: 650,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(logo),
                // width: 50,
                height: 150,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Container(
                      // width: 400,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                      padding: const pw.EdgeInsets.symmetric(vertical: 5),
                      child: pw.Column(children: [
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.start,
                                  children: [
                                    pw.SizedBox(width: 12),
                                    pw.Text(
                                      "Employee Name:",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        font: font,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.Text(
                                      " ${userData?.result?.data?.name}",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        font: font,
                                      ),
                                    ),
                                  ]),
                            ),
                          ],
                        ),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.start,
                                  children: [
                                    pw.SizedBox(width: 15),
                                    pw.Text(
                                      "Employee ID:",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        font: font,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.Text(
                                      " ${userData?.result?.data?.uid}",
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 15,
                                        font: font,
                                      ),
                                    ),
                                  ]),
                            ),
                          ],
                        ),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Email:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  font: font,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${userData?.result?.data?.username}",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  font: font,
                                ),
                              ),
                            ]),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Project Name:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  font: font,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${reportDetail.report.name}",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  font: font,
                                ),
                              )
                            ]),
                        pw.Container(
                            color: PdfColors.black,
                            height: 1,
                            margin: const pw.EdgeInsets.symmetric(vertical: 5)),
                        pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            children: [
                              pw.SizedBox(width: 12),
                              pw.Text(
                                "Date:",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  font: font,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                " ${DateFormat("dd//MM/yyyy").format(DateTime.now())}",
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 15,
                                ),
                              )
                            ]),
                      ])),
                ),
                pw.SizedBox(height: 20),
                if (!needToShowCover) _buildTableHeader()
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(reportDetail.coverPage!.title,
                textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(
                  reportDetail.coverPage!.title,
                )
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
                style: pw.TextStyle(
                    fontSize: 24, font: font, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (reportDetail.coverPage!.description != null)
              pw.Text(reportDetail.coverPage!.description!,
                  textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(
                    reportDetail.coverPage!.description!,
                  )
                      ? pw.TextDirection.rtl
                      : pw.TextDirection.ltr,
                  style: pw.TextStyle(
                    fontSize: 15,
                    font: font,
                  )),
          ],
        ),
      ));
      // content.add(pw.PageBreak());
    }
    content.add(_buildTemplateBody(templateType, reportDetail, imageMap, font));
    return content;
  }

  pw.Widget _buildTemplateBody(String templateType, ReportDetailModel report,
      Map imageMap, pw.Font font) {
    switch (templateType) {
      case 'template2':
        return _buildTemplate2Body(report, imageMap, font);
      case 'template3':
        return _buildTemplate3Body(report, imageMap, font);
      case 'template4':
        return _buildTemplate4Body(report, imageMap, font);
      case 'template1':
      default:
        return _buildTemplate1Body(report, imageMap, font);
    }
  }

  pw.Widget _buildTemplate1Body(
      ReportDetailModel reportDetail, Map imageMap, pw.Font font) {
    final items = reportDetail.reportItems;

    return pw.Column(
      children: [
        for (int i = 0; i < items.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Item ${i + 1}',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        font: font)),
                pw.SizedBox(height: 6),
                _buildReportImage(items[i], imageMap, height: 190),
                pw.SizedBox(height: 8),
                _buildTemplateText(items[i], font),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildTemplate2Body(
      ReportDetailModel reportDetail, Map imageMap, pw.Font font) {
    final items = reportDetail.reportItems;

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < items.length; i++)
          pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Item ${i + 1}',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        font: font)),
                pw.SizedBox(height: 4),
                _buildReportImage(items[i], imageMap, height: 130),
                pw.SizedBox(height: 6),
                _buildTemplateText(items[i], font),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildTemplate3Body(
      ReportDetailModel reportDetail, Map imageMap, pw.Font font) {
    final items = reportDetail.reportItems;

    return pw.Column(
      children: [
        for (int i = 0; i < items.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 190,
                  child: _buildReportImage(items[i], imageMap, height: 130),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _buildTemplateText(items[i], font)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildTemplate4Body(
      ReportDetailModel reportDetail, Map imageMap, pw.Font font) {
    final items = reportDetail.reportItems;

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < items.length; i++)
          pw.Container(
            width: 170,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Item ${i + 1}',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        font: font)),
                pw.SizedBox(height: 4),
                _buildReportImage(items[i], imageMap, height: 95),
                pw.SizedBox(height: 6),
                _buildTemplateText(items[i], font),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildReportImage(ReportItemModel item, Map imageMap,
      {required double height}) {
    final image = imageMap[item.image];
    if (item.type == 'text' || image == null) {
      return pw.Container(
        height: height,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColors.grey100,
        ),
        child: pw.Text('No image'),
      );
    }
    final squareSide = height;
    return pw.Container(
      height: height,
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.grey100,
      ),
      child: pw.Center(
        child: pw.SizedBox(
          width: squareSide,
          height: squareSide,
          child: pw.Image(
            image,
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTemplateText(ReportItemModel item, pw.Font font) {
    final location = item.location.trim();
    final description = item.description.trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (location.isNotEmpty) ...[
          pw.Text('Location:',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, font: font)),
          _buildBulletList(location, font),
          pw.SizedBox(height: 4),
        ],
        if (description.isNotEmpty) ...[
          pw.Text('Description:',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, font: font)),
          _buildBulletList(description, font),
        ],
        if (location.isEmpty && description.isEmpty)
          pw.Text('-', style: pw.TextStyle(fontSize: 10, font: font)),
      ],
    );
  }

  _buildFooter(context, String userName, pw.Font font) {
    return pw.Container(
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 2))),
        padding: const pw.EdgeInsets.only(top: 10, left: 20, right: 20),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (userName.isNotEmpty)
                pw.Text(
                  userName,
                  style: pw.TextStyle(fontSize: 12, font: font),
                ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 12, font: font),
              ),
            ]));
  }

  Future<Uint8List> _loadAssetAsBytes(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  pw.Widget _buildWatermark(
    pw.Context context,
    String watermarkText, {
    pw.Font? font,
  }) {
    if (watermarkText.isEmpty) return pw.SizedBox();

    const double angle = -0.5236; // -30 degrees
    const double fontSize = 22;
    const int cols = 3;
    const int rows = 6;

    final textStyle = pw.TextStyle(
      color: PdfColors.grey200,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.normal,
      font: font,
    );

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Column(
        children: List.generate(
          rows,
          (row) => pw.Expanded(
            child: pw.Row(
              children: List.generate(
                cols,
                (col) => pw.Expanded(
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: angle,
                      child: pw.Text(
                        watermarkText,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget buildTableBody(
      ReportDetailModel reportDetail, Map imageMap, pw.Font font) {
    const double rowHeight = 200;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        for (int i = 0; i < reportDetail.reportItems.length; i++)
          pw.TableRow(
            children: [
              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.center,
                child: pw.Text("${i + 1}"),
              ),
              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.center,
                child: () {
                  final img = imageMap[reportDetail.reportItems[i].image];
                  if (reportDetail.reportItems[i].type != 'text' &&
                      img != null) {
                    return pw.Image(img);
                  }
                  return pw.Text('');
                }(),
              ),
              pw.Container(
                height: rowHeight,
                alignment: pw.Alignment.topLeft,
                padding: const pw.EdgeInsets.all(6),
                child: _buildBulletList(
                    reportDetail.reportItems[i].location, font),
              ),
              // Content column with created date, title, and description.
              pw.Container(
                height: rowHeight,
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.topLeft,
                child: _buildBulletList(
                    reportDetail.reportItems[i].description, font),
              ),
            ],
          ),
      ],
    );
  }

  int _getReportNumber(ReportDetailModel report) {
    final parsedId = int.tryParse(report.report.id) ?? 0;
    if (parsedId <= 0) return 1001;
    return 1000 + parsedId;
  }

  pw.Widget _buildBulletList(String description, pw.Font font) {
    final lines = description
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[•\-*]+\s*'), ''))
        .toList();

    if (lines.isEmpty) {
      return pw.Text(description,
          textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(description)
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr,
          style: pw.TextStyle(fontSize: 13, font: font));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: pw.TextStyle(fontSize: 13, font: font)),
                pw.Expanded(
                  child: pw.Text(line,
                      textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(line)
                          ? pw.TextDirection.rtl
                          : pw.TextDirection.ltr,
                      style: pw.TextStyle(fontSize: 13, font: font)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildTableHeader() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text(
                "#",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text(
                "Photo",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text(
                "Location",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: pw.Text(
                "Description",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
