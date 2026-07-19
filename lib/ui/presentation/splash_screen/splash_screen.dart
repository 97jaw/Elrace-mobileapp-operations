import 'dart:async';

import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/core/app_globals.dart' show appInitCompleter;
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/widgets/update_dialog.dart';
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
  bool _isSecurityCheckComplete = false;
  bool _isDeviceSecure = true;
  bool _didScheduleNavigation = false;
  late VideoPlayerController _videoController;
  bool _isVideoReady = false;
  final Completer<void> _videoCompletedCompleter = Completer<void>();

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
    appInitCompleter.future.then((_) => _logGateTiming('appInitCompleter-resolved'));

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
          .timeout(const Duration(seconds: 6));

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

  /// Wait for both: 1) minimum 3-second splash, 2) heavy init complete,
  /// 3) security check, then navigate.
  Future<void> _waitForInitAndNavigate() async {
    debugPrint('🚀 SplashScreen: waiting for bounded startup checks');
    _logGateTiming('waitForInitAndNavigate-start');
    // Wait for BOTH heavy init and intro video completion.
    await Future.wait<void>([
      appInitCompleter.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⚠️ Heavy init timeout in splash – continuing anyway');
        },
      ),
      _videoCompletedCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⚠️ Video completion timeout in splash – continuing anyway');
        },
      ),
    ]);
    _logGateTiming('waitForInitAndNavigate-gate-resolved');

    if (!mounted) return;

    // Check security
    if (!_isDeviceSecure && _isSecurityCheckComplete) {
      print('🚫 Navigation blocked - device not secure');
      return;
    }

    // Wait for security check if not complete yet
    if (!_isSecurityCheckComplete) {
      print('⏳ Waiting for security check...');
      await _waitForSecurityCheck();
    }

    if (!mounted) return;
    if (!_isDeviceSecure) return;

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

  /// Wait for security check to complete (up to 5 seconds)
  Future<void> _waitForSecurityCheck() async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isSecurityCheckComplete) return;
    }
    // Timeout - allow to proceed
    print('⚠️ Security check timeout – proceeding');
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
    _logGateTiming('update-check-start');

    try {
      // Keep in sync with version in pubspec.yaml
      const String currentVersion = '1.0.10';

      final updateResult = await UpdateService.instance
          .checkForUpdate(currentVersion)
          .timeout(const Duration(seconds: 10));
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

  void _doNavigate() {
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
