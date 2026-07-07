import 'package:flutter/material.dart';

/// Brief scale feedback when glass header icons are pressed.
class GlassTapIcon extends StatefulWidget {
  const GlassTapIcon({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<GlassTapIcon> createState() => _GlassTapIconState();
}

class _GlassTapIconState extends State<GlassTapIcon> {
  double _scale = 1.0;

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    setState(() => _scale = 0.88);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _scale = 1.0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
