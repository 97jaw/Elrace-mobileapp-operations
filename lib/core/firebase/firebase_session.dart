import 'dart:async';

import 'package:el_race/chat/services/firebase_chat_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Single entry point for Firebase Auth across the whole app.
///
/// Firebase sign-in used to be owned by the chat module, so every other
/// feature (Notes, Todos, Tickets, Signatures, Tasks) kept its own copy that
/// replayed the one-time custom token from login and never refreshed it. Those
/// copies started failing roughly an hour after login. Everything now goes
/// through here, which delegates to [FirebaseChatAuthService] — the only
/// implementation that refreshes via `POST /api/firebase/refresh_token`.
class FirebaseSession {
  FirebaseSession._();

  static final FirebaseSession instance = FirebaseSession._();

  /// Post-login Firebase bootstrap, registered by `PostLoginSetup`. Callers
  /// await it instead of racing it on the first screen after sign-in.
  Future<void>? _bootstrap;

  /// Coalesces concurrent sign-in attempts so a burst of widgets loading at
  /// once triggers a single token refresh.
  Future<User>? _inFlight;

  static const Duration _bootstrapTimeout = Duration(seconds: 8);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Registered by the login flow so [ensureSignedIn] can wait for the
  /// in-progress bootstrap rather than starting a competing sign-in.
  void trackBootstrap(Future<void> bootstrap) {
    _bootstrap = bootstrap;
  }

  /// Ensures Firebase Auth has a usable ID token, refreshing or re-signing
  /// from the backend when needed. Throws if the user cannot be signed in.
  Future<User> ensureSignedIn() {
    return _inFlight ??= _ensureSignedIn().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<User> _ensureSignedIn() async {
    await _awaitBootstrap();
    return FirebaseChatAuthService.instance.ensureAuthenticated();
  }

  /// Non-throwing variant for background work that should degrade quietly.
  Future<User?> ensureSignedInOrNull() async {
    try {
      return await ensureSignedIn();
    } catch (e) {
      debugPrint('⚠️ FirebaseSession: sign-in unavailable: $e');
      return null;
    }
  }

  /// Runs [action] with a guaranteed Firebase session. On an auth denial the
  /// session is rebuilt from a fresh custom token and [action] is retried once.
  ///
  /// [action] must be safe to run twice.
  Future<T> run<T>(Future<T> Function() action) async {
    await ensureSignedIn();
    try {
      return await action();
    } catch (error) {
      if (!isAuthDenied(error)) rethrow;
      debugPrint('⚠️ FirebaseSession: auth denied, refreshing and retrying…');
      await forceRefresh();
      // Brief yield so the Auth, Firestore and Storage clients pick up the
      // new ID token before the retry.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return await action();
    }
  }

  /// Drops the current Firebase session and signs in again with a token freshly
  /// minted by the backend. Used when a valid-looking ID token is being
  /// rejected, which the local SDK cannot detect on its own.
  Future<User> forceRefresh() async {
    _inFlight = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Already signed out — the sign-in below is what matters.
    }
    return ensureSignedIn();
  }

  /// Re-establishes auth when the app comes back to the foreground. Never
  /// throws: resume work is best-effort and must not block the UI.
  Future<void> refreshOnResume() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await ensureSignedInOrNull();
      return;
    }
    try {
      await user.getIdToken(true);
    } catch (e) {
      debugPrint('⚠️ FirebaseSession: resume token refresh failed: $e');
      await ensureSignedInOrNull();
    }
  }

  /// True when [error] means "Firebase rejected this caller's credentials",
  /// as opposed to a genuine rule violation we cannot retry our way out of.
  ///
  /// Covers Firestore, Storage, Functions and Auth, which all surface as
  /// [FirebaseException] subclasses with their own code vocabularies.
  static bool isAuthDenied(Object error) {
    if (error is FirebaseAuthException) {
      return error.code == 'invalid-custom-token' ||
          error.code == 'custom-token-expired' ||
          error.code == 'user-token-expired';
    }
    if (error is FirebaseException) {
      return error.code == 'unauthenticated' ||
          error.code == 'permission-denied' ||
          error.code == 'unauthorized';
    }
    return false;
  }

  Future<void> _awaitBootstrap() async {
    final pending = _bootstrap;
    if (pending == null) return;
    // Only worth waiting for when there is no session at all. Skipping the
    // wait once signed in also keeps calls made *during* the bootstrap (chat
    // setup writes to Firestore) from waiting on the future they are part of.
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await pending.timeout(_bootstrapTimeout);
    } catch (e) {
      // A failed or slow bootstrap is recoverable: ensureAuthenticated() below
      // fetches a fresh custom token on its own.
      debugPrint('⚠️ FirebaseSession: bootstrap did not complete: $e');
    } finally {
      if (identical(_bootstrap, pending)) _bootstrap = null;
    }
  }
}
