import 'package:flutter/material.dart';

/// Absorbs downward overscroll at the top so the widgets panel can collapse
/// without fighting bounce rubber-banding.
///
/// Does **not** invoke [onCollapseDrag] during [applyBoundaryConditions]
/// (that can run mid-layout). Callers should drive collapse from
/// [OverscrollNotification] / [ScrollUpdateNotification] instead; this
/// physics only clamps the list so overscroll is reported cleanly.
class HomePanelScrollPhysics extends ScrollPhysics {
  const HomePanelScrollPhysics({super.parent});

  @override
  HomePanelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HomePanelScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // At top, block downward scroll into negative offset so overscroll
    // notifications fire instead of rubber-band fighting the panel drag.
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent + 0.5) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
