import 'dart:async';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/services/badge_refresh_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/prayer_audio_service.dart';
import 'package:el_race/firebase_service.dart';
import 'package:flutter/widgets.dart';

/// Single owner of all app-resume work.
///
/// Before this coordinator, five independent `WidgetsBindingObserver`s
/// (MyApp, HomeScreen, HomeGlassAppBar, HeaderWidget, ParayerWidget,
/// ProjectsGreetingHeader) all reacted to the same OS resume event at once —
/// stacking a GPS fetch, an attendance sync, duplicate badge API calls, a
/// blocking location dialog, and prayer-time recomputation in the same
/// event-loop turn. On mid-range devices that fan-out is a visible hang.
///
/// Now `main.dart`'s observer is the only one that reacts to
/// `AppLifecycleState.resumed` for app-wide work, and it delegates here.
/// Work is tiered so the UI is interactive immediately:
///
/// - T0 (caller, before this class): immersive mode, portrait lock —
///   synchronous, cheap, stays in `main.dart`.
/// - T1 (after first frame): prayer foreground handover (cancels OS azan
///   schedules so azan doesn't double-fire) and one shared badge refresh.
/// - T2 (after [_tier2Delay], with a cooldown): attendance status sync and
///   any registered tier-2 listener (e.g. prayer-times recompute). Never
///   awaited by the UI.
///
/// Deliberately NOT here:
/// - `refreshRoles` / session refresh — roles come from the login payload
///   only and refresh on re-login, per product decision (2026-07-20).
/// - GPS fetch and the location-services dialog — location is validated on
///   demand when the user opens check-in, not on every resume.
/// - Chat presence — `ChatLifecycleObserver` stays independent because it
///   also handles paused/hidden (going offline), and its resumed work is a
///   single cheap presence write.
class ResumeCoordinator {
  ResumeCoordinator._();

  static final ResumeCoordinator instance = ResumeCoordinator._();

  /// Delay before background (T2) work so it never competes with the
  /// first frames after resume.
  static const Duration _tier2Delay = Duration(milliseconds: 1500);

  /// Rapid app-switching (away and back within seconds) should not stack
  /// repeated attendance syncs; badge/prayer T1 work is cheap and still
  /// runs every resume.
  static const Duration _tier2Cooldown = Duration(seconds: 15);

  final Map<Object, VoidCallback> _tier2Listeners = {};
  bool _inFlight = false;
  DateTime? _lastTier2Run;

  /// Register deferred resume work (e.g. prayer-times recompute). Use the
  /// widget's `State` as [key] and call [removeTier2Listener] in `dispose()`.
  void addTier2Listener(Object key, VoidCallback callback) {
    _tier2Listeners[key] = callback;
  }

  void removeTier2Listener(Object key) {
    _tier2Listeners.remove(key);
  }

  /// Entry point — called from `main.dart`'s lifecycle observer on
  /// `AppLifecycleState.resumed`. Returns immediately; all work is deferred.
  void onResumed() {
    // A splash restart tears down the route stack and re-primes everything
    // on the way back in — resume work would race the new splash for CPU.
    if (isRestartingFromSplashTimeout.value) {
      debugPrint('⏱️ [resume] skipped — splash restart in flight');
      return;
    }
    if (_inFlight) {
      debugPrint('⏱️ [resume] skipped — previous resume still in flight');
      return;
    }
    _inFlight = true;

    // T1 — after the first frame so the UI paints before any service work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Foreground owns azan again — cancel OS schedules; timer plays once.
      unawaited(PrayerAudioService().enterForegroundMode());
      if (SharedPref.isUserAuthenticated()) {
        unawaited(BadgeRefreshService.refreshOnResume());
        // Keep Odoo expo_token fresh after long sessions / token rotation.
        unawaited(FirebaseService.syncFcmTokenToOdoo());
      }
    });

    // T2 — background work, never awaited by the UI.
    unawaited(_runTier2AfterDelay());
  }

  Future<void> _runTier2AfterDelay() async {
    try {
      await Future<void>.delayed(_tier2Delay);
      if (isRestartingFromSplashTimeout.value) return;

      final last = _lastTier2Run;
      if (last != null &&
          DateTime.now().difference(last) < _tier2Cooldown) {
        debugPrint('⏱️ [resume] tier-2 skipped — within cooldown');
        return;
      }
      _lastTier2Run = DateTime.now();

      for (final callback in List.of(_tier2Listeners.values)) {
        try {
          callback();
        } catch (e) {
          debugPrint('⏱️ [resume] tier-2 listener failed: $e');
        }
      }

      if (SharedPref.isUserAuthenticated()) {
        debugPrint('⏱️ [resume] attendance sync start');
        await AttendanceStatusSyncService.refreshFromServer(
          reason: 'app_resumed',
        ).timeout(const Duration(seconds: 10), onTimeout: () => null);
        debugPrint('⏱️ [resume] attendance sync complete');
      }
    } finally {
      _inFlight = false;
    }
  }
}
