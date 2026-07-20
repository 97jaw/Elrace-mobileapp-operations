import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide orientation policy.
///
/// - Phone: portrait only (set at startup).
/// - Tablet Home: landscape only.
/// - Tablet sub-screens: portrait + landscape allowed.
abstract final class AppOrientations {
  static const tabletHome = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const tabletFlexible = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const phone = [
    DeviceOrientation.portraitUp,
  ];

  /// Global [RouteObserver] so Home can re-lock landscape when it becomes
  /// visible again after a sub-screen pops.
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  static Future<void> lockTabletHomeLandscape() async {
    if (!ResponsiveBreakpoints.isTabletScreen) return;
    await SystemChrome.setPreferredOrientations(tabletHome);
  }

  static Future<void> allowTabletRotation() async {
    if (!ResponsiveBreakpoints.isTabletScreen) return;
    await SystemChrome.setPreferredOrientations(tabletFlexible);
  }
}
