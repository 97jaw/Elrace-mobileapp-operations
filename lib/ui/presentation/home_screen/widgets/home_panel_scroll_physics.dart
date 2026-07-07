import 'package:flutter/material.dart';

/// Absorbs downward overscroll at scroll offset 0 so the panel can collapse
/// without fighting [BouncingScrollPhysics].
class HomePanelScrollPhysics extends ScrollPhysics {
  const HomePanelScrollPhysics({
    required this.onCollapseDrag,
    super.parent,
  });

  final ValueChanged<double> onCollapseDrag;

  @override
  HomePanelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HomePanelScrollPhysics(
      onCollapseDrag: onCollapseDrag,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      final overflow = position.pixels - value;
      if (overflow > 0) {
        onCollapseDrag(overflow);
        return value - position.pixels;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
