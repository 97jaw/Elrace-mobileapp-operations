import 'package:flutter/material.dart';

/// Fade + slight slide when list data appears (staggered by [index]).
class TmAnimatedListItem extends StatefulWidget {
  const TmAnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggerMs = 280,
    this.perItemDelayMs = 45,
  });

  final int index;
  final Widget child;
  final int maxStaggerMs;
  final int perItemDelayMs;

  @override
  State<TmAnimatedListItem> createState() => _TmAnimatedListItemState();
}

class _TmAnimatedListItemState extends State<TmAnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delayMs = (widget.index * widget.perItemDelayMs)
        .clamp(0, widget.maxStaggerMs);
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
