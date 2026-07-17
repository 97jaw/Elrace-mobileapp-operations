import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseHubCardTile extends StatelessWidget {
  const PurchaseHubCardTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.tr),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.tw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.tw,
                      height: 36.tw,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12.tr),
                      ),
                      child: Icon(icon, color: accent, size: 20.tsp),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 22.tsp),
                  ],
                ),
                SizedBox(height: 14.th),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.th),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.th),
                Text(
                  count,
                  style: GoogleFonts.poppins(
                    fontSize: 24.tsp,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String hubCardCount(PurchaseHubCards cards, PurchaseHubCardKind kind) {
  return switch (kind) {
    PurchaseHubCardKind.waitingRfqs => '${cards.waitingRfqs}',
    PurchaseHubCardKind.totalRfqs => '${cards.totalRfqs}',
    PurchaseHubCardKind.pendingMrs => '${cards.pendingMrs}',
    PurchaseHubCardKind.lpos => '${cards.lpos}',
    PurchaseHubCardKind.invoiceReceiving => 'Open',
  };
}

enum PurchaseHubCardKind {
  waitingRfqs,
  totalRfqs,
  pendingMrs,
  lpos,
  invoiceReceiving,
}

extension PurchaseHubCardKindX on PurchaseHubCardKind {
  String get title => switch (this) {
        PurchaseHubCardKind.waitingRfqs => 'Waiting RFQs',
        PurchaseHubCardKind.totalRfqs => 'Total RFQs',
        PurchaseHubCardKind.pendingMrs => 'Pending MRs',
        PurchaseHubCardKind.lpos => 'LPOs',
        PurchaseHubCardKind.invoiceReceiving => 'Invoice Receiving',
      };

  String get subtitle => switch (this) {
        PurchaseHubCardKind.waitingRfqs =>
          'Pending validation or draft / sent / to approve',
        PurchaseHubCardKind.totalRfqs => 'All RFQs in your scope',
        PurchaseHubCardKind.pendingMrs =>
          'Draft through approved requisitions',
        PurchaseHubCardKind.lpos => 'Confirmed purchase orders',
        PurchaseHubCardKind.invoiceReceiving => 'Create or receive invoices',
      };

  IconData get icon => switch (this) {
        PurchaseHubCardKind.waitingRfqs => Icons.hourglass_top_rounded,
        PurchaseHubCardKind.totalRfqs => Icons.request_quote_rounded,
        PurchaseHubCardKind.pendingMrs => Icons.assignment_outlined,
        PurchaseHubCardKind.lpos => Icons.receipt_long_rounded,
        PurchaseHubCardKind.invoiceReceiving => Icons.fact_check_outlined,
      };

  Color get accent => switch (this) {
        PurchaseHubCardKind.waitingRfqs => const Color(0xFFF59E0D),
        PurchaseHubCardKind.totalRfqs => const Color(0xFF7DB3E8),
        PurchaseHubCardKind.pendingMrs => const Color(0xFF4ADE80),
        PurchaseHubCardKind.lpos => const Color(0xFFA78BFA),
        PurchaseHubCardKind.invoiceReceiving => const Color(0xFF38BDF8),
      };

  String get listStatusFilter => switch (this) {
        PurchaseHubCardKind.waitingRfqs => 'WAITING_RFQS',
        PurchaseHubCardKind.totalRfqs => '',
        PurchaseHubCardKind.pendingMrs => 'PENDING_MRS',
        PurchaseHubCardKind.lpos => 'LPOS',
        PurchaseHubCardKind.invoiceReceiving => '',
      };
}
