import 'dart:async';

import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/core/app_globals.dart' show appInitCompleter;
import 'package:el_race/core/session/force_logout_guard.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/widgets/update_dialog.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/security/device_security_service.dart';
import 'package:provider/provider.dart';
import 'package:el_race/ui/presentation/qr_survey/providers/qr_survey_data_provider.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Keep in sync with version in pubspec.yaml.
  static const String _currentAppVersion = '1.0.10';

  bool _isSecurityCheckComplete = false;
  bool _isDeviceSecure = true;
  bool _didScheduleNavigation = false;
  late VideoPlayerController _videoController;
  bool _isVideoReady = false;
  final Completer<void> _videoCompletedCompleter = Completer<void>();
  // Phase 2: replaces the _waitForSecurityCheck() polling loop so the
  // security gate can be awaited alongside init/video instead of after them.
  final Completer<void> _securityCheckCompleter = Completer<void>();

  // Phase 2: kicked off in initState alongside video/security since it has
  // no dependency on either — only awaited (with its existing 10s timeout)
  // right before _doNavigate() in _checkForUpdateThenNavigate().
  late final Future<UpdateCheckResult> _updateCheckFuture;

  // Phase 0 instrumentation: measures elapsed time of each splash gate so we
  // have real numbers instead of guesses before attempting the structural
  // fix in Phase 2. No behavior change — logging only.
  final Stopwatch _splashStopwatch = Stopwatch()..start();

  void _logGateTiming(String label) {
    debugPrint(
        '⏱️ [splash] $label at ${_splashStopwatch.elapsedMilliseconds}ms');
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen.initState(): first screen mounted');
    _logGateTiming('initState');

    // Instrumentation only: log when appInitCompleter resolves, independent
    // of the Future.wait gate in _waitForInitAndNavigate (Completers support
    // multiple listeners, so this does not change existing behavior).
    appInitCompleter.future
        .then((_) => _logGateTiming('appInitCompleter-resolved'));

    // Phase 2: start the update check now, in parallel with init/video/
    // security, since it has no dependency on any of them. Previously this
    // only started after security finished, adding its full latency to the
    // serial chain. Attach a no-op error listener immediately so a failure
    // here doesn't surface as an unhandled zone exception before it's
    // actually awaited (and handled) in _checkForUpdateThenNavigate.
    _updateCheckFuture = UpdateService.instance
        .checkForUpdate(_currentAppVersion)
        .timeout(const Duration(seconds: 10));
    _logGateTiming('update-check-start');
    _updateCheckFuture.catchError((_) => const UpdateCheckResult.noUpdate());

    // Initialize video player (uses hardware decoder, not main thread)
    _videoController = VideoPlayerController.asset('assets/mp4/splash.mp4')
      ..initialize().then((_) {
        _logGateTiming('video-ready');
        if (mounted) {
          setState(() => _isVideoReady = true);
          _videoController.addListener(_onVideoProgress);
          _videoController.play();
        }
      }).catchError((e) {
        print('⚠️ Video init error: $e');
        _completeVideoIfNeeded();
      });

    // Defer security check & QR clear to after the first frame so
    // the splash background paints immediately without any blocking work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSecurityCheck();
      final provider =
          Provider.of<QrSurveyDataProvider>(context, listen: false);
      provider.clearData();
      print('🧹 SplashScreen - Cleared QR data on app start');
    });
  }

  /// Perform security check before allowing app usage
  Future<void> _performSecurityCheck() async {
    _logGateTiming('security-check-start');
    try {
      print('🔒 Starting security check...');
      final result = await DeviceSecurityService.instance
          .performSecurityCheck()
          .timeout(const Duration(seconds: kDebugMode ? 2 : 6));

      if (mounted) {
        setState(() {
          _isDeviceSecure = result.isSecure;
          _isSecurityCheckComplete = true;
        });

        if (!result.isSecure) {
          print('❌ Device security check failed!');
          // Show security warning dialog
          DeviceSecurityService.showSecurityBlockDialog(context, result);
        } else {
          print('✅ Device security check passed!');
        }
      }
      _logGateTiming('security-check-complete (isSecure=${result.isSecure})');
    } catch (e) {
      print('⚠️ Error during security check: $e');
      // On error, allow app to continue (fail-open for better UX)
      if (mounted) {
        setState(() {
          _isSecurityCheckComplete = true;
          _isDeviceSecure = true;
        });
      }
      _logGateTiming('security-check-complete (error, fail-open)');
    } finally {
      // Signal _waitForInitAndNavigate's Future.wait — replaces the old
      // _waitForSecurityCheck() polling loop (500ms x 10).
      if (!_securityCheckCompleter.isCompleted) {
        _securityCheckCompleter.complete();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only schedule navigation once (didChangeDependencies can be called many times)
    if (_didScheduleNavigation) return;
    _didScheduleNavigation = true;

    _waitForInitAndNavigate();
  }

  /// Wait for init + security in parallel. Splash video is decorative only —
  /// do NOT gate navigation on it (video is ~5s and completion often misses,
  /// Jul 20 "Let splash video finish before navigation").
  Future<void> _waitForInitAndNavigate() async {
    debugPrint('🚀 SplashScreen: waiting for bounded startup checks');
    _logGateTiming('waitForInitAndNavigate-start');
    await Future.wait<void>([
      appInitCompleter.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⚠️ Heavy init timeout in splash – continuing anyway');
        },
      ),
      _securityCheckCompleter.future.timeout(
        const Duration(seconds: kDebugMode ? 2 : 6),
        onTimeout: () {
          print('⚠️ Security check timeout in splash – continuing anyway');
        },
      ),
    ]);
    await _videoCompletedCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('Video completion timeout in splash - continuing anyway');
      },
    );
    _logGateTiming('waitForInitAndNavigate-gate-resolved');

    if (!mounted) return;

    // Check security — unchanged policy: only blocks if the check actually
    // completed and found the device insecure. A timed-out/incomplete check
    // (_isSecurityCheckComplete still false) fails open, same as before.
    if (!_isDeviceSecure && _isSecurityCheckComplete) {
      print('🚫 Navigation blocked - device not secure');
      return;
    }

    _navigateToNextScreen();
  }

  void _onVideoProgress() {
    if (!_videoController.value.isInitialized) return;

    final duration = _videoController.value.duration;
    final position = _videoController.value.position;

    if (duration == Duration.zero) return;

    if (position >= duration - const Duration(milliseconds: 100)) {
      _completeVideoIfNeeded();
    }
  }

  void _completeVideoIfNeeded() {
    if (!_videoCompletedCompleter.isCompleted) {
      _videoCompletedCompleter.complete();
      _logGateTiming('video-complete');
    }
  }

  /// Navigate to the appropriate screen after security check.
  /// Runs the update check first, then proceeds with routing.
  void _navigateToNextScreen() {
    if (!mounted) return;
    debugPrint('🚀 SplashScreen: initialization finished; checking route');
    _checkForUpdateThenNavigate();
  }

  Future<void> _checkForUpdateThenNavigate() async {
    if (!mounted) return;

    try {
      // Started back in initState, in parallel with init/video/security —
      // this just waits for whatever's left of its own 10s timeout.
      final updateResult = await _updateCheckFuture;
      _logGateTiming('update-check-complete');

      if (!mounted) return;

      final blocked = await UpdateDialog.showIfNeeded(
        context,
        updateResult,
        isRtl: Directionality.of(context) == TextDirection.rtl,
      );

      // Force-update: block navigation until user updates the app
      if (blocked) return;
    } catch (e) {
      print('⚠️ Update check error (ignored): $e');
      _logGateTiming('update-check-complete (error, ignored)');
    }

    if (!mounted) return;
    _doNavigate();
  }

  Future<void> _doNavigate() async {
    if (!mounted) return;
    // Proxy for "first frame of HomeScreen/SignInScreen": this is the last
    // point splash_screen.dart controls before handing off navigation, since
    // instrumenting the destination screens is out of scope for this file.
    _logGateTiming('navigate-handoff');

    try {
      // Check authentication first
      final isAuthenticated = SharedPref.isUserAuthenticated();
      debugPrint(
        '🚀 SplashScreen: navigating to '
        '${isAuthenticated ? 'home' : 'sign-in'}',
      );

      // Fetch home screen data (with error handling inside the function)
      // This won't throw - errors are handled internally
      Util.fetchHomeScreenData(context);

      if (isAuthenticated) {
        // Admin force-logout: block home until user re-logins.
        final forced = await ForceLogoutGuard.instance.isForceLoggedOut();
        if (!mounted) return;
        if (forced) {
          await ForceLogoutGuard.instance.presentForcedLogoutFlow(
            context: context,
          );
          return;
        }

        // Check if face registration is in progress or pending
        final isRegistrationInProgress =
            SharedPref().getPreferenceBoolean('isFaceRegistrationInProgress');
        final isPendingFaceVerification =
            SharedPref().getPreferenceBoolean('pendingFaceVerification');
        final isFaceRegistered =
            SharedPref().getPreferenceBoolean('isFaceRegistered');

        // If registration was in progress, user must complete it
        if (isRegistrationInProgress ||
            (isPendingFaceVerification && !isFaceRegistered)) {
          // In Test Mode, skip face registration
          if (AppConfigService.instance.isTestMode) {
            SharedPref()
                .setPreferencesBoolean('pendingFaceVerification', false);
            SharedPref()
                .setPreferencesBoolean('isFaceRegistrationInProgress', false);
            Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
            FirebaseService.markHomeReady();
            return;
          }

          // User needs to register face - go to home, it will be triggered from there
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        } else {
          // User already registered or no pending verification
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        }
      } else {
        Util.pushPageAndRemoveRoutes(const SignInScreen(), context);
      }
    } catch (e) {
      print('❌ Error navigating from splash: $e');
      // Fallback based on authentication status, not to login screen blindly
      if (mounted) {
        if (SharedPref.isUserAuthenticated()) {
          Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
          FirebaseService.markHomeReady();
        } else {
          Util.pushPageAndRemoveRoutes(const SignInScreen(), context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _isVideoReady
            ? SizedBox.expand(
                key: const ValueKey('splash-video'),
                child: ColoredBox(
                  color: Colors.black,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
              )
            : const _SplashLoadingPlaceholder(key: ValueKey('splash-loading')),
      ),
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoProgress);
    _videoController.dispose();
    super.dispose();
  }
}

class _SplashLoadingPlaceholder extends StatelessWidget {
  const _SplashLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3F4F6),
            Color(0xFFE5E7EB),
          ],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF9CA3AF),
            backgroundColor: Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }
}
