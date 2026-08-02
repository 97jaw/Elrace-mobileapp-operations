import 'package:el_race/ui/presentation/my_documents/screens/shared_documents_screen.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_bottom_bar.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_nav.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:flutter/material.dart';

/// Deep-links from Productivity home widgets into live task/ticket modules.
class HomeProductivityNavigation {
  HomeProductivityNavigation._();

  /// Always opens the productivity hub on the Home tab.
  static void openTaskManagement(
    BuildContext context, {
    TaskFilter? filter,
  }) {
    ProductivityNav.openHub(
      context,
      tab: ProductivityLightNavTab.home,
      tasksFilter: filter ?? TaskFilter.all,
    );
  }

  static void openTickets(
    BuildContext context, {
    bool highPriorityOnly = false,
  }) {
    ProductivityNav.openHub(
      context,
      tab: ProductivityLightNavTab.tickets,
      ticketsHighPriorityOnly: highPriorityOnly,
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
