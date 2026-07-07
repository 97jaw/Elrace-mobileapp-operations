import 'package:flutter/material.dart';

import 'my_report_type.dart';

enum MyReportCategoryType {
  hr,
  project,
  clientInvoice,
  purchase,
  timesheet,
  attendance,
  pettyCash,
  management,
}

class MyReportCategory {
  const MyReportCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.types,
  });

  final MyReportCategoryType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final List<MyReportType> types;
}
