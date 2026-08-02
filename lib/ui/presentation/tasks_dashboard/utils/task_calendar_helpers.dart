import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:flutter/material.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Inclusive start/end for a todo on the calendar (null if undated).
({DateTime start, DateTime end})? todoDateSpan(TodoModel todo) {
  final start = todo.startDate != null ? dateOnly(todo.startDate!) : null;
  final end = todo.dueDate != null ? dateOnly(todo.dueDate!) : null;
  if (start == null && end == null) return null;
  if (start != null && end != null) {
    return start.isBefore(end)
        ? (start: start, end: end)
        : (start: end, end: start);
  }
  final single = start ?? end!;
  return (start: single, end: single);
}

bool todoOverlapsDay(TodoModel todo, DateTime day) {
  final span = todoDateSpan(todo);
  if (span == null) return false;
  final d = dateOnly(day);
  return !d.isBefore(span.start) && !d.isAfter(span.end);
}

List<TodoModel> tasksForDay(List<TodoModel> todos, DateTime day) {
  return todos.where((t) => todoOverlapsDay(t, day)).toList();
}

Color taskChipBackground(TodoModel todo) {
  final now = DateTime.now();
  final overdue = !todo.isCompleted &&
      todo.dueDate != null &&
      todo.dueDate!.isBefore(now);
  if (todo.isCompleted) return ProductivityLightTheme.statusCompletedBg;
  if (overdue) return ProductivityLightTheme.statusOverdueBg;
  if (todo.progress > 0 && todo.progress < 1) {
    return ProductivityLightTheme.statusActiveBg;
  }
  return ProductivityLightTheme.statusPendingBg;
}

Color taskChipAccent(TodoModel todo) {
  final now = DateTime.now();
  final overdue = !todo.isCompleted &&
      todo.dueDate != null &&
      todo.dueDate!.isBefore(now);
  if (todo.isCompleted) return ProductivityLightTheme.accentActive;
  if (overdue) return ProductivityLightTheme.accentEnded;
  if (todo.progress > 0 && todo.progress < 1) {
    return ProductivityLightTheme.accentTotal;
  }
  return ProductivityLightTheme.accentPending;
}

enum CalendarRangePreset { thisWeek, thisMonth, days1to10, days11to20, days21end }

({DateTime start, DateTime end}) rangeForPreset(
  CalendarRangePreset preset,
  DateTime visibleMonth,
) {
  final y = visibleMonth.year;
  final m = visibleMonth.month;
  final lastDay = DateTime(y, m + 1, 0).day;
  final monthStart = DateTime(y, m, 1);
  final monthEnd = DateTime(y, m, lastDay);

  switch (preset) {
    case CalendarRangePreset.thisWeek:
      final now = dateOnly(DateTime.now());
      final weekday = now.weekday % 7; // Sun=0 style week start
      final start = now.subtract(Duration(days: weekday));
      final end = start.add(const Duration(days: 6));
      return (start: start, end: end);
    case CalendarRangePreset.thisMonth:
      return (start: monthStart, end: monthEnd);
    case CalendarRangePreset.days1to10:
      return (start: monthStart, end: DateTime(y, m, lastDay.clamp(1, 10)));
    case CalendarRangePreset.days11to20:
      return (
        start: DateTime(y, m, lastDay < 11 ? lastDay : 11),
        end: DateTime(y, m, lastDay.clamp(11, 20)),
      );
    case CalendarRangePreset.days21end:
      return (
        start: DateTime(y, m, lastDay < 21 ? lastDay : 21),
        end: monthEnd,
      );
  }
}

String presetLabel(CalendarRangePreset preset, DateTime visibleMonth) {
  final mon = _shortMonth(visibleMonth.month);
  final lastDay = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
  switch (preset) {
    case CalendarRangePreset.thisWeek:
      return 'This week';
    case CalendarRangePreset.thisMonth:
      return 'This month';
    case CalendarRangePreset.days1to10:
      return '1–10 $mon';
    case CalendarRangePreset.days11to20:
      return '11–20 $mon';
    case CalendarRangePreset.days21end:
      return '21–$lastDay $mon';
  }
}

String _shortMonth(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[month - 1];
}

/// Builds the 6×7 cells for [visibleMonth] (leading/trailing from adjacent months).
List<DateTime> monthGridDays(DateTime visibleMonth) {
  final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
  // Dart weekday: Mon=1 … Sun=7. We use Sun-first grid.
  final leading = first.weekday % 7;
  final start = first.subtract(Duration(days: leading));
  return List.generate(42, (i) => dateOnly(start.add(Duration(days: i))));
}
