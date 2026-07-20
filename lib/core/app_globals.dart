import 'dart:async';

import 'package:flutter/material.dart';

/// Signals that critical app initialization is done.
final Completer<void> appInitCompleter = Completer<void>();

/// Global navigator key used across the app.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// True while `main.dart`'s 10-minute-inactivity resume handler is tearing
/// down the route stack and mounting a fresh SplashScreen. Other
/// WidgetsBindingObserver resume handlers (e.g. HomeScreen's) should check
/// this and skip their own resume work — there's no point kicking off a
/// location dialog, GPS fetch, attendance sync, or role refresh on a screen
/// that's about to be replaced by splash anyway (splash's own navigation
/// back into Home re-primes that data). Per
/// RESUME_LIFECYCLE_HANG_INVESTIGATION.md Phase 8.1.
final ValueNotifier<bool> isRestartingFromSplashTimeout = ValueNotifier(false);
