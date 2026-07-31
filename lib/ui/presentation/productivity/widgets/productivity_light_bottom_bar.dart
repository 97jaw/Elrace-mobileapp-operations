import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ProductivityLightNavTab { home, tasks, tickets, calendar }

/// Fixed bottom bar: Home · Tasks · + · Tickets · Calendar
class ProductivityLightBottomBar extends StatelessWidget {
  const ProductivityLightBottomBar({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onTasks,
    required this.onAdd,
    required this.onTickets,
    required this.onCalendar,
  });

  final ProductivityLightNavTab selected;
  final VoidCallback onHome;
  final VoidCallback onTasks;
  final VoidCallback onAdd;
  final VoidCallback onTickets;
  final VoidCallback onCalendar;

  static const double _waveTop = 14;
  static const double _barBody = 56;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = _waveTop + _barBody + bottomInset;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: barHeight + 8,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                painter: const _BottomBarWavePainter(waveTop: _waveTop),
                child: SizedBox(
                  height: barHeight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: _waveTop,
                      bottom: bottomInset,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavLabelButton(
                            icon: Icons.home_outlined,
                            selectedIcon: Icons.home_rounded,
                            label: 'Home',
                            selected: selected == ProductivityLightNavTab.home,
                            onTap: onHome,
                          ),
                        ),
                        Expanded(
                          child: _NavLabelButton(
                            icon: Icons.folder_outlined,
                            selectedIcon: Icons.folder_rounded,
                            label: 'Tasks',
                            selected: selected == ProductivityLightNavTab.tasks,
                            onTap: onTasks,
                          ),
                        ),
                        const SizedBox(width: 72),
                        Expanded(
                          child: _NavLabelButton(
                            icon: Icons.confirmation_number_outlined,
                            selectedIcon: Icons.confirmation_number,
                            label: 'Tickets',
                            selected:
                                selected == ProductivityLightNavTab.tickets,
                            onTap: onTickets,
                          ),
                        ),
                        Expanded(
                          child: _NavLabelButton(
                            icon: Icons.calendar_today_outlined,
                            selectedIcon: Icons.calendar_month_rounded,
                            label: 'Calendar',
                            selected:
                                selected == ProductivityLightNavTab.calendar,
                            onTap: onCalendar,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: bottomInset + (_barBody / 2) - 29,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.navAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ProductivityLightTheme.navAccent
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLabelButton extends StatelessWidget {
  const _NavLabelButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? ProductivityLightTheme.ink
        : ProductivityLightTheme.inkMuted;

    return InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? ProductivityLightTheme.navSelectedWash
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(
                      color: ProductivityLightTheme.navBarEdge
                          .withValues(alpha: 0.8),
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarWavePainter extends CustomPainter {
  const _BottomBarWavePainter({this.waveTop = 14});

  final double waveTop;

  @override
  void paint(Canvas canvas, Size size) {
    final y = waveTop;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width * 0.5 - 42, y)
      ..cubicTo(
        size.width * 0.5 - 28,
        y,
        size.width * 0.5 - 30,
        0,
        size.width * 0.5,
        0,
      )
      ..cubicTo(
        size.width * 0.5 + 30,
        0,
        size.width * 0.5 + 28,
        y,
        size.width * 0.5 + 42,
        y,
      )
      ..lineTo(size.width, y)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.1), 14, true);

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ProductivityLightTheme.navBarTop,
          ProductivityLightTheme.washCream,
          ProductivityLightTheme.navBarBottom,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final edge = Paint()
      ..color = ProductivityLightTheme.navBarEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _BottomBarWavePainter oldDelegate) =>
      oldDelegate.waveTop != waveTop;
}
