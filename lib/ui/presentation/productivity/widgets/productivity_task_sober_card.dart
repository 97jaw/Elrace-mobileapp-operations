import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_sober_card.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Applies dashboard [TaskFilter] buckets to a todo list.
List<TodoModel> applyTaskFilter(List<TodoModel> todos, TaskFilter filter) {
  switch (filter) {
    case TaskFilter.all:
      return List<TodoModel>.from(todos);
    case TaskFilter.pending:
      return todos
          .where((t) =>
              !t.isCompleted &&
              t.dueDate != null &&
              t.dueDate!.isAfter(DateTime.now()))
          .toList();
    case TaskFilter.notCompleted:
      return todos.where((t) => !t.isCompleted).toList();
    case TaskFilter.completed:
      return todos.where((t) => t.isCompleted).toList();
    case TaskFilter.open:
      return todos.where((t) => !t.isCompleted && t.progress == 0).toList();
    case TaskFilter.inProgress:
      return todos
          .where((t) => !t.isCompleted && t.progress > 0 && t.progress < 1)
          .toList();
  }
}

List<TodoModel> searchTodos(List<TodoModel> todos, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return todos;
  return todos.where((t) {
    final title = t.title.toLowerCase();
    final desc = (t.description ?? '').toLowerCase();
    final assignee = (t.assignedToName ?? '').toLowerCase();
    return title.contains(q) || desc.contains(q) || assignee.contains(q);
  }).toList();
}

List<TodoModel> sortTodosNewestFirst(List<TodoModel> todos) {
  final sorted = List<TodoModel>.from(todos)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted;
}

String memberDisplayName(String rawName) {
  final cleaned = rawName
      .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
      .trim();
  final parts =
      cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return rawName.trim();
  if (parts.length == 1) return parts.first;
  return '${parts[0]} ${parts[1]}';
}

Widget buildMemberAvatar({
  required String name,
  required Map<int, String> photoById,
  double size = 24,
}) {
  final idMatch = RegExp(r'^\s*(\d+)\s+').firstMatch(name);
  final id = idMatch != null ? int.tryParse(idMatch.group(1)!) : null;
  final url = id != null ? photoById[id] : null;
  final displayName = memberDisplayName(name);
  final initials =
      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

  if (url != null && url.isNotEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFEFEFEF),
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w500,
        color: ProductivityLightTheme.ink,
      ),
    ),
  );
}

/// Shared sober card for Task Management todos.
class ProductivityTaskSoberCard extends StatelessWidget {
  const ProductivityTaskSoberCard({
    super.key,
    required this.todo,
    required this.photoById,
    required this.onTap,
  });

  final TodoModel todo;
  final Map<int, String> photoById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = !todo.isCompleted &&
        todo.dueDate != null &&
        todo.dueDate!.isBefore(now);

    late final String statusLabel;
    late final Color statusBg;
    if (todo.isCompleted) {
      statusLabel = 'Completed';
      statusBg = ProductivityLightTheme.statusCompletedBg;
    } else if (overdue) {
      statusLabel = 'Overdue';
      statusBg = ProductivityLightTheme.statusOverdueBg;
    } else if (todo.progress > 0 && todo.progress < 1) {
      statusLabel = 'Active';
      statusBg = ProductivityLightTheme.statusActiveBg;
    } else {
      statusLabel = 'Pending';
      statusBg = ProductivityLightTheme.statusPendingBg;
    }

    final names = (todo.assignedMembers != null &&
            todo.assignedMembers!.isNotEmpty)
        ? todo.assignedMembers!
            .map((m) => m.name.trim())
            .where((n) => n.isNotEmpty)
            .toList()
        : (todo.assignedToName ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final primaryName = names.isEmpty ? null : names.first;
    final subtitle = primaryName == null
        ? 'Unassigned'
        : memberDisplayName(primaryName);

    String? dateText;
    if (todo.startDate != null || todo.dueDate != null) {
      final start = todo.startDate != null
          ? DateFormat('MMM d').format(todo.startDate!)
          : null;
      final end = todo.dueDate != null
          ? DateFormat('MMM d').format(todo.dueDate!)
          : null;
      if (start != null && end != null) {
        dateText = '$start – $end';
      } else {
        dateText = end ?? start;
      }
    }

    return ProductivitySoberCard(
      title: todo.title,
      statusLabel: statusLabel,
      statusBackground: statusBg,
      leadingAvatar: primaryName != null
          ? buildMemberAvatar(
              name: primaryName,
              photoById: photoById,
              size: 24,
            )
          : null,
      subtitle: subtitle,
      dateText: dateText,
      progress: todo.isCompleted ? 1.0 : todo.progress,
      onTap: onTap,
    );
  }
}
