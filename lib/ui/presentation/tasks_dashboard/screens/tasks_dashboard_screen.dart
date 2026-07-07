import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:el_race/ui/presentation/my_reports/screens/my_reports_hub_screen.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_screen_shell.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/add_task.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';

enum TaskFilter { all, pending, notCompleted, completed, open, inProgress }

class TasksDashboardScreen extends StatefulWidget {
  const TasksDashboardScreen({Key? key, this.initialFilter}) : super(key: key);

  final TaskFilter? initialFilter;

  @override
  State<TasksDashboardScreen> createState() => _TasksDashboardScreenState();
}

class _TasksDashboardScreenState extends State<TasksDashboardScreen> {
  late TaskFilter _selectedFilter;
  Map<int, String> _memberPhotoById = {};
  Map<int, TeamMember> _memberById = {};
  bool _isLoadingMemberPhotos = false;
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? TaskFilter.all;
    // Create a stream that emits current time every day to update days countdown
    _timeStream =
        Stream.periodic(const Duration(days: 1), (_) => DateTime.now());

    // Load tasks from Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoFirebaseProvider>().loadTodos();
      _loadMemberPhotos();
    });
  }

  Future<void> _loadMemberPhotos() async {
    if (_isLoadingMemberPhotos) return;
    setState(() => _isLoadingMemberPhotos = true);

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers(forceRefresh: true);
      final map = <int, String>{};
      final memberMap = <int, TeamMember>{};
      for (final m in members) {
        final url = m.image?.trim();
        if (url != null && url.isNotEmpty) {
          map[m.id] = url;
          if (m.employeeId != null) map[m.employeeId!] = url;
        }
        memberMap[m.id] = m;
        if (m.employeeId != null) memberMap[m.employeeId!] = m;
      }
      if (!mounted) return;
      setState(() {
        _memberPhotoById = map;
        _memberById = memberMap;
      });
    } catch (_) {
      // ignore (fallback to initials)
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingMemberPhotos = false);
    }
  }

  int? _extractLeadingId(String name) {
    final match = RegExp(r'^\s*(\d+)\s+').firstMatch(name);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  String? _photoUrlForDisplayName(String name) {
    final id = _extractLeadingId(name);
    if (id == null) return null;
    return _memberPhotoById[id];
  }

  TeamMember? _memberForDisplayName(String name) {
    final id = _extractLeadingId(name);
    if (id == null) return null;
    return _memberById[id];
  }

  String _memberDisplayName(String rawName) {
    final cleaned = rawName
        .replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return rawName.trim();
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  Widget _buildAvatarForName(String name, {double size = 42}) {
    final url = _photoUrlForDisplayName(name);
    final displayName = _memberDisplayName(name);
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD9D9D9),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFEFEFEF),
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, __) {},
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD9D9D9),
          width: 2,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFFEFEFEF),
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  List<TodoModel> _filterTodos(List<TodoModel> todos) {
    switch (_selectedFilter) {
      case TaskFilter.all:
        return todos;
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
        return todos
            .where((t) => !t.isCompleted && t.progress == 0)
            .toList();
      case TaskFilter.inProgress:
        return todos
            .where((t) =>
                !t.isCompleted && t.progress > 0 && t.progress < 1)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductivityScreenShell(
      title: 'Task Management',
      body: Consumer<TodoFirebaseProvider>(
        builder: (context, provider, child) {
          final allTodos = provider.todos;
          final filteredTodos = _filterTodos(allTodos);

          // Calculate statistics
          final totalTasks = allTodos.length;
          final completedTasks = allTodos.where((t) => t.isCompleted).length;
          final overdueTasks = allTodos
              .where((t) =>
                  !t.isCompleted &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(DateTime.now()))
              .length;
          final pendingReports = allTodos
              .where((t) => t.reportId != null && !t.isCompleted)
              .length;

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            "assets/png/Tasks.svg",
                            height: 24.w,
                            width: 24.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'TASKS DASHBOARD',
                            style: GoogleFonts.poppins(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w500,
                              color: appFontColor,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _TotalTasksCard(
                                totalTasks: totalTasks,
                                overdueTasks: overdueTasks,
                                completedTasks: completedTasks,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _PendingReportsCard(
                                pendingReports: pendingReports,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _FilterTabs(
                      selectedFilter: _selectedFilter,
                      onFilterChanged: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Text(
                            'Total TASKS (${filteredTodos.length})',
                            style: const TextStyle(
                              color: Color(0xFFB0B0B0),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Spacer(),
                          const AddTaskButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredTodos.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 80.w,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No tasks',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final todo = filteredTodos[index];
                      return _TaskCard(
                        todo: todo,
                        onToggleComplete: () {
                          provider.updateTodo(
                            todo.copyWith(isCompleted: !todo.isCompleted),
                          );
                        },
                        buildAvatar: _buildAvatarForName,
                        memberDisplayName: _memberDisplayName,
                        memberForDisplayName: _memberForDisplayName,
                      );
                    },
                    childCount: filteredTodos.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// بطاقة إجمالي المهام
class _TotalTasksCard extends StatelessWidget {
  final int totalTasks;
  final int overdueTasks;
  final int completedTasks;

  const _TotalTasksCard({
    required this.totalTasks,
    required this.overdueTasks,
    required this.completedTasks,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: const LinearGradient(
          colors: [Color(0xFF039BE5), Color(0xFF4DD0E1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: Text(
                    'TOTAL TASKS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$totalTasks',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 50.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6.0),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Overdue ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                      TextSpan(
                        text: 'Tasks $overdueTasks',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 12.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24.0),
                bottomRight: Radius.circular(24.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completedTasks task completed',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12.0,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 6.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3.0),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6.0,
                    backgroundColor: Colors.grey.shade300,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة التقارير المعلقة
class _PendingReportsCard extends StatelessWidget {
  final int pendingReports;

  const _PendingReportsCard({required this.pendingReports});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF90CAF9),
                  Color(0xFF9FA8DA),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PENDING REPORTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: null,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '$pendingReports',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyReportsHubScreen(),
                ),
              );
            },
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: const Center(
                child: Text(
                  'View Reports',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فلاتر المهام
class _FilterTabs extends StatelessWidget {
  final TaskFilter selectedFilter;
  final Function(TaskFilter) onFilterChanged;

  const _FilterTabs({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTab('ALL TASKS', TaskFilter.all),
          const SizedBox(width: 12),
          _buildTab('PENDING', TaskFilter.pending),
          const SizedBox(width: 12),
          _buildTab('NOT COMPLETED', TaskFilter.notCompleted),
          const SizedBox(width: 12),
          _buildTab('COMPLETED', TaskFilter.completed),
        ],
      ),
    );
  }

  Widget _buildTab(String text, TaskFilter filter) {
    final isSelected = selectedFilter == filter;
    return GestureDetector(
      onTap: () => onFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFFC0DBEE),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// بطاقة المهمة
class _TaskCard extends StatefulWidget {
  final TodoModel todo;
  final VoidCallback onToggleComplete;
  final Widget Function(String name, {double size}) buildAvatar;
  final String Function(String name) memberDisplayName;
  final TeamMember? Function(String name) memberForDisplayName;

  const _TaskCard({
    required this.todo,
    required this.onToggleComplete,
    required this.buildAvatar,
    required this.memberDisplayName,
    required this.memberForDisplayName,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    // Update every day to reflect days countdown changes
    _timeStream =
        Stream.periodic(const Duration(days: 1), (_) => DateTime.now());
  }

  TaskStatus get _status {
    if (widget.todo.isCompleted) return TaskStatus.completed;
    if (widget.todo.dueDate != null &&
        widget.todo.dueDate!.isBefore(DateTime.now())) {
      return TaskStatus.overdue;
    }
    return TaskStatus.pending;
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending:
        return const Color(0xFFFF9800);
      case TaskStatus.completed:
        return const Color(0xFF0F9D58);
      case TaskStatus.overdue:
        return const Color(0xFFC62828);
    }
  }

  int _getRemainingDays(DateTime now) {
    if (widget.todo.dueDate == null) return 0;
    return widget.todo.dueDate!.difference(now).inDays;
  }

  double _getProgress(DateTime now) {
    if (widget.todo.isCompleted) return 1.0;
    if (widget.todo.dueDate == null || widget.todo.createdAt == null)
      return 0.0;

    final total =
        widget.todo.dueDate!.difference(widget.todo.createdAt!).inDays;
    final elapsed = now.difference(widget.todo.createdAt!).inDays;

    if (total <= 0) return 0.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusColor = _statusColor(status);

    return StreamBuilder<DateTime>(
      stream: _timeStream,
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final remainingDays = _getRemainingDays(now);
        final progress = _getProgress(now);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailsScreen(task: widget.todo),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD0D0D0)),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // LEFT
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Text(
                              widget.todo.title.toUpperCase(),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                decoration: widget.todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final names = (widget.todo.assignedMembers != null &&
                                  widget.todo.assignedMembers!.isNotEmpty)
                                ? widget.todo.assignedMembers!
                                  .map((member) => member.name.trim())
                                  .where((name) => name.isNotEmpty)
                                  .toList()
                                : (widget.todo.assignedToName ?? '')
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              if (names.isEmpty) {
                                return Row(
                                  children: [
                                    widget.buildAvatar('U', size: 36),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Unassigned',
                                      maxLines: null,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: names
                                    .map(
                                      (name) {
                                        final displayName = widget.memberDisplayName(name);
                                        final member = widget.memberForDisplayName(name);
                                        final department = member?.department?.trim();

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              widget.buildAvatar(name, size: 36),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      displayName,
                                                      maxLines: null,
                                                      overflow: TextOverflow.visible,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    if (department != null && department.isNotEmpty)
                                                      Text(
                                                        department,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF9AA3AE),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          if (widget.todo.listId != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 44, top: 4),
                              child: Consumer<TodoFirebaseProvider>(
                                builder: (context, provider, _) {
                                  final list = provider.todoLists.firstWhere(
                                    (l) => l.firebaseId == widget.todo.listId,
                                    orElse: () => provider.todoLists.isNotEmpty
                                        ? provider.todoLists.first
                                        : throw Exception('No list found'),
                                  );
                                  return Text(
                                    list.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9AA3AE),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final trackWidth = constraints.maxWidth;
                              final progressLocal = progress;

                              const double iconSize = 16;
                              final double coloredWidth =
                                  trackWidth * progressLocal;
                              final double iconLeft =
                                  (coloredWidth - iconSize / 2)
                                      .clamp(0.0, trackWidth - iconSize);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 24,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                            height: 4,
                                            width: double.infinity,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                            height: 4,
                                            width: coloredWidth,
                                            color: statusColor,
                                          ),
                                        ),
                                        Positioned(
                                          left: iconLeft,
                                          bottom: 4,
                                          child: Image.asset(
                                            progressLocal < 1.0
                                                ? 'assets/png/walker-man.png'
                                                : 'assets/png/stand.png',
                                            width: iconSize,
                                            height: iconSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.todo.dueDate != null
                                        ? DateFormat('h:mm a')
                                            .format(widget.todo.dueDate!)
                                        : '--:--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9AA3AE),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 72,
                      color: const Color(0xFFD9D9D9),
                    ),
                    const SizedBox(width: 10),
                    // RIGHT
                    SizedBox(
                      width: 86,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'START DATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF11A84A),
                            ),
                          ),
                          Text(
                            widget.todo.createdAt != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(widget.todo.createdAt!)
                                    .toUpperCase()
                                : '--',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9AA3AE),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'END DATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                          Text(
                            widget.todo.dueDate != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(widget.todo.dueDate!)
                                    .toUpperCase()
                                : '--',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9AA3AE),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${remainingDays.abs()}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFBDBDBD),
                                  height: 0.9,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                remainingDays >= 0 ? 'Days' : 'Late',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: remainingDays >= 0
                                      ? const Color(0xFFBDBDBD)
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: widget.onToggleComplete,
                    child: StarburstBadge(
                      size: 22,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum TaskStatus { completed, pending, overdue }

/// ⭐ Starburst badge مثل الصورة (مسنن)
class StarburstBadge extends StatelessWidget {
  final double size;
  final Color color;

  const StarburstBadge({
    Key? key,
    required this.size,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StarburstPainter(color: color, points: 12, innerRatio: 0.72),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final Color color;
  final int points;
  final double innerRatio;

  _StarburstPainter({
    required this.color,
    required this.points,
    required this.innerRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * innerRatio;

    final path = Path();
    final total = points * 2;
    for (int i = 0; i < total; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final angle =
          (i * (3.141592653589793 * 2) / total) - (3.141592653589793 / 2);
      final x = cx + r * Math.cos(angle);
      final y = cy + r * Math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.points != points ||
        oldDelegate.innerRatio != innerRatio;
  }
}

class AddTaskButton extends StatelessWidget {
  const AddTaskButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AddTaskScreen(),
          ),
        );

        if (created == true && context.mounted) {
          await context.read<TodoFirebaseProvider>().loadTodos();
          await context.read<TodoFirebaseProvider>().refreshCounts();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'ADD TASK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
