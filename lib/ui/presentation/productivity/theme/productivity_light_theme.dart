import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light, sober palette + Roboto typography for Task Management / Tickets.
abstract final class ProductivityLightTheme {
  static const Color washBlue = Color(0xFFE9EEF8);
  static const Color washCream = Color(0xFFF3F4E8);
  static const Color card = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF111111);
  static const Color inkSecondary = Color(0xFF6B7280);
  static const Color inkMuted = Color(0xFF9CA3AF);
  static const Color inkSoft = Color(0xFFB0B5BD);
  static const Color border = Color(0xFFEEF0F3);
  static const Color iconChip = Color(0xFFF4F5F7);
  static const Color sparklineTrack = Color(0xFFE5E7EB);

  /// Distinct accents for the 2x2 stats icon chips / sparklines.
  static const Color accentTotal = Color(0xFF5B6CFF);
  static const Color accentPending = Color(0xFFF59E0B);
  static const Color accentActive = Color(0xFF0F766E);
  static const Color accentEnded = Color(0xFFE11D48);

  static const Color statusCompletedBg = Color(0xFFE8F8EF);
  static const Color statusPendingBg = Color(0xFFFFF4E5);
  static const Color statusOverdueBg = Color(0xFFFEE2E2);
  static const Color statusActiveBg = Color(0xFFCCFBF1);

  /// Badge text is black/regular per polish notes (bg still soft tint).
  static const Color statusCompletedFg = ink;
  static const Color statusPendingFg = ink;
  static const Color statusOverdueFg = ink;
  static const Color statusActiveFg = ink;

  /// Progress bar — teal, high contrast (no purple).
  static const Color progressTrack = Color(0xFFE8EAEE);
  static const Color progressFill = Color(0xFF0F766E);
  static const Color progressFillSoft = Color(0xFF99F6E4);
  static const Color progressStripe = Color(0xFF0D9488);

  /// Bottom nav center action (slate, not purple).
  static const Color navAccent = Color(0xFF1F2937);

  /// Bottom bar wash (matches moving background).
  static const Color navBarTop = Color(0xFFF5F7FC);
  static const Color navBarBottom = Color(0xFFFFFFFF);
  static const Color navBarEdge = Color(0xFFDDE3EE);
  static const Color navSelectedWash = Color(0xFFE9EEF8);

  static const double boxRadius = 14;

  // ── Typography (Roboto) ──

  static TextStyle get heroEyebrow => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
        height: 1.2,
        letterSpacing: 0,
      );

  static TextStyle get heroTitle => GoogleFonts.roboto(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: ink,
        height: 1.15,
        letterSpacing: -0.3,
      );

  static TextStyle get statLabel => GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.2,
        letterSpacing: 0,
      );

  static TextStyle get statValue => GoogleFonts.roboto(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.0,
        letterSpacing: -0.5,
      );

  static TextStyle get sectionLabel => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ink,
        letterSpacing: 0,
      );

  static TextStyle get cardTitle => GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle get cardSubtitle => GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
        letterSpacing: 0,
      );

  static TextStyle get cardBody => GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFF374151),
        height: 1.45,
        letterSpacing: 0,
      );

  static TextStyle get cardMeta => GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: inkMuted,
        letterSpacing: 0,
      );

  static TextStyle get statusPill => GoogleFonts.roboto(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: ink,
        letterSpacing: 0,
      );
}
