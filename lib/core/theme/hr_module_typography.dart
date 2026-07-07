import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hr_module_colors.dart';

/// Typography scale for HR Management — SRD §6.2.
/// Sizes are logical pixels; wrap with `ScreenUtil` `.sp` in UI if the screen uses it.
abstract final class HrModuleTypography {
  static TextStyle pageTitle() => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: HrModuleColors.text,
      );

  static TextStyle sectionHeading() => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: HrModuleColors.text,
      );

  static TextStyle cardTitle() => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: HrModuleColors.text,
      );

  static TextStyle body() => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: HrModuleColors.text,
      );

  static TextStyle caption() => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: HrModuleColors.mutedText,
      );

  static TextStyle counterNumber() => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: HrModuleColors.primary,
      );

  static TextStyle counterLabel() => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: HrModuleColors.mutedText,
      );

  static TextStyle button() => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: HrModuleColors.surface,
      );

  static TextStyle statusBadge({required Color color}) => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      );
}
