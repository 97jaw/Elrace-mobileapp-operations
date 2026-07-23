import 'package:el_race/ui/presentation/my_documents/screens/shared_documents_screen.dart';
import 'package:el_race/ui/presentation/tasks/tasks_screen.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart';
import 'package:flutter/material.dart';

/// Deep-links from Productivity home widgets into live task/ticket modules.
class HomeProductivityNavigation {
  HomeProductivityNavigation._();

  static void openTaskManagement(
    BuildContext context, {
    TaskFilter? filter,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TasksDashboardScreen(initialFilter: filter),
      ),
    );
  }

  static void openTickets(
    BuildContext context, {
    bool highPriorityOnly = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TasksScreen(highPriorityOnly: highPriorityOnly),
      ),
    );
  }

  static void openSharedDocuments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SharedDocumentsScreen(),
      ),
    );
  }
}
