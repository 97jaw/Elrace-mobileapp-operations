import 'package:flutter/material.dart';

/// Shadow tokens for Project Site Timesheet — Module 6 SRD §10.4.
abstract final class TimesheetModuleShadows {
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F14182F),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> fabShadow = [
    BoxShadow(
      color: Color(0x598B2635),
      offset: Offset(0, 12),
      blurRadius: 24,
    ),
  ];
}
