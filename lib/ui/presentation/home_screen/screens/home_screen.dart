import 'dart:async';

import 'package:el_race/core/biometric/device_auth_service.dart';
import 'package:el_race/core/biometric/unified_biometric_helper.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/location_bloc/location_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/biometric_sign_in_gate_screen.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_home_content_widget.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:el_race/core/services/app_config_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}

class HomeScreenPage extends StatefulWidget {
  const HomeScreenPage({
    super.key,
  });

  static bool _didAuthenticateThisSession = false;
  static bool _isAuthenticating = false;

  /// True while Face ID / fingerprint gate must block the UI.
  static bool _sessionUiLocked = false;

  /// Whether the shell should absorb taps (used by [MainScreen] too).
  static bool get isSessionUiLocked => _sessionUiLocked;

  /// Reset the biometric gate so the next login triggers it again.
  static void resetAuthSession() {
    _didAuthenticateThisSession = false;
    _isAuthenticating = false;
    _sessionUiLocked = false;
  }

  @override
  State<HomeScreenPage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenPage> {
  // auth flags are stored on the widget class so they can be reset from outside

  // bool isMuted = false; // default value
  bool isCheckedIn = false;

  /// Blocks home UI until biometrics succeed (covers cancel → gate screen).
  bool _isBiometricLocked = false;

  bool _showBiometricGateScreen = false;

  final _locationBloc = LocationBloc();

  // _loadMuteStatus() {
  //   setState(() {
  //     isMuted = SharedPref().getPreferenceBoolean('mute_notifications');
  //   });
  // }

  void _setBiometricLocked(bool locked) {
    HomeScreenPage._sessionUiLocked = locked;
    if (!mounted) return;
    if (_isBiometricLocked == locked) return;
    setState(() => _isBiometricLocked = locked);
  }

  @override
  void initState() {
    super.initState();
    Get.put(TimerController()); // only once!
    // _loadMuteStatus();
    // Future.delayed(const Duration(seconds: 5), () {
    //   showBabyGirlPopup(context);
    // });
    // Location-services enforcement moved to the check-in panel
    // (LocationServiceBanner) — validated on demand where it matters,
    // instead of a blocking dialog on every Home mount/resume.
    // One GPS prime per Home mount (post-login); resumes no longer re-fetch.
    _locationBloc.add(GetCurrentLocationET());

    // After login: show the dim lock overlay, then start biometrics
    // automatically after Home has painted.
    if (!AppConfigService.instance.shouldSkipFaceId &&
        !HomeScreenPage._didAuthenticateThisSession &&
        !HomeScreenPage._isAuthenticating) {
      // Lock on the first frame — before the system prompt appears — so taps
      // cannot slip through in the delay / cancel / retry gaps.
      _isBiometricLocked = true;
      HomeScreenPage._sessionUiLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_authenticateAfterLogin());
      });
    }
    // List of pages or widgets that you want to display for each navigation ite
  }

  /// Authenticate user right after login using device biometrics only.
  /// PIN, passcode, password, and pattern fallback are not allowed.
  /// On cancel/miss, keep the dim lock overlay visible.
  Future<void> _authenticateAfterLogin({bool fromButton = false}) async {
    if (HomeScreenPage._didAuthenticateThisSession) return;
    if (HomeScreenPage._isAuthenticating && !fromButton) return;

    HomeScreenPage._isAuthenticating = true;
    _setBiometricLocked(true);
    if (mounted) setState(() => _showBiometricGateScreen = false);

    if (!fromButton) {
      await Future.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted) {
      HomeScreenPage._isAuthenticating = false;
      HomeScreenPage._sessionUiLocked = false;
      return;
    }

    final hasBiometrics = await UnifiedBiometricHelper.isBiometricAvailable();
    if (!mounted) {
      HomeScreenPage._isAuthenticating = false;
      return;
    }

    if (!hasBiometrics) {
      await _showBiometricRequiredDialog();
      HomeScreenPage._isAuthenticating = false;
      if (mounted) setState(() => _showBiometricGateScreen = true);
      return;
    }

    final authenticated = await _authenticateWithBiometricTimeout();

    if (!mounted) {
      HomeScreenPage._isAuthenticating = false;
      return;
    }

    if (authenticated) {
      HomeScreenPage._didAuthenticateThisSession = true;
      _setBiometricLocked(false);
      setState(() => _showBiometricGateScreen = false);
    } else {
      // Cancel / miss keeps the lock overlay visible (session stays logged in).
      _setBiometricLocked(true);
      setState(() => _showBiometricGateScreen = true);
    }
    HomeScreenPage._isAuthenticating = false;
  }

  Future<bool> _authenticateWithBiometricTimeout() {
    return UnifiedBiometricHelper.authenticate(
      context: context,
      title: 'تحقق من الهوية',
      subtitle: 'يرجى التحقق من هويتك للمتابعة',
      reason: 'تحقق من هويتك بعد تسجيل الدخول',
      stickyAuth: false,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () async {
        debugPrint(
            'Post-login biometric prompt timed out; keeping lock overlay');
        await DeviceAuthService.instance.cancelAuthentication();
        return false;
      },
    );
  }

  Future<void> _showBiometricRequiredDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('البصمة مطلوبة'),
        content: const Text(
          'يجب تفعيل بصمة الوجه أو بصمة الإصبع على الجهاز للمتابعة. رمز PIN أو كلمة المرور غير مسموحين لأسباب أمنية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // NOTE: HomeScreen no longer registers a WidgetsBindingObserver. All
  // app-resume work (attendance sync, badge refresh, prayer handover) is
  // owned by ResumeCoordinator (see main.dart), and location-services
  // enforcement lives in the check-in panel where it actually matters.

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;
    // final drawerWidth = screenWidth * 0.75; // 75% of screen width
    final gateLocked = _isBiometricLocked || HomeScreenPage.isSessionUiLocked;
    return Scaffold(
      backgroundColor: HomeGlassTheme.silverLeft,
      extendBody: false,
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: gateLocked,
            child: const MainHomeContentWidget(),
          ),
          BlocBuilder<HomeBloc, HomeState>(
            buildWhen: (previous, current) => current is ReorderModeChanged,
            builder: (context, state) {
              final bloc = HomeBloc.get(context);
              if (!bloc.isReorderMode || gateLocked) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 120.h,
                right: 20.w,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        bloc.add(const ToggleReorderModeEvent());
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32.sp,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (gateLocked && _showBiometricGateScreen)
            Positioned.fill(
              child: BiometricSignInGateScreen(
                onSignInWithBiometric: () =>
                    _authenticateAfterLogin(fromButton: true),
              ),
            )
          else if (gateLocked)
            const Positioned.fill(
              child: _BiometricLockOverlay(),
            ),
        ],
      ),
    );
  }
}

/// Full-screen non-dismissible barrier while Face ID / fingerprint is required.
class _BiometricLockOverlay extends StatelessWidget {
  const _BiometricLockOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 56.sp,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Authentication required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Use Face ID or fingerprint to unlock the app.\nYou cannot use the app until authentication succeeds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
