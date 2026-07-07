import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:flutter/material.dart';

/// Light body gradient per HR submodule (used inside each service, not the hub).
enum HrServiceScreenKind {
  requests,
  recruitment,
  performance,
  payslip,
  attendance,
}

/// Top color should match [scaffoldBackground] for seamless AppBar / status area.
abstract final class HrServiceScreenBackdrop {
  static Color scaffoldBackground(HrServiceScreenKind kind) {
    return switch (kind) {
      HrServiceScreenKind.requests => HrModuleColors.requestsGradientTop,
      HrServiceScreenKind.recruitment => HrModuleColors.recruitmentGradientTop,
      HrServiceScreenKind.performance => HrModuleColors.performanceGradientTop,
      HrServiceScreenKind.payslip => HrModuleColors.payslipGradientTop,
      HrServiceScreenKind.attendance => const Color(0xFFE3F2FD),
    };
  }

  static LinearGradient bodyGradient(HrServiceScreenKind kind) {
    return switch (kind) {
      HrServiceScreenKind.requests => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HrModuleColors.requestsGradientTop,
            HrModuleColors.requestsGradientMid,
            HrModuleColors.requestsGradientBottom,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      HrServiceScreenKind.recruitment => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HrModuleColors.recruitmentGradientTop,
            HrModuleColors.recruitmentGradientMid,
            HrModuleColors.recruitmentGradientBottom,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      HrServiceScreenKind.performance => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HrModuleColors.performanceGradientTop,
            HrModuleColors.performanceGradientMid,
            HrModuleColors.performanceGradientBottom,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      HrServiceScreenKind.payslip => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HrModuleColors.payslipGradientTop,
            HrModuleColors.payslipGradientMid,
            HrModuleColors.payslipGradientBottom,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      HrServiceScreenKind.attendance => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3F2FD),
            Color(0xFFF0F7FF),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
    };
  }

  static Widget wrap({
    required HrServiceScreenKind kind,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: bodyGradient(kind)),
      child: child,
    );
  }
}
