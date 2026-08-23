import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/security/device_security_service.dart';
import 'package:el_race/core/services/resume_coordinator.dart';
import 'package:el_race/chat/chat.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_audio_service.dart';
import 'package:el_race/data/services/prayer_background_service.dart';
import 'package:el_race/providers/announcements_provider.dart';
import 'package:el_race/providers/global_search_provider.dart';
import 'package:el_race/providers/profile_box_provider.dart';
import 'package:el_race/ui/presentation/call_screen/bloc/contact_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_sheet_host.dart';
import 'package:el_race/ui/presentation/media/bloc/media_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_request/bloc/requests_bloc.dart';
import 'package:el_race/ui/presentation/qr_code/bloc/qr_code_bloc.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/deep_links/uaepass_link_handler.dart';
import 'package:el_race/ui/presentation/splash_screen/splash_screen.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/qr_survey/providers/qr_survey_data_provider.dart';
import 'package:el_race/ui/presentation/qr_survey/services/qr_survey_api_service.dart';
import 'package:el_race/ui/presentation/qr_survey/screens/qr_code_wrapper.dart';
import 'package:el_race/ui/presentation/tasks/data/tasks_api_service.dart';
import 'package:el_race/ui/presentation/tasks/data/tasks_repository.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/utils/di.dart';
import 'package:el_race/utils/generated_routes.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/screen_size_util.dart';
import 'package:el_race/data/services/auto_checkout_service.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/data/services/counter_reset_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/data/services/unified_workmanager_dispatcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:el_race/core/app_globals.dart';
import 'core/services/app_config_service.dart';
import 'core/services/attendance_status_sync_service.dart';
import 'firebase_service.dart';
import 'report_module/data/provider/reports_provider.dart';
import 'ui/presentation/Email Approval/bloc/approval_bloc.dart';
import 'ui/presentation/home_screen/provider/slider_provider.dart';

// Background message handler - يجب أن يكون خارج main()
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  // Mute prefs live in SharedPreferences — must init in this isolate.
  try {
    await SharedPref().instantiatePreferences();
  } catch (_) {}

  print('📩 Background message received: ${message.notification?.title}');
  print('📩 Message data: ${message.data}');

  // Save notification to storage
  try {
    final notification = message.notification;
    final title = (notification?.title ??
            message.data['title'] ??
            message.data['subject'] ??
            '')
        .toString()
        .trim();
    final body = (notification?.body ??
            message.data['body'] ??
            message.data['message'] ??
            '')
        .toString()
        .trim();

    if (title.isEmpty && body.isEmpty) {
      print('⚠️ Background skip: empty FCM payload');
      return;
    }

    String category = 'notification';
    if (message.data.containsKey('category')) {
      category = message.data['category'].toString();
    } else if (message.data.containsKey('type')) {
      category = message.data['type'].toString();
    } else if (message.data.containsKey('model')) {
      category = message.data['model'].toString();
    }

    // Local cache only — no network from BG isolate (G4).
    final muted = await NotificationStorageService.shouldMuteNotification(
      category: category,
      data: message.data,
      allowNetwork: false,
    );
    if (muted) {
      print(
          '🔇 Background notification suppressed by mute settings: category=$category');
      return;
    }

    await NotificationStorageService.saveNotification(
      title: title.isEmpty ? 'Notification' : title,
      body: body,
      imageUrl: notification?.android?.imageUrl ?? notification?.apple?.imageUrl,
      data: message.data,
      category: category,
    );
    print('✅ Background notification saved to storage');
  } catch (e) {
    print('❌ Error saving background notification: $e');
  }
}

/// Last time we logged a given error signature, to avoid flooding logs when an
/// error (e.g. a runaway async chain) repeats rapidly.
final Map<String, DateTime> _lastGuardLogAt = {};

/// SharedPref key used to persist the first app-frame of a swallowed
/// StackOverflowError so a "hang" that was previously invisible in the field
/// leaves a breadcrumb readable on the next app start. Phase 0 instrumentation
/// only — the guard still swallows the error (see [_logGuardedError]).
const String _kStackOverflowBreadcrumbKey = 'debug_stack_overflow_breadcrumb';

/// Installs process-wide guards so a single unhandled error — including a
/// runaway async error chain that manifests as a `StackOverflowError` — cannot
/// hard-crash the app in production. Errors are logged once (deduped) with any
/// real originating frame preserved for diagnosis.
void _installGlobalErrorGuard() {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _logGuardedError('FlutterError', details.exception, details.stack);
    previousFlutterOnError?.call(details);
  };

  // Catches unhandled async errors in the root zone (no runZonedGuarded needed).
  // Returning true marks the error handled so the engine does not treat it as
  // fatal.
  WidgetsBinding.instance.platformDispatcher.onError = (
    Object error,
    StackTrace stack,
  ) {
    _logGuardedError('PlatformDispatcher', error, stack);
    return true;
  };
}

void _logGuardedError(String source, Object error, StackTrace? stack) {
  final signature = '$source:${error.runtimeType}';
  final now = DateTime.now();
  final last = _lastGuardLogAt[signature];
  // Throttle identical errors to at most one log every 3 seconds.
  if (last != null && now.difference(last) < const Duration(seconds: 3)) {
    return;
  }
  _lastGuardLogAt[signature] = now;

  if (error is StackOverflowError) {
    final lines = stack?.toString().split('\n') ?? const <String>[];
    // The async plumbing frames are useless; surface the first app-code frame
    // (if any) so the runaway source can be identified.
    final appFrame = lines.firstWhere(
      (line) => line.contains('package:el_race/'),
      orElse: () => '(no app frame in stack — likely infinite async chain)',
    );
    // When there's no app frame, the recursion is happening inside a plugin
    // or the Dart SDK itself. A StackOverflowError's trace is almost always
    // a small cycle of frames repeated thousands of times — the first ~20
    // lines are enough to show that cycle and name the actual package
    // responsible, instead of just "no app frame" with no further lead.
    final packageFrames = lines
        .where((line) => line.contains('package:') || line.contains('dart:'))
        .take(20)
        .join('\n');
    debugPrint('🛑 [$source] StackOverflowError swallowed. First app frame: '
        '$appFrame');
    debugPrint('🛑 [$source] First 20 package/dart frames (repeating cycle):\n'
        '$packageFrames');
    _persistStackOverflowBreadcrumb(source, '$appFrame\n$packageFrames');
    return;
  }

  debugPrint('🛑 [$source] Unhandled error swallowed: $error');
}

/// Persists the first app-frame of a swallowed StackOverflowError so it can
/// be surfaced on the next app start (see [_checkStackOverflowBreadcrumb]).
/// Best-effort: SharedPref may not be instantiated yet if the error happens
/// before Phase-1 init completes, so failures here are swallowed same as the
/// rest of this file's early-startup guards.
void _persistStackOverflowBreadcrumb(String source, String? appFrame) {
  try {
    SharedPref().setPreferencesString(
      _kStackOverflowBreadcrumbKey,
      '${DateTime.now().toIso8601String()} [$source] $appFrame',
    );
  } catch (e) {
    debugPrint('🛑 Failed to persist StackOverflowError breadcrumb: $e');
  }
}

/// Logs and clears any StackOverflowError breadcrumb left by a previous
/// session. Called once SharedPref is guaranteed initialized.
void _checkStackOverflowBreadcrumb() {
  try {
    final breadcrumb =
        SharedPref().getPreferenceString(_kStackOverflowBreadcrumbKey);
    if (breadcrumb.isNotEmpty) {
      debugPrint(
          '🛑 [breadcrumb] Previous session recorded a StackOverflowError: $breadcrumb');
      SharedPref().removePreference(_kStackOverflowBreadcrumbKey);
    }
  } catch (e) {
    debugPrint('🛑 Failed to read StackOverflowError breadcrumb: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 main(): Flutter binding initialized');

  _installGlobalErrorGuard();

  // await _enableGlobalScreenProtection();

  // MyApp resolves these blocs during its first build, so DI must be ready
  // before runApp. Starting it from a post-frame callback creates a deadlock:
  // the first frame fails while resolving an unregistered bloc, and the
  // callback that would register it never runs.
  try {
    debugPrint('🚀 main(): initializing dependencies required by first frame');
    await initDI().timeout(const Duration(seconds: 10));
    _verifyStartupDependencies();
  } catch (error, stackTrace) {
    debugPrint('❌ main(): dependency initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error));
    return;
  }

  // ── PHASE 1: Bare-minimum init (fast, needed before first frame) ──
  try {
    await Future.wait([
      SharedPref().instantiatePreferences(),
      Firebase.initializeApp(),
      DeviceUiCapability.init(),
    ]).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ Phase-1 init timeout – continuing');
        return [];
      },
    );
  } catch (e) {
    print('❌ Phase-1 init error: $e');
  }
  // SharedPref is now instantiated (best-effort) — surface any
  // StackOverflowError breadcrumb left by a previous session.
  _checkStackOverflowBreadcrumb();

  // Localization is required by MyApp, but must never leave a native white
  // screen indefinitely if loading its assets fails.
  late final LocalizationDelegate delegate;
  try {
    delegate = await LocalizationDelegate.create(
      fallbackLocale: 'en',
      supportedLocales: ['en'],
      basePath: 'assets/i18n',
    ).timeout(const Duration(seconds: 10));
  } catch (error, stackTrace) {
    debugPrint('❌ main(): localization initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error));
    return;
  }
  // Allow runtime Google Fonts fetch so missing font files don't crash app startup.
  // TODO: Set back to false only after bundling all used font TTFs in assets.
  GoogleFonts.config.allowRuntimeFetching = true;

  // ── Launch the UI immediately so the native splash disappears fast ──
  debugPrint('🚀 main(): startup ready; calling runApp()');
  runApp(
    BlocProvider(
      create: (_) => ApprovalBloc(),
      child: LocalizedApp(delegate, const MyApp()),
    ),
  );

  // ── PHASE 2: Heavy init (runs AFTER first frame is drawn) ──
  // Using addPostFrameCallback ensures the first frame is painted before
  // any heavy work starts, giving a smooth native-splash → Flutter transition.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _performHeavyInitialization();
  });
}

void _verifyStartupDependencies() {
  final missing = <String>[
    if (!sl.isRegistered<SignInBloc>()) 'SignInBloc',
    if (!sl.isRegistered<HomeBloc>()) 'HomeBloc',
    if (!sl.isRegistered<RequestsBloc>()) 'RequestsBloc',
    if (!sl.isRegistered<ApprovalBloc>()) 'ApprovalBloc',
    if (!sl.isRegistered<ContactBloc>()) 'ContactBloc',
    if (!sl.isRegistered<NotesBloc>()) 'NotesBloc',
    if (!sl.isRegistered<MediaBloc>()) 'MediaBloc',
    if (!sl.isRegistered<UaepassAuthCubit>()) 'UaepassAuthCubit',
  ];
  if (missing.isNotEmpty) {
    throw StateError('Missing startup dependencies: ${missing.join(', ')}');
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'The app could not finish starting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
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

Future<void> _enableGlobalScreenProtection() async {
  try {
    await Future.wait<void>([
      ScreenProtector.preventScreenshotOn(),
      ScreenProtector.protectDataLeakageOn(),
    ]);
    debugPrint('✅ Screen protection enabled globally');
  } catch (e) {
    debugPrint('❌ Failed to enable screen protection: $e');
  }
}

/// Runs all the heavy services in the background.
/// [appInitCompleter] is completed as soon as the CRITICAL services are ready
/// (DI, Hive, AppConfig, Firebase) so the splash screen can navigate quickly.
/// Non-critical services continue initializing in the background after that.
Future<void> _performHeavyInitialization() async {
  // ── CRITICAL PATH (blocks splash navigation) ──────────────────────────
  try {
    // Step 1: Hive. DI is already initialized before runApp because MyApp
    // resolves its blocs during the first build.
    try {
      await HiveService.setupHive().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ Hive init timeout');
        },
      );
    } catch (e) {
      print('❌ Hive error: $e');
    }

    // Step 2: AppConfig + Firebase (parallel – independent of each other)
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (_) {}

    try {
      await Future.wait([
        AppConfigService.instance.load().timeout(
              const Duration(seconds: 10),
              onTimeout: () => print('⚠️ AppConfig load timeout'),
            ),
        FirebaseService.initialize(
          requestPermissions: false,
          fetchToken: false,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => print('⚠️ Firebase service init timeout'),
        ),
      ]);
    } catch (e) {
      print('❌ Critical services error: $e');
    }

    print('✅ Critical initialization complete');
  } catch (e) {
    print('❌ Unexpected error in critical init: $e');
  } finally {
    // Signal splash screen it can navigate NOW.
    if (!appInitCompleter.isCompleted) {
      appInitCompleter.complete();
    }
  }

  // ── NON-CRITICAL PATH (runs after splash can already navigate) ────────
  // These services are needed for full functionality but NOT for the splash
  // to finish. Running them in parallel maximizes throughput and minimizes
  // total main-thread blocking time.
  await Future.delayed(Duration.zero); // yield once before the batch
  _initializeNonCriticalServices();
}

/// Background services that don't gate splash navigation.
/// All independent services run in parallel.
Future<void> _initializeNonCriticalServices() async {
  // Fire-and-forget FCM token
  _logFcmToken();

  // Run all independent services in parallel
  await Future.wait<void>([
    FirebaseService.completeDeferredSetup(),
    _initWorkManager(),
    _initPrayerAndCheckoutServices(),
    _initializeChatIfLoggedIn(),
  ]);

  print('✅ All background services initialized');

  // PHASE 4: Permissions + System UI (after everything else)
  try {
    await _requestEssentialPermissions();
  } catch (_) {}
  try {
    await _configureAppSystemUi();
  } catch (_) {}
}

/// WorkManager + periodic task scheduling
Future<void> _initWorkManager() async {
  try {
    await Workmanager()
        .initialize(unifiedCallbackDispatcher, isInDebugMode: false);
    debugPrint('✅ WorkManager initialized');

    await Future.wait<void>([
      Workmanager().registerPeriodicTask(
        'taskDeadlineCheck',
        taskDeadlineCheckTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      ),
      TimesheetCaptureQueueService().registerBackgroundDrain(),
      TaskNotificationService().initialize(),
    ]);
    debugPrint('✅ Task deadline check scheduled');
  } catch (e) {
    print('❌ WorkManager/task error: $e');
  }
}

/// Prayer, checkout, counter, check-in reminders, attendance sync
Future<void> _initPrayerAndCheckoutServices() async {
  try {
    // These are all independent – run in parallel
    await Future.wait<void>([
      PrayerBackgroundService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => print('⚠️ Prayer service timeout'),
      ),
      AutoCheckoutService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => print('⚠️ Auto checkout timeout'),
      ),
      CounterResetService.checkAndResetOnAppStart().then((_) async {
        debugPrint('✅ Counter reset check done');
        await CounterResetService.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () => print('⚠️ Counter reset service timeout'),
        );
        debugPrint('✅ Daily counter reset scheduled');
      }),
    ]);
  } catch (e) {
    print('❌ Service init error: $e');
  }

  // Attendance sync only (check-in/out local reminders disabled).
  if (SharedPref.isUserAuthenticated()) {
    try {
      await Future.wait<void>([
        CheckInReminderNotificationService().cancelAllReminders().timeout(
              const Duration(seconds: 5),
              onTimeout: () {},
            ),
        _syncAttendanceStatusIfLoggedIn(),
      ]);

      final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
      if (isCheckedIn) {
        await AutoCheckoutService.scheduleAutoCheckout();
        debugPrint('✅ Auto checkout scheduled');
      }
    } catch (e) {
      print('❌ Attendance sync error: $e');
    }
  }
}

/// Log FCM token without blocking startup (debug builds only — the token
/// must never appear in production logs).
Future<void> _logFcmToken() async {
  if (!kDebugMode) return;
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ FCM token timeout');
        return null;
      },
    );
    if (fcmToken != null) {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔥 FCM TOKEN :');
      print('═══════════════════════════════════════════════════════════');
      print(fcmToken);
      print('═══════════════════════════════════════════════════════════');
      print('');
    }
  } catch (e) {
    print('❌ FCM token error: $e');
  }
}

Timer? _androidSystemBarsTimer;

Future<void> _configureAppSystemUi() async {
  await _lockPortraitOrientation();

  if (Platform.isAndroid) {
    await _enableAndroidImmersiveMode();
    return;
  }

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

const _systemUiChannel = MethodChannel('ae.elrace.mobile/system_ui');

/// Phones stay portrait-only. Tablets may rotate so Home multi-pane can use
/// landscape width (otherwise both orientations report ~phone/portrait width).
Future<void> _configureAppOrientations() async {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  var isTablet = false;
  if (views.isNotEmpty) {
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    // shortestSide >= 600 ≈ Material tablet breakpoint
    isTablet = logical.shortestSide >= 600;
  }

  if (isTablet) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}

/// @Deprecated — use [_configureAppOrientations]. Kept name for call sites.
Future<void> _lockPortraitOrientation() => _configureAppOrientations();


Future<void> _enableAndroidImmersiveMode() async {
  if (!Platform.isAndroid) return;

  // إخفاء النافيقيشن بار (تحت) فقط مع إبقاء الستاتس بار (فوق) ظاهر
  // نستخدم native MethodChannel لأن Flutter لا يدعم إخفاء النافيقيشن بار
  // فقط مع سلوك edge-swipe (BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE)
  try {
    await _systemUiChannel.invokeMethod('hideNavigationBar');
  } catch (e) {
    // fallback to Flutter API if native channel fails
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
    ),
  );
}

Future<void> _showAndroidSystemBarsTemporarily() async {
  if (!Platform.isAndroid) return;

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  _androidSystemBarsTimer?.cancel();
  _androidSystemBarsTimer = Timer(const Duration(seconds: 2), () {
    _enableAndroidImmersiveMode();
  });
}

/// Request Camera and Location permissions at app start
/// This prevents lag when opening face registration or check-in screens
Future<void> _requestEssentialPermissions() async {
  try {
    print('📍 Requesting essential permissions...');

    // Request Camera permission
    final cameraStatus = await Permission.camera.request();
    print('📷 Camera permission: $cameraStatus');

    // Request Location permission
    final locationStatus = await Permission.location.request();
    print('📍 Location permission: $locationStatus');

    print('✅ Essential permissions requested');
  } catch (e) {
    print('⚠️ Error requesting permissions: $e');
  }
}

/// Sync today's attendance status if the user is logged in.
/// Called on every app startup so external check-ins/outs are reflected
/// in the app's timer and UI without requiring the user to manually refresh.
Future<void> _syncAttendanceStatusIfLoggedIn() async {
  try {
    if (!SharedPref.isUserAuthenticated()) return;
    await AttendanceStatusSyncService.refreshFromServer(reason: 'app_startup')
        .timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  } catch (_) {}
}

/// Initialize chat module if user is already logged in.
/// This restores chat session on app restart.
Future<void> _initializeChatIfLoggedIn() async {
  try {
    if (SharedPref.isUserAuthenticated()) {
      print('🔷 main: User is authenticated, restoring chat session...');
      final result = await ChatModuleHelper.instance.restoreFromStoredSession();
      if (result != null && result.chatEnabled) {
        print('✅ main: Chat session restored successfully');
      } else {
        print('ℹ️ main: Chat not available: ${result?.error ?? "No session"}');
      }
    } else {
      print('ℹ️ main: User not authenticated, skipping chat initialization');
    }
  } catch (e) {
    print('❌ main: Error initializing chat: $e');
    // Don't rethrow - chat is optional
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const Duration _inactiveTimeout = Duration(minutes: 10);
  DateTime? _backgroundedAt;
  bool _isRestartingFromTimeout = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 MyApp.initState(): first Flutter screen tree started');
    WidgetsBinding.instance.addObserver(this);
    _enableAndroidImmersiveMode();
    // NOTE: Do NOT call FirebaseService.processPendingNotificationTap() here.
    // At this point the SplashScreen is still running. Notification taps
    // require the full app context (HomeBloc, providers, auth session) that is
    // only available after the splash completes. markHomeReady() in
    // SplashScreen._navigateToNextScreen() will replay any queued tap.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // T0 — synchronous UI chrome only; everything else is deferred.
      _enableAndroidImmersiveMode();
      // ignore: unawaited_futures
      _lockPortraitOrientation();

      // Long-idle security re-verification runs silently in the background;
      // it only routes to splash if the device check actually fails.
      final lastBackground = _backgroundedAt;
      if (lastBackground != null && !_isRestartingFromTimeout) {
        final inactiveFor = DateTime.now().difference(lastBackground);
        if (inactiveFor >= _inactiveTimeout) {
          // ignore: unawaited_futures
          _recheckSecurityAfterTimeout(inactiveFor);
        }
      }

      // Tiered resume work (prayer foreground handover, badge refresh,
      // attendance sync) — single owner, never blocks the UI.
      ResumeCoordinator.instance.onResumed();

      _backgroundedAt = null;
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgroundedAt ??= DateTime.now();

      // Stop foreground timer and arm a single OS schedule per prayer.
      if (state == AppLifecycleState.paused) {
        // ignore: unawaited_futures
        PrayerAudioService().enterBackgroundMode();
      }
    }
  }

  /// Long-idle (>= [_inactiveTimeout]) security re-verification.
  ///
  /// Previously this unconditionally tore down the route stack and replayed
  /// the full SplashScreen (video decode + security check + re-navigation) on
  /// every 10-minute background — while HomeScreen's own resume work raced it
  /// for CPU, producing the "splash video stuck" hang. The security intent is
  /// preserved: the same device check still runs after long idle, but
  /// silently. Only a failed check (or an expired login) falls back to the
  /// splash restart, where SplashScreen's own gates show the blocking
  /// security dialog / login flow.
  Future<void> _recheckSecurityAfterTimeout(Duration inactiveFor) async {
    _isRestartingFromTimeout = true;
    debugPrint(
      '⏱️ Inactivity timeout reached (${inactiveFor.inMinutes} min). '
      'Running silent security re-check...',
    );
    try {
      if (!SharedPref.isUserAuthenticated()) {
        debugPrint('⏱️ Silent re-check: session no longer authenticated — restarting from splash');
        _restartFromSplash();
        return;
      }
      final result = await DeviceSecurityService.instance
          .performSecurityCheck()
          .timeout(const Duration(seconds: 6));
      if (result.isSecure) {
        debugPrint('⏱️ Silent security re-check passed — continuing without splash restart');
        return;
      }
      debugPrint('⏱️ Silent security re-check FAILED — restarting from splash');
      _restartFromSplash();
    } catch (e) {
      // Fail-open, same policy as SplashScreen's own check: a check error
      // (timeout, plugin failure) must not lock the user out.
      debugPrint('⏱️ Silent security re-check error ($e) — fail-open, no restart');
    } finally {
      if (!isRestartingFromSplashTimeout.value) {
        _isRestartingFromTimeout = false;
      }
    }
  }

  void _restartFromSplash() {
    // Tell other resume observers (ResumeCoordinator, HomeScreen) a splash
    // restart is in flight so they skip their own resume work instead of
    // racing the new SplashScreen's video/security-check gates.
    isRestartingFromSplashTimeout.value = true;

    final navigator = navKey.currentState;
    if (navigator == null) {
      _isRestartingFromTimeout = false;
      isRestartingFromSplashTimeout.value = false;
      return;
    }

    // Reset home-ready flag so notification taps are re-queued until
    // the splash screen finishes and auth is confirmed again.
    FirebaseService.markHomeNotReady();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );

    // Allow future timeout checks after navigation settles.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      _isRestartingFromTimeout = false;
      isRestartingFromSplashTimeout.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizationDelegate = LocalizedApp.of(context).delegate;
    SizeConfig().init(context);
    OnGeneratedRoutes onGeneratedRoutes = OnGeneratedRoutes();

    // Initialize deep linking
    _initDeepLinking(context);

    return ProviderScope(
      child: LocalizationProvider(
        state: LocalizationProvider.of(context).state,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SliderProvider()),
            ChangeNotifierProvider(create: (_) => ProfileBoxProvider()),
            ChangeNotifierProvider(create: (_) => ReportProvider()),
            ChangeNotifierProvider(create: (_) => TodoFirebaseProvider()),
            ChangeNotifierProvider(create: (_) => TicketFirebaseProvider()),
            ChangeNotifierProvider(create: (_) => QrSurveyDataProvider()),
            ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
            ChangeNotifierProvider(create: (_) => GlobalSearchProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  TasksProvider(TasksRepository(api: TasksApiService())),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (ctx) => sl<SignInBloc>()),
              BlocProvider(create: (ctx) => sl<HomeBloc>()),
              BlocProvider(create: (ctx) => sl<RequestsBloc>()),
              BlocProvider(create: (ctx) => sl<ApprovalBloc>()),
              // BlocProvider(create: (ctx) => sl<ProjectListBloc>()), // Temporarily disabled for iOS simulator
              BlocProvider(create: (ctx) => sl<ContactBloc>()),
              BlocProvider(create: (ctx) => sl<NotesBloc>()),
              BlocProvider(create: (ctx) => sl<MediaBloc>()),
              BlocProvider(create: (ctx) => QrCodeBloc()),
              BlocProvider(create: (ctx) => sl<UaepassAuthCubit>()),
            ],
            child: ScreenUtilInit(
              designSize: const Size(411.4, 843.4),
              minTextAdapt: true,
              splitScreenMode: true,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorObservers: [AppOrientations.routeObserver],
                builder: (context, child) {
                  ScreenSizeUtil.context = context;
                  return NotificationListener<ScrollUpdateNotification>(
                    onNotification: (notification) {
                      if (notification.scrollDelta != null &&
                          notification.scrollDelta! < -1) {
                        _showAndroidSystemBarsTemporarily();
                      }
                      return false;
                    },
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerMove: (event) {
                        if (event.delta.dy < -4) {
                          _showAndroidSystemBarsTemporarily();
                        }
                      },
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final profileBoxProvider =
                                  Provider.of<ProfileBoxProvider>(context,
                                      listen: false);
                              if (profileBoxProvider.isProfileVisible) {
                                profileBoxProvider.hideProfileBox();

                                /// Close the profile box
                              }
                            },
                            child: child!,
                          ),
                          Theme(
                            data: ThemeData(
                              colorScheme: ColorScheme.fromSeed(
                                  seedColor: Colors.deepPurple),
                              useMaterial3: true,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                              textTheme:
                                  GoogleFonts.poppinsTextTheme(const TextTheme(
                                displayLarge: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w700),
                                titleMedium: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                bodyMedium: TextStyle(fontSize: 14),
                              )),
                            ),
                            child: const ProfileBoxWithSlideAnimation(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                navigatorKey: navKey,
                title: 'El Race',
                theme: ThemeData(
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                  useMaterial3: true,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  pageTransitionsTheme: DeviceUiCapability.isLowEnd
                      ? const PageTransitionsTheme(
                          builders: {
                            TargetPlatform.android:
                                FadeUpwardsPageTransitionsBuilder(),
                            TargetPlatform.iOS:
                                CupertinoPageTransitionsBuilder(),
                          },
                        )
                      : null,
                  textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
                    displayLarge:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    titleMedium:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    bodyMedium: TextStyle(fontSize: 14),
                  )),
                ),
                localizationsDelegates: [
                  localizationDelegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en')],
                locale: const Locale('en'),
                onGenerateRoute: onGeneratedRoutes.generatedRoutes,
                home: const SplashScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final GlobalKey<OverlayState> appOverlayKey = GlobalKey<OverlayState>();
bool _deepLinkingInitialized = false;
Uri? _lastHandledDeepLink;
DateTime? _lastHandledAt;
bool _initialDeepLinkProcessed = false; // Track if initial link was handled
const Duration _deepLinkDedupWindow = Duration(seconds: 2);

// Deep Linking Handler
void _initDeepLinking(BuildContext context) {
  // Prevent multiple initializations on rebuild
  if (_deepLinkingInitialized) {
    return;
  }
  _deepLinkingInitialized = true;

  print(
      '🚀 ==================== INITIALIZING DEEP LINKING ====================');
  final appLinks = AppLinks();

  // Handle incoming links - the app is already started
  print('👂 Listening for incoming deep links...');
  appLinks.uriLinkStream.listen((uri) {
    print('🔗 Deep link received (stream): $uri');
    _handleDeepLink(uri, context);
  }, onError: (err) {
    print('❌ Deep link stream error: $err');
  });

  // Handle cold-start deep links (app was killed and relaunched via deep link)
  if (!_initialDeepLinkProcessed) {
    _initialDeepLinkProcessed = true;
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        print('🔗 Initial deep link (cold start): $uri');
        // Small delay to ensure the widget tree is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(uri, context);
        });
      } else {
        print('ℹ️ No initial deep link on app start');
      }
    }).catchError((err) {
      print('❌ Error getting initial deep link: $err');
    });
  }
  print(
      '🚀 ==================== DEEP LINKING INITIALIZED ====================');
}

void _handleDeepLink(Uri uri, BuildContext context) async {
  // Drop duplicate events that arrive back-to-back for the same URI
  if (_lastHandledDeepLink == uri) {
    final now = DateTime.now();
    if (_lastHandledAt != null &&
        now.difference(_lastHandledAt!) <= _deepLinkDedupWindow) {
      print('⏩ Skipping duplicate deep link within debounce window: $uri');
      return;
    }
  }

  _lastHandledDeepLink = uri;
  _lastHandledAt = DateTime.now();

  print('🔗 ==================== DEEP LINK HANDLER ====================');
  print('🔗 Received URI: $uri');
  print('🔗 Host: ${uri.host}');
  print('🔗 Path: ${uri.path}');
  print('🔗 Query Parameters: ${uri.queryParameters}');

  if (await UaepassLinkHandler.handle(uri)) {
    return;
  }

  // Check if it's a QR code survey link
  // Format: https://elrace.com/RCC4/Requirements/qrcodeapp or qrcodeapp.php
  if (uri.host == 'elrace.com' &&
      (uri.path.contains('/RCC4/Requirements/qrcodeapp.php') ||
          uri.path.contains('/RCC4/Requirements/qrcodeapp'))) {
    print('📱 QR Survey link detected!');
    print('📱 Path matched: ${uri.path}');
    print('📱 Starting API call to fetch content...');

    // Fetch content from API
    try {
      final content = await QrSurveyApiService().getContentAfterQrCodeScanned();
      print(
          '📦 API Response received: ${content != null ? "Success" : "Null"}');

      if (content != null && context.mounted) {
        print('📦 Content Data: $content');

        // Validate content structure
        if (content['type'] == null || content['data'] == null) {
          print('❌ Invalid content structure - missing type or data');
          _showErrorDialog(
            navKey.currentContext ?? context,
            'Invalid Content',
            'The QR code content is not properly formatted. Please try again.',
          );
          return;
        }

        // Store in provider with QR code flag
        final effectiveContext = navKey.currentContext ?? context;
        final provider =
            Provider.of<QrSurveyDataProvider>(effectiveContext, listen: false);
        provider.setContentData(content, fromQrCode: true);
        print('✅ Content stored in provider (from QR code)');

        // Check if user is logged in
        print('🔐 Checking login status...');
        final loginData = SharedPref.getLoginData();
        final token = loginData.result?.token;
        final isLoggedIn = token != null && token.isNotEmpty;
        final qrStatus = loginData.result?.data?.qr_status;

        print(
            '🔐 Token: ${token != null ? "Found (${token.substring(0, 10)}...)" : "Not Found"}');
        print('🔐 Is Logged In: $isLoggedIn');
        print('🔐 QR Status: $qrStatus');

        // Navigate based on login status and QR permissions
        if (isLoggedIn) {
          // Check if user has QR access permission
          // Support: qr_status = 1 (int), true (bool), "1" (string)
          final hasQrPermission = qrStatus == 1 ||
              qrStatus == true ||
              qrStatus == '1' ||
              qrStatus?.toString() == '1';

          if (hasQrPermission) {
            // Logged in user with QR permission - switch to QR Survey screen
            print(
                '✅ User logged in with QR permission - switching to QR Survey');

            final context = navKey.currentContext;
            if (context != null) {
              final homeBloc = HomeBloc.get(context);
              homeBloc
                  .add(ChangeCurrentIndex(index: 3)); // Show QR Survey screen
            }
          } else {
            // Logged in but no QR permission - show error dialog
            print(
                '❌ User logged in but NO QR permission (qr_status = $qrStatus)');
            navKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Access Denied'),
                    backgroundColor: Colors.red,
                  ),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.block,
                            size: 80,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No QR Access Permission',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your account does not have permission to access QR survey content. Please contact your administrator.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        } else {
          // Guest user - show without AppBar and BottomBar
          print('👤 Guest user - showing guest screen (no AppBar/BottomBar)');
          navKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => const QrCodeWrapper(),
            ),
          );
        }
        print(
            '🔗 ==================== NAVIGATION COMPLETE ====================');
      } else {
        print(
            '❌ Content is null or context not mounted - showing error message');
        if (context.mounted) {
          _showErrorDialog(
            navKey.currentContext ?? context,
            'No Content Available',
            'The QR code did not return any content. Please try scanning again or contact support.',
          );
        }
        print(
            '🔗 ==================== NAVIGATION FAILED (NO CONTENT) ====================');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling QR deep link: $e');
      print('❌ Stack trace: $stackTrace');

      // Show error to user
      if (context.mounted) {
        _showErrorDialog(
          navKey.currentContext ?? context,
          'Error Loading Content',
          'An error occurred while loading the QR content. Please try again later.\n\nError: $e',
        );
      }
      print('🔗 ==================== ERROR OCCURRED ====================');
    }
  } else {
    print('⚠️ URI does not match expected pattern');
    print('⚠️ Expected: https://elrace.com/RCC4/Requirements/qrcodeapp[.php]');
  }
  print('🔗 ==================== END DEEP LINK HANDLER ====================');
}

/// Helper function to show error dialog
void _showErrorDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
