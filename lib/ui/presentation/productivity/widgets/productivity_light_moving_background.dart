import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:flutter/material.dart';

/// Slow drifting light gradient (#E9EEF8 ↔ #F3F4E8) for Task/Tickets screens.
class ProductivityLightMovingBackground extends StatefulWidget {
  const ProductivityLightMovingBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ProductivityLightMovingBackground> createState() =>
      _ProductivityLightMovingBackgroundState();
}

class _ProductivityLightMovingBackgroundState
    extends State<ProductivityLightMovingBackground>
    with SingleTickerProviderStateMixin {
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
      color: ProductivityLightTheme.washBlue,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);

          final top = Color.lerp(
            ProductivityLightTheme.washBlue,
            ProductivityLightTheme.washCream,
            t,
          )!;
          final bottom = Color.lerp(
            ProductivityLightTheme.washCream,
            ProductivityLightTheme.washBlue,
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
                  top,
                  Color.lerp(
                    ProductivityLightTheme.washBlue,
                    ProductivityLightTheme.washCream,
                    0.45,
                  )!,
                  bottom,
                ],
                stops: const [0.0, 0.5, 1.0],
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
