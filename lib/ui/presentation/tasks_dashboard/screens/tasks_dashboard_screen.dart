import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_widgets.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_nav.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_task_sober_card.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_all_list_screen.dart';
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/screens/ticket_details_screen.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';

class TasksDashboardScreen extends StatefulWidget {
  const TasksDashboardScreen({
    Key? key,
    this.initialFilter,
    this.embedded = false,
  }) : super(key: key);

  /// Prefer [ProductivityHubScreen.routeName] for entry navigation.
  static const routeName = '/productivity_home';

  final TaskFilter? initialFilter;

  /// When true, render body only (hub owns shell + bottom bar).
  final bool embedded;

  @override
  State<TasksDashboardScreen> createState() => _TasksDashboardScreenState();
}

class _TasksDashboardScreenState extends State<TasksDashboardScreen> {
  Map<int, String> _memberPhotoById = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoFirebaseProvider>().loadTodos();
      context.read<TicketFirebaseProvider>().loadTickets();
      _loadMemberPhotos();
    });
  }

  Future<void> _loadMemberPhotos() async {
    try {
      final members =
          await TeamMembersApiService.instance.getTeamMembers(forceRefresh: true);
      final map = <int, String>{};
      for (final m in members) {
        final url = m.image?.trim();
        if (url != null && url.isNotEmpty) {
          map[m.id] = url;
          if (m.employeeId != null) map[m.employeeId!] = url;
        }
      }
      if (!mounted) return;
      setState(() => _memberPhotoById = map);
    } catch (_) {}
  }

  List<TodoModel> _latestFive(List<TodoModel> todos) {
    return sortTodosNewestFirst(_scopedTodos(todos)).take(5).toList();
  }

  List<TodoModel> _scopedTodos(List<TodoModel> todos) {
    return applyTaskFilter(todos, widget.initialFilter ?? TaskFilter.all);
  }

  void _openAllTasks({TaskFilter filter = TaskFilter.all}) {
    if (widget.embedded) {
      ProductivityNav.goTasks(context, filter: filter);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TasksAllListScreen(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer2<TodoFirebaseProvider, TicketFirebaseProvider>(
        builder: (context, provider, ticketsProvider, _) {
          final allTodos = provider.todos;
          final latestTodos = _latestFive(allTodos);
          final latestTickets = ticketsProvider.tickets.take(5).toList();

          final totalTasks = allTodos.length;
          final pendingTasks = allTodos
              .where((t) =>
                  !t.isCompleted &&
                  t.dueDate != null &&
                  t.dueDate!.isAfter(DateTime.now()))
              .length;
          final activeTasks = allTodos
              .where((t) => !t.isCompleted && t.progress > 0 && t.progress < 1)
              .length;
          final endedTasks = allTodos.where((t) => t.isCompleted).length;

          if (provider.isLoading && allTodos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadTodos();
              await ticketsProvider.loadTickets();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: ProductivityLightHero(
                    eyebrow: 'Get Focused',
                    title: 'Productivity Showcase!',
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProductivityStatsGrid(
                    items: [
                      ProductivityStatItem(
                        label: 'Total Task',
                        value: totalTasks,
                        icon: Icons.assignment_outlined,
                        accent: ProductivityLightTheme.accentTotal,
                        sparkHighlightStart: 3,
                        sparkHighlightEnd: 5,
                        onTap: () => _openAllTasks(filter: TaskFilter.all),
                      ),
                      ProductivityStatItem(
                        label: 'Pending Task',
                        value: pendingTasks,
                        icon: Icons.description_outlined,
                        accent: ProductivityLightTheme.accentPending,
                        sparkHighlightStart: 5,
                        sparkHighlightEnd: 7,
                        onTap: () =>
                            _openAllTasks(filter: TaskFilter.pending),
                      ),
                      ProductivityStatItem(
                        label: 'Active Task',
                        value: activeTasks,
                        icon: Icons.folder_open_outlined,
                        accent: ProductivityLightTheme.accentActive,
                        sparkHighlightStart: 4,
                        sparkHighlightEnd: 6,
                        onTap: () =>
                            _openAllTasks(filter: TaskFilter.inProgress),
                      ),
                      ProductivityStatItem(
                        label: 'Ended Task',
                        value: endedTasks,
                        icon: Icons.task_alt_outlined,
                        accent: ProductivityLightTheme.accentEnded,
                        sparkHighlightStart: 2,
                        sparkHighlightEnd: 5,
                        onTap: () =>
                            _openAllTasks(filter: TaskFilter.completed),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                    child: Row(
                      children: [
                        _MiniStat(
                          label: 'Tickets',
                          value: ticketsProvider.tickets.length,
                          onTap: () => ProductivityNav.goTickets(context),
                        ),
                        const SizedBox(width: 10),
                        _MiniStat(
                          label: 'Open',
                          value: ticketsProvider.openCount,
                          onTap: () => ProductivityNav.goTickets(context),
                        ),
                        const SizedBox(width: 10),
                        _MiniStat(
                          label: 'Active',
                          value: ticketsProvider.inProgressCount,
                          onTap: () => ProductivityNav.goTickets(context),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                    child: Row(
                      children: [
                        Text(
                          'Currently Tasks',
                          style: ProductivityLightTheme.sectionLabel,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _openAllTasks(),
                          child: Text(
                            'See all',
                            style: ProductivityLightTheme.cardMeta.copyWith(
                              color: ProductivityLightTheme.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (latestTodos.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tasks',
                        textAlign: TextAlign.center,
                        style: ProductivityLightTheme.cardSubtitle,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final todo = latestTodos[index];
                        return ProductivityTaskSoberCard(
                          todo: todo,
                          photoById: _memberPhotoById,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailsScreen(taskId: todo.firebaseId),
                              ),
                            );
                          },
                        );
                      },
                      childCount: latestTodos.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                    child: Row(
                      children: [
                        Text(
                          'Currently Tickets',
                          style: ProductivityLightTheme.sectionLabel,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => ProductivityNav.goTickets(context),
                          child: Text(
                            'See all',
                            style: ProductivityLightTheme.cardMeta.copyWith(
                              color: ProductivityLightTheme.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (latestTickets.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tickets',
                        textAlign: TextAlign.center,
                        style: ProductivityLightTheme.cardSubtitle,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ticket = latestTickets[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: ProductivityLightTheme.border,
                              ),
                            ),
                            tileColor: ProductivityLightTheme.card,
                            title: Text(
                              ticket.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ProductivityLightTheme.cardSubtitle
                                  .copyWith(color: ProductivityLightTheme.ink),
                            ),
                            subtitle: Text(ticket.status.label),
                            trailing: Text(
                              ticket.priority.label,
                              style: ProductivityLightTheme.cardMeta,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TicketDetailsScreen(
                                    ticketId: ticket.firebaseId!,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: latestTickets.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
    );

    if (widget.embedded) return body;

    return ProductivityLightShell(
      showBack: false,
      body: body,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: ProductivityLightTheme.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ProductivityLightTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ProductivityLightTheme.cardMeta),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style:
                      ProductivityLightTheme.cardTitle.copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
