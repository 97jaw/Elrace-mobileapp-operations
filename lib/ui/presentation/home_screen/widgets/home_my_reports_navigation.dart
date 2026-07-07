import 'package:el_race/ui/presentation/my_reports/screens/my_reports_hub_screen.dart';
import 'package:flutter/material.dart';

/// Opens the AI-first My Reports hub.
abstract final class HomeMyReportsNavigation {
  static void open(BuildContext context, {required String metricType}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyReportsHubScreen()),
    );
  }
}
