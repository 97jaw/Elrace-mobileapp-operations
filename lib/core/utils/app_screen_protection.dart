import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Scoped screenshot blocking (PDFs / sensitive financial screens only).
abstract final class AppScreenProtection {
  static Future<void> enable() async {
    try {
      await Future.wait<void>([
        ScreenProtector.preventScreenshotOn(),
        ScreenProtector.protectDataLeakageOn(),
      ]);
    } catch (e) {
      debugPrint('Screen protection enable failed: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await Future.wait<void>([
        ScreenProtector.preventScreenshotOff(),
        ScreenProtector.protectDataLeakageOff(),
      ]);
    } catch (e) {
      debugPrint('Screen protection disable failed: $e');
    }
  }
}
