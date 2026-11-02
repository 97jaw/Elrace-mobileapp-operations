import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_session.dart';

/// User-visible Firebase failure. The message carries the step, path, auth
/// uid and whether the ID token was refreshed. No other personal data.
class FirebaseFailure implements Exception {
  FirebaseFailure({
    required this.step,
    required this.path,
    required this.tokenRefreshed,
    required this.cause,
  }) : uid = FirebaseAuth.instance.currentUser?.uid ?? '' {
    _record();
  }

  final String step;
  final String path;
  final String uid;
  final bool tokenRefreshed;
  final Object cause;

  String get detail =>
      'step=$step path=$path uid=$uid tokenRefreshed=$tokenRefreshed';

  @override
  String toString() => 'Firebase failure $detail';

  void _record() {
    final code = cause is FirebaseException
        ? (cause as FirebaseException).code
        : cause.runtimeType.toString();
    final line = '$detail code=$code';
    debugPrint('Firebase failure $line');
    developer.log(line, name: 'Firebase');
    _sendCrashlytics(line);
  }

  void _sendCrashlytics(String line) {
    try {
      if (Firebase.apps.isEmpty) return;
      final crashlytics = FirebaseCrashlytics.instance;
      if (!crashlytics.isCrashlyticsCollectionEnabled) return;
      crashlytics.log(line);
      crashlytics.recordError(
        cause,
        StackTrace.current,
        reason: line,
        fatal: false,
      );
    } catch (_) {
      // Crashlytics is a dependency but is not initialized in this app.
    }
  }

  /// Log once and return the sentence shown to the user.
  static String surface({
    required String fallback,
    required Object error,
    required String step,
    required String path,
  }) {
    if (error is FirebaseFailure) return '$fallback (${error.detail})';
    final failure = FirebaseFailure(
      step: step,
      path: path,
      tokenRefreshed: FirebaseSession.instance.lastTokenRefreshed,
      cause: error,
    );
    return '$fallback (${failure.detail})';
  }
}
