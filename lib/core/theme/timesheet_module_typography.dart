import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'timesheet_module_colors.dart';

/// Typography scale for Project Site Timesheet — Module 6 SRD §10.2.
abstract final class TimesheetModuleTypography {
  static TextStyle display() => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: TimesheetModuleColors.text,
      );

  static TextStyle h1() => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: TimesheetModuleColors.text,
      );

  static TextStyle h2() => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: TimesheetModuleColors.text,
      );

  static TextStyle cardTitle() => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: TimesheetModuleColors.text,
      );

  static TextStyle body() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: TimesheetModuleColors.text,
      );

  static TextStyle caption() => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: TimesheetModuleColors.mutedText,
      );

  static TextStyle statValue() => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: TimesheetModuleColors.text,
      );

  static TextStyle statLabel() => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: TimesheetModuleColors.mutedText,
      );

  static TextStyle button({Color color = TimesheetModuleColors.surface}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      );
}
