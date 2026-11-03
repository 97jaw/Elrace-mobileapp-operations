import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Headline amount on a waiting approval form.
///
/// Matches the invoice amount box: blush fill, small label, large bold value.
class ApprovalAmountBar extends StatelessWidget {
  const ApprovalAmountBar({
    super.key,
    required this.label,
    required this.amount,
    this.trailing,
  });

  final String label;
  final String amount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(14.tr),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB4534A),
                  ),
                ),
                SizedBox(height: 2.th),
                MarqueeText(
                  text: amount,
                  style: GoogleFonts.poppins(
                    fontSize: 18.tsp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// True when a waiting-form field is a money value that should use [ApprovalAmountBar].
bool approvalLabelIsAmount(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized.contains('amount') ||
      normalized.contains('salary') ||
      normalized.contains('increment') ||
      normalized.contains('gratuity') ||
      normalized == 'suggested by manager';
}
