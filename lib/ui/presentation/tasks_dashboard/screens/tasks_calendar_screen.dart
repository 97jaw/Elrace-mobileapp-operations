import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/utils/task_calendar_helpers.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Full-screen Task Management calendar: month grid + range presets.
class TasksCalendarScreen extends StatefulWidget {
  const TasksCalendarScreen({super.key, this.embedded = false});

  /// When true, render body only (hub owns shell + bottom bar).
  final bool embedded;

  @override
  State<TasksCalendarScreen> createState() => _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends State<TasksCalendarScreen> {
  late DateTime _visibleMonth;
  CalendarRangePreset _preset = CalendarRangePreset.thisMonth;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _applyPreset(CalendarRangePreset.thisMonth, jumpMonth: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoFirebaseProvider>().loadTodos();
    });
  }

  void _applyPreset(CalendarRangePreset preset, {bool jumpMonth = true}) {
    final range = rangeForPreset(preset, _visibleMonth);
    setState(() {
      _preset = preset;
      _rangeStart = range.start;
      _rangeEnd = range.end;
      if (jumpMonth && preset == CalendarRangePreset.thisWeek) {
        _visibleMonth = DateTime(range.start.year, range.start.month);
        final refreshed = rangeForPreset(preset, _visibleMonth);
        _rangeStart = refreshed.start;
        _rangeEnd = refreshed.end;
      }
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      if (_preset != CalendarRangePreset.thisWeek) {
        final range = rangeForPreset(_preset, _visibleMonth);
        _rangeStart = range.start;
        _rangeEnd = range.end;
      }
    });
  }

  bool _inRange(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(_rangeStart) && !d.isAfter(_rangeEnd);
  }

  Future<void> _openDaySheet(DateTime day, List<TodoModel> dayTasks) async {
    if (dayTasks.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ProductivityLightTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    DateFormat('EEE, MMM d').format(day),
                    style: ProductivityLightTheme.cardTitle,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: dayTasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final todo = dayTasks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: taskChipAccent(todo),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          todo.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ProductivityLightTheme.cardSubtitle.copyWith(
                            color: ProductivityLightTheme.ink,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (todo.firebaseId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailsScreen(
                                taskId: todo.firebaseId,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<TodoFirebaseProvider>(
      builder: (context, provider, _) {
          if (provider.isLoading && provider.todos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = provider.todos;
          final days = monthGridDays(_visibleMonth);
          final monthLabel = DateFormat('MMMM yyyy').format(_visibleMonth);

          return RefreshIndicator(
            onRefresh: () => provider.loadTodos(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _shiftMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: ProductivityLightTheme.ink,
                        ),
                        Expanded(
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: ProductivityLightTheme.cardTitle,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _shiftMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: ProductivityLightTheme.ink,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final preset in CalendarRangePreset.values) ...[
                          _PresetChip(
                            label: presetLabel(preset, _visibleMonth),
                            selected: _preset == preset,
                            onTap: () => _applyPreset(preset),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (final label in const [
                          'S',
                          'M',
                          'T',
                          'W',
                          'T',
                          'F',
                          'S',
                        ])
                          Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: ProductivityLightTheme.cardMeta.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final day = days[index];
                        final inMonth = day.month == _visibleMonth.month;
                        final inRange = _inRange(day);
                        final dayTasks = inMonth
                            ? tasksForDay(todos, day)
                            : const <TodoModel>[];
                        final isToday =
                            dateOnly(day) == dateOnly(DateTime.now());

                        return _DayCell(
                          day: day,
                          inMonth: inMonth,
                          inRange: inRange,
                          isToday: isToday,
                          tasks: dayTasks,
                          onTap: () => _openDaySheet(day, dayTasks),
                        );
                      },
                      childCount: days.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
    );

    if (widget.embedded) return body;

    return ProductivityLightShell(
      showBack: true,
      title: 'Calendar',
      body: body,
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ProductivityLightTheme.ink
                : ProductivityLightTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? ProductivityLightTheme.ink
                  : ProductivityLightTheme.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? Colors.white : ProductivityLightTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.inRange,
    required this.isToday,
    required this.tasks,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool inRange;
  final bool isToday;
  final List<TodoModel> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = inMonth && !inRange;
    final visibleChips = tasks.take(2).toList();
    final overflow = tasks.length - visibleChips.length;

    return Opacity(
      opacity: inMonth ? (dimmed ? 0.38 : 1.0) : 0.22,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: inMonth ? onTap : null,
          borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: inRange && inMonth
                  ? ProductivityLightTheme.card
                  : ProductivityLightTheme.card.withValues(alpha: 0.7),
              borderRadius:
                  BorderRadius.circular(ProductivityLightTheme.boxRadius),
              border: Border.all(
                color: isToday
                    ? ProductivityLightTheme.navAccent
                    : inRange && inMonth
                        ? ProductivityLightTheme.navBarEdge
                        : ProductivityLightTheme.border,
                width: isToday ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${day.day}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: ProductivityLightTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Column(
                      children: [
                        for (final todo in visibleChips) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: taskChipBackground(todo),
                              borderRadius: BorderRadius.circular(4),
                              border: Border(
                                left: BorderSide(
                                  color: taskChipAccent(todo),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              todo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 8,
                                height: 1.1,
                                color: ProductivityLightTheme.ink,
                              ),
                            ),
                          ),
                        ],
                        if (overflow > 0)
                          Text(
                            '+$overflow',
                            style: GoogleFonts.roboto(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: ProductivityLightTheme.inkSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
