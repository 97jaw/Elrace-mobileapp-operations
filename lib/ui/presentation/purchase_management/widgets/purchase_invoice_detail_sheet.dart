import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showPurchaseInvoiceDetailSheet(
  BuildContext context, {
  required int invoiceId,
  DraftInvoiceItem? preview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PurchaseInvoiceDetailSheet(
      invoiceId: invoiceId,
      preview: preview,
    ),
  );
}

class PurchaseInvoiceDetailSheet extends ConsumerWidget {
  const PurchaseInvoiceDetailSheet({
    super.key,
    required this.invoiceId,
    this.preview,
  });

  final int invoiceId;
  final DraftInvoiceItem? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseInvoiceDetailProvider(invoiceId));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 24),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.62,
            minChildSize: 0.42,
            maxChildSize: 0.96,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F9FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10.th),
                    Container(
                      width: 40.tw,
                      height: 4.th,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D2D6),
                        borderRadius: BorderRadius.circular(2.tr),
                      ),
                    ),
                    Expanded(
                      child: detailAsync.when(
                        loading: () => _LoadingBody(
                          scrollController: scrollController,
                          preview: preview,
                        ),
                        error: (e, _) => ListView(
                          controller: scrollController,
                          padding: EdgeInsets.all(20.tw),
                          children: [
                            Text(
                              'Could not load invoice details',
                              style: GoogleFonts.poppins(
                                fontSize: 14.tsp,
                                fontWeight: FontWeight.w600,
                                color: PurchaseTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8.th),
                            Text(
                              '$e',
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                color: PurchaseTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        data: (detail) {
                          if (detail == null) {
                            return ListView(
                              controller: scrollController,
                              padding: EdgeInsets.all(20.tw),
                              children: [
                                Text(
                                  'Invoice not found or not authorized.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.tsp,
                                    color: PurchaseTheme.textSecondary,
                                  ),
                                ),
                              ],
                            );
                          }
                          return _DetailBody(
                            scrollController: scrollController,
                            detail: detail,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({
    required this.scrollController,
    this.preview,
  });

  final ScrollController scrollController;
  final DraftInvoiceItem? preview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 28.th),
      children: [
        if (preview != null) ...[
          _Header(
            vendor: preview!.vendor,
            vendorPhoto: preview!.vendorPhoto,
            invoiceId: preview!.invoiceId,
            status: preview!.displayStatus,
            origin: preview!.origin,
          ),
          SizedBox(height: 20.th),
        ],
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(
              color: PurchaseTheme.accentBlue,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.scrollController,
    required this.detail,
  });

  final ScrollController scrollController;
  final PurchaseInvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 32.th),
      children: [
        _Header(
          vendor: detail.vendor,
          vendorPhoto: detail.vendorPhoto,
          invoiceId: detail.invoiceId,
          status: detail.displayStatus,
          origin: detail.origin,
        ),
        SizedBox(height: 16.th),
        _MoneyBlock(detail: detail),
        SizedBox(height: 14.th),
        _SectionCard(
          title: 'Dates',
          children: [
            _KV(label: 'Invoice date', value: detail.invoiceDate),
            _KV(label: 'Due date', value: detail.dueDate),
          ],
        ),
        if (detail.ref.isNotEmpty || detail.narration.isNotEmpty) ...[
          SizedBox(height: 14.th),
          _SectionCard(
            title: 'Notes',
            children: [
              if (detail.ref.isNotEmpty) _KV(label: 'Ref', value: detail.ref),
              if (detail.narration.isNotEmpty)
                _KV(label: 'Narration', value: detail.narration),
            ],
          ),
        ],
        SizedBox(height: 14.th),
        _PaymentsSection(payments: detail.payments),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.vendor,
    required this.vendorPhoto,
    required this.invoiceId,
    required this.status,
    required this.origin,
  });

  final String vendor;
  final String vendorPhoto;
  final String invoiceId;
  final String status;
  final String origin;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(name: vendor, photoUrl: vendorPhoto),
        SizedBox(width: 12.tw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.isNotEmpty ? vendor : '—',
                style: GoogleFonts.poppins(
                  fontSize: 16.tsp,
                  fontWeight: FontWeight.w700,
                  color: PurchaseTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2.th),
              Text(
                invoiceId,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w600,
                  color: PurchaseTheme.accentDeep,
                ),
              ),
              if (origin.isNotEmpty) ...[
                SizedBox(height: 2.th),
                Text(
                  'LPO / Origin: $origin',
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    color: PurchaseTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        InvoiceStatusBadge(label: status),
      ],
    );
  }
}

class _MoneyBlock extends StatelessWidget {
  const _MoneyBlock({required this.detail});

  final PurchaseInvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Amounts',
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniAmount(
                label: 'Untaxed',
                value: detail.formattedUntaxed.isNotEmpty
                    ? detail.formattedUntaxed
                    : _fmt(detail.amountUntaxed),
              ),
            ),
            Expanded(
              child: _MiniAmount(
                label: 'Tax',
                value: detail.formattedTax.isNotEmpty
                    ? detail.formattedTax
                    : _fmt(detail.amountTax),
              ),
            ),
            Expanded(
              child: _MiniAmount(
                label: 'Total',
                value: detail.formattedAmount.isNotEmpty
                    ? detail.formattedAmount
                    : _fmt(detail.amount),
                emphasize: true,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.th),
        Row(
          children: [
            Expanded(
              child: _MiniAmount(
                label: 'Paid',
                value: detail.formattedPaid.isNotEmpty
                    ? detail.formattedPaid
                    : _fmt(detail.amountPaid),
              ),
            ),
            Expanded(
              child: _MiniAmount(
                label: 'Amount due',
                value: detail.formattedResidual.isNotEmpty
                    ? detail.formattedResidual
                    : _fmt(detail.amountResidual),
                emphasize: true,
                color: detail.amountResidual > 0.01
                    ? const Color(0xFFC05621)
                    : const Color(0xFF2F855A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(double v) => 'AED ${v.toStringAsFixed(2)}';
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.payments});

  final List<InvoicePaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payments${payments.isEmpty ? '' : ' (${payments.length})'}',
      children: [
        if (payments.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.th),
            child: Text(
              'No payments linked yet',
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: PurchaseTheme.textMuted,
              ),
            ),
          )
        else
          for (var i = 0; i < payments.length; i++) ...[
            if (i > 0) SizedBox(height: 8.th),
            _PaymentCard(payment: payments[i]),
          ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final InvoicePaymentItem payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(
          color: PurchaseTheme.accentBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.name.isNotEmpty ? payment.name : 'Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                payment.formattedAmount.isNotEmpty
                    ? payment.formattedAmount
                    : 'AED ${payment.amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w700,
                  color: PurchaseTheme.accentDeep,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.th),
          Text(
            [
              if (payment.date.isNotEmpty) payment.date,
              if (payment.journal.isNotEmpty) payment.journal,
              if (payment.state.isNotEmpty) payment.state.toUpperCase(),
            ].join(' · '),
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              color: PurchaseTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      decoration: PurchaseTheme.glassPanel(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w700,
              color: PurchaseTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 8.th),
          ...children,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 6.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.tw,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: PurchaseTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w600,
                color: PurchaseTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.tsp,
            color: PurchaseTheme.textMuted,
          ),
        ),
        SizedBox(height: 2.th),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: emphasize ? 13.tsp : 12.tsp,
            fontWeight: FontWeight.w700,
            color: color ?? PurchaseTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = PurchaseAvatar.sanitizeUrl(photoUrl);
    if (url != null) {
      return CircleAvatar(
        radius: 24.tr,
        backgroundColor: const Color(0xFFE8F4FC),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: 48.tr,
            height: 48.tr,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _fallback(initial),
          ),
        ),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) {
    return CircleAvatar(
      radius: 24.tr,
      backgroundColor: PurchaseTheme.accentBlue.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 16.tsp,
          fontWeight: FontWeight.w700,
          color: PurchaseTheme.accentDeep,
        ),
      ),
    );
  }
}
