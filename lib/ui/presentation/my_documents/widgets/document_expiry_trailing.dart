import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_display.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Right-side stack for document list rows: status pill + Updated date.
class DocumentExpiryTrailing extends StatelessWidget {
  const DocumentExpiryTrailing({
    super.key,
    required this.document,
  });

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final days = DocumentDisplay.daysUntilExpiry(document);
    final label = DocumentDisplay.expiryCountdownLabel(document);
    final updated = DocumentDisplay.formatUpdatedShort(document);
    final style = _pillStyle(days);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
          decoration: BoxDecoration(
            color: style.fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: style.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 13.tsp, color: style.accent),
              SizedBox(width: 4.tw),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w600,
                  color: style.accent,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (updated != null) ...[
          SizedBox(height: 4.th),
          Text(
            'Updated $updated',
            style: GoogleFonts.poppins(
              fontSize: 9.tsp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7B8290),
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }

  static _PillStyle _pillStyle(int? days) {
    if (days == null) {
      return const _PillStyle(
        fill: Color(0xFFF0F2F5),
        accent: Color(0xFF6B7280),
        icon: Icons.help_outline_rounded,
      );
    }
    if (days < 0) {
      return const _PillStyle(
        fill: Color(0xFFFFE8E8),
        accent: Color(0xFFC62828),
        icon: Icons.error_outline_rounded,
      );
    }
    if (days <= 30) {
      return const _PillStyle(
        fill: Color(0xFFFFF1E0),
        accent: Color(0xFFC47A12),
        icon: Icons.access_time_rounded,
      );
    }
    return const _PillStyle(
      fill: Color(0xFFE6F6EC),
      accent: Color(0xFF1F7A4D),
      icon: Icons.access_time_rounded,
    );
  }
}

class _PillStyle {
  const _PillStyle({
    required this.fill,
    required this.accent,
    required this.icon,
  });

  final Color fill;
  final Color accent;
  final IconData icon;
}
