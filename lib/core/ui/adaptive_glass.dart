import 'dart:ui';

import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:flutter/material.dart';

/// Wraps [child] with [BackdropFilter] on high-end devices, or a frosted fill on low-end.
class AdaptiveGlassLayer extends StatelessWidget {
  const AdaptiveGlassLayer({
    super.key,
    required this.child,
    this.borderRadius,
    this.sigma = 12,
    this.fallbackColor,
    this.fallbackBorder,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double sigma;
  final Color? fallbackColor;
  final BoxBorder? fallbackBorder;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    if (!DeviceUiCapability.useBackdropBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor ?? Colors.white.withValues(alpha: 0.84),
            borderRadius: radius,
            border: fallbackBorder,
          ),
          child: child,
        ),
      );
    }

    final effectiveSigma = DeviceUiCapability.adaptiveBlurSigma(sigma);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveSigma,
          sigmaY: effectiveSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor ?? Colors.white.withValues(alpha: 0.08),
            borderRadius: radius,
            border: fallbackBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
