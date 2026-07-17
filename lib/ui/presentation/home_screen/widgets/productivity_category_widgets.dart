import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_notes_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_productivity_navigation.dart';
import 'package:el_race/ui/presentation/my_notes/screens/my_notes_screen.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/tasks_dashboard_screen.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// v7 Productivity category — Task Management (full), Notes + Tickets (half).
class ProductivityCategoryTaskManagementCard extends StatefulWidget {
  const ProductivityCategoryTaskManagementCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  State<ProductivityCategoryTaskManagementCard> createState() =>
      _ProductivityCategoryTaskManagementCardState();
}

class _ProductivityCategoryTaskManagementCardState
    extends State<ProductivityCategoryTaskManagementCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TodoFirebaseProvider>().loadTodos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoFirebaseProvider>(
      builder: (context, todoProvider, _) {
        final data = todoProvider.taskManagementRecord;

        return _ProductivityFullCardShell(
      onTap: () => HomeProductivityNavigation.openTaskManagement(context),
      height: widget.tabletCompact ? double.infinity : 150.uh,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4A8FF5),
          Color(0xFF2D7FF0),
          Color(0xFF1E6BE0),
          Color(0xFF1858C0),
        ],
      ),
      iconBadge: const _GlassIconBadge(
        icon: Icons.checklist_rounded,
        iconColor: Colors.white,
        background: Color(0x33FFFFFF),
      ),
      pattern: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -48.w,
            top: -52.uh,
            child: Container(
              width: 200.w,
              height: 200.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _CheckmarkPatternPainter()),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: GoogleFonts.poppins(
              fontSize: 8.usp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 2.uh),
          Text(
            'Task Management',
            style: GoogleFonts.poppins(
              fontSize: 14.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          SizedBox(height: 8.uh),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TaskStatColumn(
                  label: 'Open',
                  value: '${data.openCount}',
                  valueColor: Colors.white,
                  onTap: () => HomeProductivityNavigation.openTaskManagement(
                    context,
                    filter: TaskFilter.open,
                  ),
                ),
                const _TaskStatDivider(),
                _TaskStatColumn(
                  label: 'In Progress',
                  value: '${data.inProgressCount}',
                  valueColor: const Color(0xFFF4C842),
                  onTap: () => HomeProductivityNavigation.openTaskManagement(
                    context,
                    filter: TaskFilter.inProgress,
                  ),
                ),
                const _TaskStatDivider(),
                _TaskStatColumn(
                  label: 'Done',
                  value: '${data.doneCount}',
                  valueColor: const Color(0xFF4ADE80),
                  onTap: () => HomeProductivityNavigation.openTaskManagement(
                    context,
                    filter: TaskFilter.completed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (data.dueTodayMessage.isNotEmpty)
            Text(
              data.dueTodayMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.usp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
        ],
      ),
        );
      },
    );
  }
}

class ProductivityCategoryNotesCard extends ConsumerWidget {
  const ProductivityCategoryNotesCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeNotesWidgetProvider);

    return _ProductivityHalfCardShell(
      height: null,
      onTap: () => Navigator.push(
        context,
        SlideRightPageRoute(child: const MyNotesScreen()),
      ),
      gradient: const RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Color(0xFFFFD8B8),
          Color(0xFFF5C5A8),
          Color(0xFFE8B398),
          Color(0xFFC8957D),
        ],
      ),
      iconBadge: const _GlassIconBadge(
        icon: Icons.edit_note_rounded,
        iconColor: Color(0xFF4A2F1F),
        background: Color(0x554A2F1F),
      ),
      pattern: CustomPaint(painter: _NotebookLinesPainter()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick capture',
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B3F2A),
              letterSpacing: 0.35,
            ),
          ),
          SizedBox(height: 2.uh),
          Text(
            'Notes',
            style: GoogleFonts.poppins(
              fontSize: 13.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A2F1F),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.totalCount}',
            style: GoogleFonts.poppins(
              fontSize: 30.usp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4A2F1F),
              height: 1,
            ),
          ),
          SizedBox(height: 4.uh),
          GestureDetector(
            onTap: data.lastNoteId != null
                ? () => Navigator.push(
                      context,
                      SlideRightPageRoute(child: const MyNotesScreen()),
                    )
                : null,
            child: Text(
              data.trendLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B3F2A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductivityCategoryTicketsCard extends StatelessWidget {
  const ProductivityCategoryTicketsCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(
      builder: (context, tasksProvider, _) {
        if (tasksProvider.status == TasksStatus.initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tasksProvider.loadTasks();
          });
        }

        final data = tasksProvider.ticketsWidgetRecord;
        final trendColor = _ticketsTrendColor(data.trendColor);

        return _ProductivityHalfCardShell(
      height: null,
      onTap: () => HomeProductivityNavigation.openTickets(context),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFA065B5),
          Color(0xFF8B4B9F),
          Color(0xFF6B2C7F),
          Color(0xFF4F1F60),
        ],
      ),
      iconBadge: const _GlassIconBadge(
        icon: Icons.confirmation_number_outlined,
        iconColor: Colors.white,
        background: Color(0x33FFFFFF),
      ),
      pattern: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -16.w,
            top: -20.uh,
            child: Container(
              width: 90.w,
              height: 90.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD8B4E8).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _TicketCutoutPainter()),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support',
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD8B4E8),
              letterSpacing: 0.35,
            ),
          ),
          SizedBox(height: 2.uh),
          Text(
            'Tickets',
            style: GoogleFonts.poppins(
              fontSize: 13.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.totalOpen}',
            style: GoogleFonts.poppins(
              fontSize: 30.usp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          if (data.trendMessage.isNotEmpty) ...[
            SizedBox(height: 4.uh),
            GestureDetector(
              onTap: data.highPriorityCount > 0
                  ? () => HomeProductivityNavigation.openTickets(
                        context,
                        highPriorityOnly: true,
                      )
                  : null,
              child: Text(
                data.trendMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.usp,
                  fontWeight: FontWeight.w600,
                  color: trendColor,
                ),
              ),
            ),
          ],
        ],
      ),
        );
      },
    );
  }
}

Color _ticketsTrendColor(String trendColor) {
  switch (trendColor) {
    case 'green':
      return const Color(0xFF4ADE80);
    case 'red':
      return const Color(0xFFFF6B7A);
    default:
      return const Color(0xFFD8B4E8);
  }
}

class _ProductivityFullCardShell extends StatelessWidget {
  const _ProductivityFullCardShell({
    required this.child,
    required this.gradient,
    required this.iconBadge,
    this.pattern,
    this.onTap,
    this.height,
  });

  final Widget child;
  final Gradient gradient;
  final Widget iconBadge;
  final Widget? pattern;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.ur),
        child: Container(
          height: height ?? double.infinity,
          decoration: CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
          padding: CategoryWidgetGradientBorder.padding,
          child: Container(
            decoration: CategoryWidgetGradientBorder.inner(
              borderRadius: 22.ur,
              fillGradient: gradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  if (pattern != null)
                    IgnorePointer(child: pattern!),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 12.uh, 46.w, 12.uh),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(top: 8.uh, right: 8.w, child: iconBadge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductivityHalfCardShell extends StatelessWidget {
  const _ProductivityHalfCardShell({
    required this.child,
    required this.gradient,
    required this.iconBadge,
    this.pattern,
    this.onTap,
    this.height,
  });

  final Widget child;
  final Gradient gradient;
  final Widget iconBadge;
  final Widget? pattern;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.ur),
        child: Container(
          height: height ?? double.infinity,
          decoration: CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
          padding: CategoryWidgetGradientBorder.padding,
          child: Container(
            decoration: CategoryWidgetGradientBorder.inner(
              borderRadius: 22.ur,
              fillGradient: gradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  if (pattern != null)
                    IgnorePointer(child: pattern!),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 10.uh, 40.w, 10.uh),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(top: 8.uh, right: 8.w, child: iconBadge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  const _GlassIconBadge({
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.ur),
        color: background,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 17.usp, color: iconColor),
    );
  }
}

class _TaskStatColumn extends StatelessWidget {
  const _TaskStatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.ur),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 7.usp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.62),
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 4.uh),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24.usp,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStatDivider extends StatelessWidget {
  const _TaskStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.uh),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _CheckmarkPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final scale = 1.15 + (i * 0.12);
      final dx = size.width * (0.34 + i * 0.085);
      final dy = size.height * (0.18 + i * 0.075);
      final path = Path()
        ..moveTo(dx, dy + (10 * scale))
        ..lineTo(dx + (8 * scale), dy + (18 * scale))
        ..lineTo(dx + (24 * scale), dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NotebookLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A2F1F).withValues(alpha: 0.2)
      ..strokeWidth = 1;

    const lineCount = 7;
    final gap = size.height / (lineCount + 1);
    for (var i = 1; i <= lineCount; i++) {
      final y = gap * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketCutoutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final left = size.width * 0.52;
    final top = size.height * 0.38;
    final w = size.width * 0.42;
    final h = size.height * 0.48;
    path.moveTo(left, top);
    path.lineTo(left + w, top);
    path.lineTo(left + w, top + h);
    path.lineTo(left, top + h);
    path.close();

    canvas.drawPath(path, paint);

    final notch = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(left, top + h * 0.5), 8, notch);
    canvas.drawCircle(Offset(left + w, top + h * 0.5), 8, notch);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
