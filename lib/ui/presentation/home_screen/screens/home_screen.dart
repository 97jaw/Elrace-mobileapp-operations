import 'dart:async';

import 'package:el_race/core/biometric/unified_biometric_helper.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/location_bloc/location_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_home_content_widget.dart';
import 'package:el_race/ui/presentation/home_screen/screens/main_screens.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';
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

  /// Reset the biometric gate so the next login triggers it again.
  static void resetAuthSession() {
    _didAuthenticateThisSession = false;
    _isAuthenticating = false;
  }

  @override
  State<HomeScreenPage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenPage>
    with WidgetsBindingObserver {
  // auth flags are stored on the widget class so they can be reset from outside

  // bool isMuted = false; // default value
  bool isCheckedIn = false;
  final _locationBloc = LocationBloc();
  final Location _location = Location();

  // _loadMuteStatus() {
  //   setState(() {
  //     isMuted = SharedPref().getPreferenceBoolean('mute_notifications');
  //   });
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // مراقبة حالة التطبيق
    Get.put(TimerController()); // only once!
    // _loadMuteStatus();
    // Future.delayed(const Duration(seconds: 5), () {
    //   showBabyGirlPopup(context);
    // });
    _checkLocationService(); // Check location service on initialization
    _locationBloc.add(GetCurrentLocationET());

    // After login: authenticate with biometrics only once per app session.
    // Do not ask again when returning from Contacts or other tabs to Home.
    if (!AppConfigService.instance.shouldSkipFaceId &&
        !HomeScreenPage._didAuthenticateThisSession &&
        !HomeScreenPage._isAuthenticating) {
      _authenticateAfterLogin();
    }
    // List of pages or widgets that you want to display for each navigation ite
  }

  /// Authenticate user right after login using device biometrics only.
  /// PIN, passcode, password, and pattern fallback are not allowed.
  Future<void> _authenticateAfterLogin() async {
    if (HomeScreenPage._didAuthenticateThisSession || HomeScreenPage._isAuthenticating) {
      return;
    }

    HomeScreenPage._isAuthenticating = true;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      HomeScreenPage._isAuthenticating = false;
      return;
    }

    // Now actually authenticate (Face ID / fingerprint only)
    bool authenticated = false;
    while (!authenticated && mounted) {
      final hasBiometrics = await UnifiedBiometricHelper.isBiometricAvailable();
      if (!mounted) break;

      if (!hasBiometrics && mounted) {
        await _showBiometricRequiredDialog();
        continue;
      }

      authenticated = await UnifiedBiometricHelper.authenticate(
        context: context,
        title: 'تحقق من الهوية',
        subtitle: 'يرجى التحقق من هويتك للمتابعة',
        reason: 'تحقق من هويتك بعد تسجيل الدخول',
      );

      if (!authenticated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب التحقق من هويتك للمتابعة'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (authenticated) {
      HomeScreenPage._didAuthenticateThisSession = true;
    }
    HomeScreenPage._isAuthenticating = false;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // إزالة المراقبة
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationService(); // إعادة التحقق عند العودة
      _locationBloc.add(GetCurrentLocationET()); // إعادة جلب اللوكيشن

      // مزامنة حالة الحضور من السيرفر عند العودة من الخلفية
      // لضمان تحديث الأوقات والعداد بدون الحاجة لتسجيل خروج/دخول
      AttendanceStatusSyncService.refreshFromServer(reason: 'app_resumed');
    }
  }

  Future<void> _checkLocationService() async {
    // Check if location service is enabled
    bool isServiceEnabled = await _location.serviceEnabled();
    if (!isServiceEnabled) {
      // If not enabled, show popup
      _showLocationServiceDialog();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translate('location.enable_service')),
          content: Text(translate('location.please_enable')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                bool serviceEnabled = await _location.requestService();
                if (!serviceEnabled) {
                  // If still not enabled, show the dialog again
                  _showLocationServiceDialog();
                }
              },
              child: Text(translate('common.ok')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;
    // final drawerWidth = screenWidth * 0.75; // 75% of screen width
    return Scaffold(
      backgroundColor: HomeGlassTheme.silverLeft,
      extendBody: false,
      body: Stack(
        children: [
          const MainHomeContentWidget(),
          BlocBuilder<HomeBloc, HomeState>(
            buildWhen: (previous, current) => current is ReorderModeChanged,
            builder: (context, state) {
              final bloc = HomeBloc.get(context);
              if (!bloc.isReorderMode) return const SizedBox.shrink();
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
        ],
      ),
    );
  }
}
