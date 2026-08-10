import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:flutter/material.dart';

/// Canvas with a slow Royal Bronze gradient wash (dark or light).
///
/// Listens to [NotesThemeController] so the whole notes subtree rebuilds
/// when Dark/Light toggles.
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
  static const _duration = Duration(seconds: 22);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    NotesThemeController.instance.ensureLoaded();
    NotesThemeController.instance.addListener(_onThemeChanged);
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat(reverse: true);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotesThemeController.instance.removeListener(_onThemeChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NotesTheme.canvas,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
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
                  top.withValues(alpha: NotesTheme.washAlphaTop),
                  NotesTheme.canvas.withValues(alpha: NotesTheme.washAlphaMid),
                  bottom.withValues(alpha: NotesTheme.washAlphaBottom),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
            // Force notes subtree rebuild when brightness flips.
            child: KeyedSubtree(
              key: ValueKey(NotesThemeController.instance.brightness),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
