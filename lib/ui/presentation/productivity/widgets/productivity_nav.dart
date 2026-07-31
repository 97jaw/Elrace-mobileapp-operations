import 'package:el_race/ui/presentation/productivity/screens/productivity_hub_screen.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_hub_scope.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_bottom_bar.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/add_task.dart';
import 'package:el_race/ui/presentation/tickets/screens/create_ticket_sheet.dart';
import 'package:flutter/material.dart';

/// Shared navigation for Task Management — tabs switch in-hub; nested pushes only.
abstract final class ProductivityNav {
  static void openHub(
    BuildContext context, {
    ProductivityLightNavTab tab = ProductivityLightNavTab.home,
    TaskFilter tasksFilter = TaskFilter.all,
    bool ticketsHighPriorityOnly = false,
  }) {
    final hub = ProductivityHubScope.maybeOf(context);
    if (hub != null) {
      hub.selectTab(
        tab,
        tasksFilter: tasksFilter,
        ticketsHighPriorityOnly: ticketsHighPriorityOnly,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: ProductivityHubScreen.routeName),
        builder: (_) => ProductivityHubScreen(
          initialTab: tab,
          tasksFilter: tasksFilter,
          ticketsHighPriorityOnly: ticketsHighPriorityOnly,
        ),
      ),
    );
  }

  static void goHome(BuildContext context) {
    openHub(context);
  }

  static void goTasks(
    BuildContext context, {
    TaskFilter filter = TaskFilter.all,
  }) {
    openHub(
      context,
      tab: ProductivityLightNavTab.tasks,
      tasksFilter: filter,
    );
  }

  static void goTickets(
    BuildContext context, {
    bool highPriorityOnly = false,
  }) {
    openHub(
      context,
      tab: ProductivityLightNavTab.tickets,
      ticketsHighPriorityOnly: highPriorityOnly,
    );
  }

  static void goCalendar(BuildContext context) {
    openHub(context, tab: ProductivityLightNavTab.calendar);
  }

  static void goAddTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }

  static Future<void> goAddTicket(
    BuildContext context, {
    String? parentTaskId,
    String? parentTaskTitle,
  }) {
    return CreateTicketSheet.show(
      context,
      parentTaskId: parentTaskId,
      parentTaskTitle: parentTaskTitle,
    );
  }

  /// Center + : tickets tab → create ticket; otherwise create task.
  static void onCenterAdd(
    BuildContext context,
    ProductivityLightNavTab selected,
  ) {
    if (selected == ProductivityLightNavTab.tickets) {
      goAddTicket(context);
    } else {
      goAddTask(context);
    }
  }
}
