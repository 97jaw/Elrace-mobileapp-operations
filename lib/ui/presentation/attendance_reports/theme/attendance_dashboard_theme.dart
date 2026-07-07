import 'package:flutter/material.dart';

/// Design tokens for the Attendance Dashboard redesign.
abstract final class AttendanceDashboardTheme {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const scaffoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF4FF),
      Color(0xFFF5F8FF),
      Color(0xFFFFFFFF),
    ],
  );

  static const appBarColor = Color(0xFF1A3A6B);
  static const appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3A6B), Color(0xFF1E4DB7)],
  );

  // ── Card surfaces ─────────────────────────────────────────────────────────
  static const cardSurface = Colors.white;
  static const cardRadius = 14.0;
  static BoxDecoration cardDecoration({
    Color? accent,
    double accentHeight = 4,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: cardSurface,
      borderRadius: BorderRadius.circular(cardRadius),
      border: accent != null
          ? Border(top: BorderSide(color: accent, width: accentHeight))
          : null,
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  // ── Stat card accent colors ──────────────────────────────────────────────
  static const accentTotal   = Color(0xFF1E4DB7);
  static const accentOnTime  = Color(0xFF16A34A);
  static const accentLate    = Color(0xFFD97706);
  static const accentAbsent  = Color(0xFFDC2626);
  static const accentJmTp    = Color(0xFF0284C7);   // sky-600 — no purple
  static const accentLeaves  = Color(0xFF0D9488);   // teal-600
  static const accentReview  = Color(0xFF6B7280);   // kept for compat

  static Color accentFill(Color accent) => accent.withValues(alpha: 0.08);

  // ── Filter chip colors ───────────────────────────────────────────────────
  static const filterActive   = Color(0xFF1E4DB7);
  static const filterInactive = Color(0xFFE5E7EB);
  static const filterText     = Colors.white;
  static const filterInactiveText = Color(0xFF374151);

  // ── Typography ───────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);

  static TextStyle statValue({double fontSize = 28}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        height: 1.0,
      );

  static TextStyle statLabel({double fontSize = 11}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.3,
      );

  static TextStyle sectionTitle({double fontSize = 15}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );
}
