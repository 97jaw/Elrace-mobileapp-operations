import 'package:el_race/ui/presentation/productivity/widgets/productivity_hub_scope.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_bottom_bar.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_nav.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_all_list_screen.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_calendar_screen.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart';
import 'package:el_race/ui/presentation/tickets/screens/tickets_list_screen.dart';
import 'package:flutter/material.dart';

/// Single productivity entry: fixed bottom bar + tab content (standard pattern).
class ProductivityHubScreen extends StatefulWidget {
  const ProductivityHubScreen({
    super.key,
    this.initialTab = ProductivityLightNavTab.home,
    this.tasksFilter = TaskFilter.all,
    this.ticketsHighPriorityOnly = false,
  });

  static const routeName = '/productivity_home';

  final ProductivityLightNavTab initialTab;
  final TaskFilter tasksFilter;
  final bool ticketsHighPriorityOnly;

  @override
  State<ProductivityHubScreen> createState() => _ProductivityHubScreenState();
}

class _ProductivityHubScreenState extends State<ProductivityHubScreen> {
  late ProductivityLightNavTab _tab;
  late TaskFilter _tasksFilter;
  late bool _ticketsHighPriorityOnly;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _tasksFilter = widget.tasksFilter;
    _ticketsHighPriorityOnly = widget.ticketsHighPriorityOnly;
  }

  void _selectTab(
    ProductivityLightNavTab tab, {
    TaskFilter? tasksFilter,
    bool? ticketsHighPriorityOnly,
  }) {
    setState(() {
      _tab = tab;
      if (tasksFilter != null) {
        _tasksFilter = tasksFilter;
      }
      if (ticketsHighPriorityOnly != null) {
        _ticketsHighPriorityOnly = ticketsHighPriorityOnly;
      }
    });
  }

  int get _index {
    switch (_tab) {
      case ProductivityLightNavTab.home:
        return 0;
      case ProductivityLightNavTab.tasks:
        return 1;
      case ProductivityLightNavTab.tickets:
        return 2;
      case ProductivityLightNavTab.calendar:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductivityHubScope(
      selected: _tab,
      selectTab: _selectTab,
      child: ProductivityLightShell(
        showBack: false,
        bottomNavigationBar: ProductivityLightBottomBar(
          selected: _tab,
          onHome: () => _selectTab(ProductivityLightNavTab.home),
          onTasks: () => _selectTab(ProductivityLightNavTab.tasks),
          onAdd: () => ProductivityNav.onCenterAdd(context, _tab),
          onTickets: () => _selectTab(
            ProductivityLightNavTab.tickets,
            ticketsHighPriorityOnly: false,
          ),
          onCalendar: () => _selectTab(ProductivityLightNavTab.calendar),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            const TasksDashboardScreen(embedded: true),
            TasksAllListScreen(
              key: ValueKey(_tasksFilter),
              embedded: true,
              initialFilter: _tasksFilter,
            ),
            TicketsListScreen(
              key: ValueKey(_ticketsHighPriorityOnly),
              embedded: true,
              highPriorityOnly: _ticketsHighPriorityOnly,
            ),
            const TasksCalendarScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
