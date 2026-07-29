import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';

/// Shared glassy card shell for My Notes capture tiles.
class NotesGlassCard extends StatelessWidget {
  const NotesGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? NotesTheme.cardBorderRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: NotesTheme.bronze.withValues(alpha: 0.12),
        highlightColor: NotesTheme.bronze.withValues(alpha: 0.06),
        child: AdaptiveGlassLayer(
          borderRadius: radius,
          sigma: 14,
          fallbackColor: NotesTheme.charcoal.withValues(alpha: 0.55),
          fallbackBorder: NotesTheme.glassBoxBorder,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: NotesTheme.glassBoxBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NotesTheme.glassFillStrong,
                  NotesTheme.bronze.withValues(alpha: 0.06),
                  NotesTheme.glassFill,
                ],
              ),
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
