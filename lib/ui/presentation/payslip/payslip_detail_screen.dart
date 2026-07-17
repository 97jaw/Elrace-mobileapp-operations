import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:io';

import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/payslip_pdf_builder.dart';
import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/payslip/payslip_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PayslipDetailScreen extends ConsumerWidget {
  const PayslipDetailScreen({super.key, required this.payslipId});

  final String payslipId;

  String _watermarkKey(PayslipRecord r) {
    final id = r.identificationNo.replaceAll(RegExp(r'[^0-9]'), '');
    if (id.length >= 4) return id.substring(id.length - 4);
    return r.reference;
  }

  Future<void> _openPdf(
    BuildContext context,
    PayslipRecord record,
  ) async {
    final bytes = await PayslipPdfBuilder.build(
      record: record,
      watermarkKey: _watermarkKey(record),
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _downloadPdf(
    BuildContext context,
    PayslipRecord record,
  ) async {
    final bytes = await PayslipPdfBuilder.build(
      record: record,
      watermarkKey: _watermarkKey(record),
    );
    final name =
        '${record.reference.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')}.pdf';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    if (!context.mounted) return;
    final box = context.findRenderObject();
    final origin = box is RenderBox
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 1, 1);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payslipRecordProvider(payslipId));

    return PayslipGradientScaffold(
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface.withValues(alpha: 0.92),
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        title: Text(
          'Payslip',
          style: HrModuleTypography.pageTitle().copyWith(
                fontSize: 18.tsp,
                fontWeight: FontWeight.w800,
                color: HrModuleColors.text,
              ),
        ),
      ),
      body: async.when(
          data: (record) {
            if (record == null) {
              return Center(
                child: Text(
                  'Payslip not found.',
                  style: HrModuleTypography.body(),
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                HrModuleLayout.screenPaddingH.tw,
                16.th,
                HrModuleLayout.screenPaddingH.tw,
                32.th,
              ),
              children: [
                Wrap(
                  spacing: 8.tw,
                  runSpacing: 8.th,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openPdf(context, record),
                      style: FilledButton.styleFrom(
                        backgroundColor: HrModuleColors.success,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('View PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadPdf(context, record),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HrModuleColors.primary,
                        side: BorderSide(color: HrModuleColors.primary),
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                  ],
                ),
                SizedBox(height: 16.th),
                PayslipDocumentView(record: record),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.tw),
              child: Text(
                'Could not load payslip.\n$e',
                textAlign: TextAlign.center,
                style: HrModuleTypography.body(),
              ),
            ),
          ),
        ),
    );
  }
}
