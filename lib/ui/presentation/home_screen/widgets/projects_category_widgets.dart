import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_projects_widgets_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_projects_navigation.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_reports_navigation.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// v7 Projects category widgets (My Projects, Site Management, My Reports).
class ProjectsCategoryMyProjectsCard extends ConsumerWidget {
  const ProjectsCategoryMyProjectsCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeMyProjectsWidgetProvider);
    final rowCount = data.topProjects.length;

    return _ProjectsFullCardShell(
      onTap: () => HomeMyProjectsNavigation.openProjectsModule(context),
      gradient: const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Color(0xFF9AA5B5),
          Color(0xFFB0BAC8),
          Color(0xFFC5CED8),
          Color(0xFFDCE2EA),
          Color(0xFFF0F3F7),
        ],
      ),
      iconBadge: const _ProjectsIconBadge(
        icon: Icons.apartment_rounded,
        gradient: [Color(0xFF2A3F6B), Color(0xFF1A2A4F)],
      ),
      pattern: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -36.w,
            top: -44.uh,
            child: _ConcentricRingsPattern(size: 210.w),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ACTIVE PROJECTS',
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A849C),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 3.uh),
          Text(
            data.titleLine,
            style: GoogleFonts.poppins(
              fontSize: 14.5.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2A4F),
              height: 1.15,
            ),
          ),
          SizedBox(height: rowCount == 0 ? 8.uh : 14.uh),
          if (rowCount == 0)
            Text(
              'No projects yet',
              style: GoogleFonts.poppins(
                fontSize: 11.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A6A82),
              ),
            )
          else ...[
            for (var i = 0; i < rowCount; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.uh),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: const Color(0xFF1A2A4F).withValues(alpha: 0.07),
                  ),
                ),
              _MyProjectsRow(
                project: data.topProjects[i],
                onTap: () => HomeMyProjectsNavigation.openProject(
                  context,
                  data.topProjects[i].id,
                ),
              ),
            ],
            if (data.moreProjectsCount > 0) ...[
              SizedBox(height: 10.uh),
              GestureDetector(
                onTap: () =>
                    HomeMyProjectsNavigation.openProjectsModule(context),
                child: Text(
                  '+ ${data.moreProjectsCount} more projects',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5.usp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3E7BFA),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class ProjectsCategorySiteManagementCard extends ConsumerWidget {
  const ProjectsCategorySiteManagementCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeSiteManagementWidgetProvider);
    final countLabel =
        data.activeSitesCount > 0 ? '${data.activeSitesCount}' : '—';
    final chips = data.locationChips;

    return _ProjectsHalfCardShell(
      height: null,
      onTap: () => Navigator.of(context).pushNamed(
        TimesheetRouteNames.siteManagementHome,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF1D9),
          Color(0xFFFFE0B0),
          Color(0xFFFFCC85),
          Color(0xFFF4A460),
        ],
      ),
      iconBadge: const _ProjectsIconBadge(
        icon: Icons.engineering_rounded,
        gradient: [Color(0xFFF59E3D), Color(0xFFE07B1A)],
      ),
      pattern: Align(
        alignment: Alignment.bottomRight,
        child: CustomPaint(
          size: Size(88.w, 72.uh),
          painter: _BlueprintGridPainter(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITES',
            style: GoogleFonts.poppins(
              fontSize: 8.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE07B1A),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 2.uh),
          Text(
            'Site Management',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.5.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A3E00),
            ),
          ),
          SizedBox(height: 6.uh),
          Text(
            countLabel,
            style: GoogleFonts.poppins(
              fontSize: 24.usp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7A3E00),
              height: 1,
            ),
          ),
          SizedBox(height: 3.uh),
          Text(
            data.trendLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 8.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF59E3D),
              height: 1.2,
            ),
          ),
          if (chips.isNotEmpty) ...[
            SizedBox(height: 6.uh),
            SizedBox(
              height: 22.uh,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: chips.length,
                separatorBuilder: (_, __) => SizedBox(width: 6.w),
                itemBuilder: (context, index) {
                  return _ProjectsSoftPill(label: chips[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProjectsCategoryMyReportsCard extends ConsumerWidget {
  const ProjectsCategoryMyReportsCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeMyReportsWidgetProvider);
    final trendColor = _reportsTrendColor(data.trendDirection);
    final valueStyle = GoogleFonts.poppins(
      fontSize: data.value == '—' ? 24.usp : 28.usp,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1,
    );

    return _ProjectsHalfCardShell(
      height: null,
      onTap: () => HomeMyReportsNavigation.open(
        context,
        metricType: data.metricType,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A1F2E),
          Color(0xFF2A2D40),
          Color(0xFF1A1F2E),
        ],
      ),
      iconBadge: const _ProjectsIconBadge(
        icon: Icons.show_chart_rounded,
        gradient: [Color(0xFFE63946), Color(0xFFB81D32)],
      ),
      pattern: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ReportsChartPatternPainter()),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1F2E).withValues(alpha: 0.92),
                    const Color(0xFF1A1F2E).withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE',
            style: GoogleFonts.poppins(
              fontSize: 8.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB8BEC8),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 2.uh),
          Text(
            'My Reports',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.5.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.uh),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(data.value, style: valueStyle),
          ),
          SizedBox(height: 4.uh),
          Text(
            data.trendLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 8.5.usp,
              fontWeight: FontWeight.w600,
              color: trendColor,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.uh),
          Text(
            'Updated ${data.updatedAt} · Live',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

Color _reportsTrendColor(String direction) {
  switch (direction) {
    case 'up':
      return const Color(0xFFFF6D8B);
    case 'down':
      return const Color(0xFFE05A4F);
    case 'new':
      return const Color(0xFF7FC0FF);
    default:
      return const Color(0xFFB8BEC8);
  }
}

/// Fixed traffic-light palette — mostly green/red with a narrow yellow band.
abstract final class _MyProjectsTrafficPalette {
  static const green = Color(0xFF22C55E);
  static const yellow = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [green, green, yellow, red, red],
    stops: [0.0, 0.38, 0.5, 0.62, 1.0],
  );

  static const dotGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, green, yellow, red],
    stops: [0.0, 0.45, 0.55, 1.0],
  );
}

class _MyProjectsRow extends StatelessWidget {
  const _MyProjectsRow({
    required this.project,
    required this.onTap,
  });

  final MyProjectsTopProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = project.progressPct.round();
    final pctLabel = '$pct%';
    final name = project.name.length > 22
        ? '${project.name.substring(0, 22)}…'
        : project.name;
    final barValue = (project.progressPct / 100).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.ur),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 1.uh),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _ProgressStatusDot(),
              SizedBox(width: 8.w),
              Expanded(
                flex: 5,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5.usp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A2A4F),
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 4,
                child: _ProjectProgressBar(value: barValue),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                width: 34.w,
                child: Text(
                  pctLabel,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: 11.usp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A2A4F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStatusDot extends StatelessWidget {
  const _ProgressStatusDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14.w,
      height: 14.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _MyProjectsTrafficPalette.dotGradient,
              boxShadow: [
                BoxShadow(
                  color: _MyProjectsTrafficPalette.green.withValues(alpha: 0.16),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
          Container(
            width: 5.w,
            height: 5.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _MyProjectsTrafficPalette.dotGradient,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectProgressBar extends StatelessWidget {
  const _ProjectProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 5.5.uh,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF1A2A4F).withValues(alpha: 0.08),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: _MyProjectsTrafficPalette.gradient,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: constraints.maxWidth * (1 - value),
                        child: const ColoredBox(color: Color(0xFFE8ECF2)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsSoftPill extends StatelessWidget {
  const _ProjectsSoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.uh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 8.usp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF7A3E00),
        ),
      ),
    );
  }
}

class _ProjectsIconBadge extends StatelessWidget {
  const _ProjectsIconBadge({required this.icon, required this.gradient});

  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11.ur),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 18.usp, color: Colors.white),
    );
  }
}

class _ProjectsHalfCardShell extends StatelessWidget {
  const _ProjectsHalfCardShell({
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
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (pattern != null)
                    Positioned.fill(
                      child: IgnorePointer(child: pattern!),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 10.uh, 46.w, 12.uh),
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

class _ProjectsFullCardShell extends StatelessWidget {
  const _ProjectsFullCardShell({
    required this.child,
    required this.gradient,
    required this.iconBadge,
    this.pattern,
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final Widget iconBadge;
  final Widget? pattern;
  final VoidCallback? onTap;

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
          constraints: BoxConstraints(minHeight: 108.uh),
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
                children: [
                  if (pattern != null)
                    Positioned.fill(
                      child: IgnorePointer(child: pattern!),
                    ),
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

class _ConcentricRingsPattern extends StatelessWidget {
  const _ConcentricRingsPattern({this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final canvas = size ?? 150.w;
    return SizedBox(
      width: canvas,
      height: canvas,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final scale in [1.0, 0.68, 0.38])
            Container(
              width: canvas * scale,
              height: canvas * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.52),
                  width: 2.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const step = 14.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final house = Path()
      ..moveTo(size.width * 0.72, size.height * 0.72)
      ..lineTo(size.width * 0.82, size.height * 0.52)
      ..lineTo(size.width * 0.92, size.height * 0.72)
      ..close();
    canvas.drawPath(house, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.78,
        size.height * 0.72,
        size.width * 0.1,
        size.height * 0.16,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportsChartPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE63946).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.18, size.height * 0.55)
      ..lineTo(size.width * 0.36, size.height * 0.62)
      ..lineTo(size.width * 0.54, size.height * 0.35)
      ..lineTo(size.width * 0.72, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.22);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
