import 'package:flutter/material.dart';

/// HR Management module palette — SRD §6.1.
/// Use for Module 1 screens only unless design approves reuse elsewhere.
abstract final class HrModuleColors {
  static const Color primary = Color(0xFF1F3A5F);
  static const Color secondary = Color(0xFF4A6B8A);
  static const Color accent = Color(0xFF8B2635);
  static const Color lightBg = Color(0xFFF5F8FB);
  static const Color surface = Color(0xFFFFFFFF);

  /// HR Requests — very light sea green gradient (top → bottom).
  static const Color requestsGradientTop = Color(0xFFF8FCFA);
  static const Color requestsGradientMid = Color(0xFFF3FAF7);
  static const Color requestsGradientBottom = Color(0xFFECF7F2);

  /// Pill tab bar track on gradient background.
  static const Color requestsTabTrack = Color(0xFFD4EBE3);

  /// Recruitment — very light blue gradient (top → bottom).
  static const Color recruitmentGradientTop = Color(0xFFF6FAFF);
  static const Color recruitmentGradientMid = Color(0xFFEEF5FC);
  static const Color recruitmentGradientBottom = Color(0xFFE3EFFA);

  /// Pill tab track on recruitment gradient.
  static const Color recruitmentTabTrack = Color(0xFFC5D9F0);

  /// Performance evaluation — very light gray gradient.
  static const Color performanceGradientTop = Color(0xFFF8F9FA);
  static const Color performanceGradientMid = Color(0xFFF1F3F5);
  static const Color performanceGradientBottom = Color(0xFFE9ECEF);

  /// Dropdown / chip track on performance gradient.
  static const Color performanceTabTrack = Color(0xFFDEE2E6);

  /// Payslips — very light purple gradient.
  static const Color payslipGradientTop = Color(0xFFFAF8FC);
  static const Color payslipGradientMid = Color(0xFFF5F0FA);
  static const Color payslipGradientBottom = Color(0xFFEDE6F5);

  static const Color payslipTabTrack = Color(0xFFD9CCE8);
  static const Color payslipAccent = Color(0xFF6B4C9A);
  static const Color text = Color(0xFF1A1A1A);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color border = Color(0xFFC5CDD6);
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFC77700);
  static const Color danger = Color(0xFF8B2635);

  /// SRD §6.3 — 0 x, 2 y, 4 blur, primary @ 8% opacity.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ];
}
