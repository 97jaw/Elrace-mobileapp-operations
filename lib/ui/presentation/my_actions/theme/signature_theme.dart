import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light, khaki/brown, mostly-white theme for the Signature module
/// (Home + Documents tabs). Intentionally distinct from the purple
/// gradient used by the generic My Actions landing scaffold.
abstract final class SignatureTheme {
  static const Color khaki = Color(0xFFBFA76A);
  static const Color khakiDeep = Color(0xFFA48C51);
  static const Color khakiLight = Color(0xFFE8DFC5);
  static const Color brown = Color(0xFF7B5B3A);
  static const Color brownDeep = Color(0xFF5A4028);
  static const Color brownLight = Color(0xFFEFE6D8);

  static const Color background = Color(0xFFFDFBF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F1E7);
  static const Color divider = Color(0xFFEDE5D5);

  static const Color textDark = Color(0xFF3B2F22);
  static const Color textMuted = Color(0xFF8B7E6A);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  static const Color pending = Color(0xFFC98A2E);
  static const Color signed = Color(0xFF3E8E5B);
  static const Color waiting = Color(0xFF8A6D3B);
  static const Color expired = Color(0xFFB4483C);

  static const SystemUiOverlayStyle lightStatusBar = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  );

  static Color statusColor(SignatureItemStatusLike status) {
    switch (status) {
      case SignatureItemStatusLike.needsSignature:
        return pending;
      case SignatureItemStatusLike.waitingForOthers:
        return waiting;
      case SignatureItemStatusLike.completed:
        return signed;
      case SignatureItemStatusLike.expired:
        return expired;
      case SignatureItemStatusLike.draft:
        return textMuted;
    }
  }

  static BoxDecoration card({double radius = 18}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius.tr),
      border: Border.all(color: divider),
      boxShadow: [
        BoxShadow(
          color: brownDeep.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration statCard() {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20.tr),
      border: Border.all(color: divider),
      boxShadow: [
        BoxShadow(
          color: brownDeep.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static TextStyle get appBarTitle => GoogleFonts.poppins(
        fontSize: 18.tsp,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get sectionTitle => GoogleFonts.poppins(
        fontSize: 16.tsp,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get cardTitle => GoogleFonts.poppins(
        fontSize: 14.tsp,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get cardSubtitle => GoogleFonts.poppins(
        fontSize: 12.tsp,
        fontWeight: FontWeight.w500,
        color: textMuted,
      );

  static TextStyle get statValue => GoogleFonts.poppins(
        fontSize: 26.tsp,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get statLabel => GoogleFonts.poppins(
        fontSize: 12.tsp,
        fontWeight: FontWeight.w600,
        color: textMuted,
      );
}

/// Generic status bucket shared by Home + Documents tabs for coloring.
enum SignatureItemStatusLike {
  needsSignature,
  waitingForOthers,
  completed,
  expired,
  draft,
}
