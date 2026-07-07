import 'package:flutter/material.dart';

/// Staggered fade + slide-in for DMS list rows after tab switch / reload.
class ProjectDocumentsAnimatedListItem extends StatelessWidget {
  const ProjectDocumentsAnimatedListItem({
    super.key,
    required this.index,
    required this.animationKey,
    required this.child,
  });

  final int index;
  final int animationKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final staggerMs = (index.clamp(0, 14)) * 40;

    return TweenAnimationBuilder<double>(
      key: ValueKey('dms-item-$animationKey-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + staggerMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Tab body fade when switching bottom-bar views.
class ProjectDocumentsTabTransition extends StatelessWidget {
  const ProjectDocumentsTabTransition({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final int transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(transitionKey),
        child: child,
      ),
    );
  }
}

/// Center loading indicator used during tab switches.
class ProjectDocumentsTabLoading extends StatelessWidget {
  const ProjectDocumentsTabLoading({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          color: color ?? Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
