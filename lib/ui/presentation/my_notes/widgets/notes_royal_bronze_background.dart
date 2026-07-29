import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';

/// Pure black canvas with a very slow, subtle Royal Bronze gradient wash.
///
/// Shades: [#2C3E50] ↔ [#B08D57]. Animation is low-opacity so the screen
/// stays mostly black while the bronze/charcoal drift gently.
class NotesRoyalBronzeBackground extends StatefulWidget {
  const NotesRoyalBronzeBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NotesRoyalBronzeBackground> createState() =>
      _NotesRoyalBronzeBackgroundState();
}

class _NotesRoyalBronzeBackgroundState extends State<NotesRoyalBronzeBackground>
    with SingleTickerProviderStateMixin {
  /// One full drift cycle (~22s each way) — intentionally slow / minor.
  static const _duration = Duration(seconds: 22);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NotesTheme.pureBlack,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);

          final top = Color.lerp(
            NotesTheme.charcoal,
            NotesTheme.bronze,
            t,
          )!;
          final bottom = Color.lerp(
            NotesTheme.bronze,
            NotesTheme.charcoal,
            t,
          )!;

          final begin = Alignment.lerp(
            const Alignment(-0.9, -1.0),
            const Alignment(0.85, -0.7),
            t,
          )!;
          final end = Alignment.lerp(
            const Alignment(0.9, 1.0),
            const Alignment(-0.8, 0.95),
            t,
          )!;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: [
                  top.withValues(alpha: 0.42),
                  NotesTheme.pureBlack.withValues(alpha: 0.92),
                  bottom.withValues(alpha: 0.34),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
