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

  /// Which rules file area rejected the call. Used to group Crashlytics.
  String get ruleArea => FirebaseFailure.ruleAreaFor(path);

  String get detail =>
      'step=$step path=$path uid=$uid ruleArea=$ruleArea tokenRefreshed=$tokenRefreshed';

  /// Map a Firestore, Storage, or Realtime Database path to a rules area.
  static String ruleAreaFor(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('signature_document') ||
        normalized.contains('signature_docs')) {
      return 'signature_documents';
    }
    if (normalized.contains('userchats')) return 'userChats';
    if (normalized.contains('/notes') || normalized.endsWith('/notes')) {
      return 'notes';
    }
    if (normalized.contains('/members/') || normalized.endsWith('/members')) {
      return 'members';
    }
    if (normalized.contains('/messages') || normalized.endsWith('/messages')) {
      return 'messages';
    }
    if (normalized.contains('typing')) return 'rtdb_typing';
    if (normalized.contains('presence')) return 'rtdb_presence';
    if (normalized.startsWith('chats/') || normalized.contains('/chats/')) {
      return 'chats';
    }
    return 'other';
  }

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
      crashlytics.setCustomKey('firebase_step', step);
      crashlytics.setCustomKey('firebase_path', path);
      crashlytics.setCustomKey('firebase_uid', uid);
      crashlytics.setCustomKey('firebase_rule_area', ruleArea);
      crashlytics.setCustomKey(
        'firebase_token_refreshed',
        tokenRefreshed.toString(),
      );
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
