import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

class InvoiceReceivingDetailScreen extends ConsumerWidget {
  const InvoiceReceivingDetailScreen({
    super.key,
    required this.invoiceId,
    this.testRole,
  });

  final int invoiceId;
  final PurchaseDevTestRole? testRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(invoiceDetailProvider(invoiceId));
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: detailAsync.when(
        loading: () => Column(
          children: [
            PurchaseManagementGlassHeader(
              title: translate('home.purchase.invoice_detail_title'),
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7DB3E8)))),
          ],
        ),
        error: (e, _) => Column(
          children: [
            PurchaseManagementGlassHeader(
              title: translate('home.purchase.invoice_detail_title'),
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
                child: Center(
                    child: Text(e.toString(),
                        style: GoogleFonts.poppins(
                            color: Colors.red, fontSize: 13.tsp)))),
          ],
        ),
        data: (detail) {
          if (detail == null) {
            return Column(
              children: [
                PurchaseManagementGlassHeader(
                  title: translate('home.purchase.invoice_detail_title'),
                  showBack: true,
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                    child: Center(
                        child: Text('Not found',
                            style: GoogleFonts.poppins(
                                color: Colors.white54)))),
              ],
            );
          }
          return _InvoiceDetailContent(
            detail: detail,
            invoiceId: invoiceId,
            testRole: testRole,
          );
        },
      ),
      ),
    );
  }
}

class _InvoiceDetailContent extends ConsumerStatefulWidget {
  const _InvoiceDetailContent({
    required this.detail,
    required this.invoiceId,
    this.testRole,
  });

  final InvoiceReceivingDetail detail;
  final int invoiceId;
  final PurchaseDevTestRole? testRole;

  @override
  ConsumerState<_InvoiceDetailContent> createState() =>
      _InvoiceDetailContentState();
}

class _InvoiceDetailContentState extends ConsumerState<_InvoiceDetailContent> {
  bool _receiving = false;

  Future<void> _receive() async {
    setState(() => _receiving = true);
    final repo = PurchaseRepository();
    try {
      final updated = await repo.receiveInvoiceReceiving(
        widget.invoiceId,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receive failed. Check PR role.')),
        );
        setState(() => _receiving = false);
        return;
      }
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice marked as received.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _receiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final access = ref.watch(purchaseAccessProvider);
    final status = invoiceStatusFromApi(detail.state);
    final showReceive = detail.canReceive ||
        (access.canReceiveInvoice &&
            detail.state.toUpperCase() == 'DRAFT');

    return Column(
      children: [
        PurchaseManagementGlassHeader(
          title: detail.invoiceNo,
          showBack: true,
          onBack: () => Navigator.pop(context),
          titleTrailing: PurchaseStatusChip(
            label: status.label,
            color: status.color,
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F6FA),
            child: ListView(
              padding: EdgeInsets.all(14.tw),
              children: [
                // Header card
                _SectionCard(
                  title: 'INVOICE DETAILS',
                  children: [
                    _DetailRow(label: 'Invoice No.', value: detail.invoiceNo),
                    _DetailRow(label: 'LPO No.', value: detail.lpoNo),
                    _DetailRow(label: 'Vendor', value: detail.partner),
                    _DetailRow(label: 'Invoice Date', value: detail.invoiceDate),
                    _DetailRow(label: 'Due Date', value: detail.dueDate),
                    _DetailRow(label: 'Currency', value: detail.currency),
                    _DetailRow(label: 'Payment State', value: detail.paymentState),
                    if (detail.narration.isNotEmpty)
                      _DetailRow(label: 'Notes', value: detail.narration),
                  ],
                ),
                SizedBox(height: 12.th),
                // Amounts card
                _AmountsCard(detail: detail),
                SizedBox(height: 12.th),
                // Lines
                if (detail.lines.isNotEmpty)
                  _LinesSection(lines: detail.lines),
                SizedBox(height: 12.th),
                // Attachments
                if (detail.attachments.isNotEmpty)
                  _AttachmentsSection(
                    attachments: detail.attachments,
                    invoiceId: detail.id,
                    lpoId: detail.lpoId,
                    context: context,
                  ),
                if (showReceive) ...[
                  SizedBox(height: 12.th),
                  SizedBox(
                    width: double.infinity,
                    height: 48.th,
                    child: ElevatedButton(
                      onPressed: _receiving ? null : _receive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.tr),
                        ),
                      ),
                      child: _receiving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Receive Invoice',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
                SizedBox(height: 24.th),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountsCard extends StatelessWidget {
  const _AmountsCard({required this.detail});
  final InvoiceReceivingDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.tr),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: EdgeInsets.all(14.tw),
      child: Column(
        children: [
          _AmountRow(
              label: 'Untaxed Amount',
              value: '${detail.currency} ${detail.amountUntaxed.toStringAsFixed(2)}',
              isBold: false),
          _AmountRow(
              label: 'Taxes',
              value: '${detail.currency} ${detail.amountTax.toStringAsFixed(2)}',
              isBold: false),
          Divider(color: const Color(0xFFE0E4EE), height: 16.th),
          _AmountRow(
              label: 'Total',
              value: detail.amountDisplay.isNotEmpty
                  ? detail.amountDisplay
                  : '${detail.currency} ${detail.amountTotal.toStringAsFixed(2)}',
              isBold: true),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(
      {required this.label, required this.value, required this.isBold});
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.th),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  color: const Color(0xFF8A9BB5),
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: isBold ? 15.tsp : 12.tsp,
                  color: PurchaseTheme.textPrimary,
                  fontWeight:
                      isBold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.lines});
  final List<InvoiceLineItem> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRODUCTS',
            style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w700,
                color: PurchaseTheme.textPrimary,
                letterSpacing: 0.4)),
        SizedBox(height: 8.th),
        ...lines.map((line) => Container(
              margin: EdgeInsets.only(bottom: 6.th),
              padding: EdgeInsets.all(12.tw),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.tr),
                border: Border.all(
                    color: const Color(0xFFE0E4EE), width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.product.isNotEmpty
                              ? line.product
                              : line.description,
                          style: GoogleFonts.poppins(
                              fontSize: 12.tsp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E2A4A)),
                        ),
                        Text(
                          'Qty: ${line.qty} × ${line.priceUnit.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 10.5.tsp,
                              color: const Color(0xFF8A9BB5)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.subtotal.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3E7BFA)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.attachments,
    required this.invoiceId,
    required this.lpoId,
    required this.context,
  });
  final List<InvoiceAttachment> attachments;
  final int invoiceId;
  final int? lpoId;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SUPPORTING DOCUMENTS',
            style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w700,
                color: PurchaseTheme.textPrimary,
                letterSpacing: 0.4)),
        SizedBox(height: 8.th),
        ...attachments.map((a) => Container(
              margin: EdgeInsets.only(bottom: 6.th),
              padding: EdgeInsets.all(12.tw),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.tr),
                border: Border.all(
                    color: const Color(0xFFE0E4EE), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded,
                      size: 20.tsp, color: const Color(0xFF3E7BFA)),
                  SizedBox(width: 10.tw),
                  Expanded(
                    child: Text(
                      a.name,
                      style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E2A4A)),
                    ),
                  ),
                  // Print/LPO button — opens PDF via invoice/report_url
                  TextButton(
                    onPressed: () async {
                      final repo = PurchaseRepository();
                      final url =
                          await repo.fetchInvoiceReportUrl(invoiceId);
                      if (url != null && ctx.mounted) {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                LpoPdfViewerScreen(pdfUrl: url),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: PurchaseTheme.textPrimary,
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.tw, vertical: 4.th),
                      textStyle: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w600),
                      side: const BorderSide(
                          color: PurchaseTheme.textPrimary, width: 0.8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.tr)),
                    ),
                    child: const Text('Print / LPO'),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reused layout widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.tr),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: EdgeInsets.all(14.tw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A9BB5),
                  letterSpacing: 0.4)),
          SizedBox(height: 10.th),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.tw,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A9BB5))),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 11.5.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E2A4A))),
          ),
        ],
      ),
    );
  }
}
