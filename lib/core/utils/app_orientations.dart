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

  /// Force portrait on any device (phones are already portrait-only, so this is
  /// a no-op there). Used by the face-capture screens whose detection/preview
  /// pipeline assumes a portrait frame; without it, landscape-native tablets
  /// and iPads feed sideways frames and stretch the preview.
  static Future<void> lockPortrait() async {
    await SystemChrome.setPreferredOrientations(phone);
  }
}

/// Keeps a full-screen route pinned to portrait for its whole lifetime, even on
/// tablets/iPads, and beats the tablet navigation observer that otherwise
/// re-enables rotation on push.
///
/// The global [AppOrientations.routeObserver] notifies the *previous* route's
/// `didPushNext` (which calls [AppOrientations.allowTabletRotation]) before the
/// *new* route's `didPush`, so re-locking here always wins the race. On the way
/// out we restore rotation; Home re-locks its own landscape via `didPopNext`.
mixin CapturePortraitLock<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppOrientations.lockPortrait();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppOrientations.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppOrientations.routeObserver.unsubscribe(this);
    AppOrientations.allowTabletRotation();
    super.dispose();
  }

  @override
  void didPush() => AppOrientations.lockPortrait();

  @override
  void didPopNext() => AppOrientations.lockPortrait();

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
