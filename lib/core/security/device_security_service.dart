import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:safe_device/safe_device.dart';
import 'package:el_race/core/services/app_config_service.dart';

/// Security check result containing all security statuses
class SecurityCheckResult {
  final bool isRooted;
  final bool isJailbroken;
  final bool isUsingVpn;
  final bool isMockLocation;
  final bool isEmulator;
  final bool isSecure;
  final String? errorMessage;

  SecurityCheckResult({
    required this.isRooted,
    required this.isJailbroken,
    required this.isUsingVpn,
    required this.isMockLocation,
    required this.isEmulator,
    this.errorMessage,
  }) : isSecure = !isRooted &&
            !isJailbroken &&
            !isUsingVpn &&
            !isMockLocation &&
            !isEmulator;

  factory SecurityCheckResult.vpnOnly() => SecurityCheckResult(
        isRooted: false,
        isJailbroken: false,
        isUsingVpn: true,
        isMockLocation: false,
        isEmulator: false,
      );

  /// True when VPN is the only blocking reason.
  bool get isVpnOnlyViolation =>
      isUsingVpn &&
      !isRooted &&
      !isJailbroken &&
      !isMockLocation &&
      !isEmulator;

  String get dialogTitle {
    if (isVpnOnlyViolation) return 'VPN Not Allowed';
    if (isUsingVpn) return 'Security Warning';
    return 'Security Warning';
  }

  /// Returns the reason why device is not secure
  String getSecurityViolationMessage() {
    List<String> violations = [];

    if (isRooted || isJailbroken) {
      violations.add(Platform.isIOS
          ? 'Jailbreak detected on device'
          : 'Root access detected on device');
    }
    if (isUsingVpn) {
      violations.add('Active VPN connection detected');
    }
    if (isMockLocation) {
      violations.add('Fake location (Mock Location) detected');
    }
    if (isEmulator) {
      violations.add('Emulator detected');
    }

    if (violations.isEmpty) {
      return '';
    }

    return violations.join('\n');
  }

  /// Returns a user-friendly message
  String getUserFriendlyMessage() {
    if (isSecure) {
      return 'Device is secure ✓';
    }

    if (isVpnOnlyViolation) {
      final howTo =
          Platform.isIOS
              ? 'Open Settings → VPN (or General → VPN & Device Management), turn VPN off, then tap Retry.'
              : 'Turn off VPN in your device settings (or your VPN app), then tap Retry.';
      return 'A VPN connection is currently active on this device.\n\n'
          'For security reasons, Elrace Operations cannot be used while a VPN is connected.\n\n'
          'A VPN profile saved in Settings is fine — only an active connection is blocked.\n\n'
          '$howTo';
    }

    final vpnHint = isUsingVpn
        ? '\n\nIf you are using a VPN, please turn it off and try again.'
        : '';

    return 'The application cannot be used for the following reasons:\n\n'
        '${getSecurityViolationMessage()}'
        '$vpnHint\n\n'
        'Please fix these issues and restart the application.';
  }
}

/// Service for checking device security status
class DeviceSecurityService {
  static final DeviceSecurityService _instance =
      DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  static DeviceSecurityService get instance => _instance;

  /// Performs all security checks and returns the result
  Future<SecurityCheckResult> performSecurityCheck() async {
    bool isRooted = false;
    bool isJailbroken = false;
    bool isUsingVpn = false;
    bool isMockLocation = false;
    bool isEmulator = false;
    String? errorMessage;

    try {
      // Check Root/Jailbreak (bounded — flutter_jailbreak_detection can hang
      // several seconds on some iOS devices and was the splash bottleneck).
      try {
        if (Platform.isAndroid) {
          isRooted = await FlutterJailbreakDetection.jailbroken
              .timeout(const Duration(milliseconds: 1200), onTimeout: () {
            print('⚠️ Root check timeout – assuming not rooted');
            return false;
          });
          print('🔒 Root check: $isRooted');
        } else if (Platform.isIOS) {
          if (kDebugMode) {
            // Debug installs are never App Store builds; skip the slow native
            // probe so splash isn't blocked for ~5s every run.
            print('🔒 Jailbreak check: SKIPPED in debug');
            isJailbroken = false;
          } else {
            isJailbroken = await FlutterJailbreakDetection.jailbroken
                .timeout(const Duration(milliseconds: 1200), onTimeout: () {
              print('⚠️ Jailbreak check timeout – assuming not jailbroken');
              return false;
            });
            print('🔒 Jailbreak check: $isJailbroken');
          }
        }
      } catch (e) {
        print('⚠️ Error checking root/jailbreak: $e');
      }

      // Check VPN on Android and iOS (unless remote/test config skips it).
      if (AppConfigService.instance.shouldSkipVpnCheck) {
        print('🔒 VPN check: SKIPPED (shouldSkipVpnCheck=true)');
      } else {
        try {
          print('🔒 ${Platform.isIOS ? "iOS" : "Android"}: Calling VPN detector...');
          isUsingVpn = await _detectVpnActive();
          print('🔒 VPN check result: $isUsingVpn');
        } catch (e) {
          print('⚠️ Error checking VPN: $e');
          // Don't fail the security check if VPN detection fails
          isUsingVpn = false;
        }
      }

      // Check Mock Location (Android only, iOS doesn't allow mock locations easily)
      try {
        if (Platform.isAndroid) {
          isMockLocation = await SafeDevice.isMockLocation;
          print('🔒 Mock location check: $isMockLocation');
        }
      } catch (e) {
        print('⚠️ Error checking mock location: $e');
      }

      // Note: Emulator check disabled - SafeDevice.isRealDevice is unreliable
      // and gives false positives on some Samsung devices
      // If you need emulator detection, consider using a different approach
      print('🔒 Emulator check: skipped (unreliable)');
    } catch (e) {
      errorMessage = 'Security check error: $e';
      print('❌ Security check error: $e');
    }

    final result = SecurityCheckResult(
      isRooted: isRooted,
      isJailbroken: isJailbroken,
      isUsingVpn: isUsingVpn,
      isMockLocation: isMockLocation,
      isEmulator: isEmulator, // Always false now
      errorMessage: errorMessage,
    );

    print('═══════════════════════════════════════════════════════════');
    print('🔒 SECURITY CHECK RESULT:');
    print('   - Root/Jailbreak: ${isRooted || isJailbroken}');
    print('   - VPN Active: $isUsingVpn');
    print('   - Mock Location: $isMockLocation');
    print('   - Emulator: $isEmulator');
    print('   - Is Secure: ${result.isSecure}');
    print('═══════════════════════════════════════════════════════════');

    return result;
  }

  /// Quick check - returns true if device is secure
  Future<bool> isDeviceSecure() async {
    final result = await performSecurityCheck();
    return result.isSecure;
  }

  static const MethodChannel _vpnChannel =
      MethodChannel('ae.elrace.mobile/vpn_detection');

  /// Native VPN probe (Android: TRANSPORT_VPN, iOS: active __SCOPED__ tunnel).
  /// Configured-but-disconnected VPN profiles are intentionally ignored.
  Future<bool> _detectVpnActive() async {
    try {
      final active = await _vpnChannel.invokeMethod<bool>('isVpnActive');
      return active ?? false;
    } catch (e) {
      print('⚠️ Native VPN channel error: $e');
      return false;
    }
  }

  /// Quick VPN-only check (Android + iOS). Used on app resume.
  /// Returns true when an active VPN should block the app.
  Future<bool> isVpnBlockingActive() async {
    if (AppConfigService.instance.shouldSkipVpnCheck) return false;
    try {
      return await _detectVpnActive().timeout(
        const Duration(milliseconds: 3500),
        onTimeout: () => false,
      );
    } catch (e) {
      print('⚠️ Quick VPN check error: $e');
      return false;
    }
  }

  static bool _securityDialogVisible = false;

  static bool get isSecurityDialogVisible => _securityDialogVisible;

  /// Shows a blocking dialog if the device is not secure
  static Future<void> showSecurityBlockDialog(
    BuildContext context,
    SecurityCheckResult result,
  ) async {
    if (_securityDialogVisible) return;
    if (!context.mounted) return;
    _securityDialogVisible = true;

    final isVpnFocused = result.isVpnOnlyViolation || result.isUsingVpn;
    final title = result.dialogTitle;
    final accent = isVpnFocused ? Colors.deepOrange : Colors.red;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isVpnFocused ? Icons.vpn_lock_rounded : Icons.security,
                  color: accent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.getUserFriendlyMessage(),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isVpnFocused
                              ? (Platform.isIOS
                                  ? 'Turn off VPN in iOS Settings, then tap Retry to continue.'
                                  : 'Turn off VPN on your device, then tap Retry to continue.')
                              : 'To protect your data security, the app cannot be used in this state.',
                          style: TextStyle(
                            color: accent.shade700,
                            fontSize: 13,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final newResult = await DeviceSecurityService.instance
                              .performSecurityCheck();
                          if (!newResult.isSecure && context.mounted) {
                            showSecurityBlockDialog(context, newResult);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          exit(0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _securityDialogVisible = false;
    }
  }

  /// Alternative: Shows a full-screen blocking page
  static Widget buildSecurityBlockScreen(SecurityCheckResult result) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.security,
                  size: 100,
                  color: Colors.red,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Security Warning',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    result.getUserFriendlyMessage(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => exit(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
