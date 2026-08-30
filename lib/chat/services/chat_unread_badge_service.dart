import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/chat_repository.dart';

/// Single shared unread-total source for home chat icon + bottom nav badges.
class ChatUnreadBadgeService {
  ChatUnreadBadgeService._();
  static final ChatUnreadBadgeService instance = ChatUnreadBadgeService._();

  final ValueNotifier<int> count = ValueNotifier<int>(0);

  StreamSubscription<int>? _unreadSub;
  StreamSubscription<User?>? _authSub;
  Timer? _retryTimer;

  /// Start (or retry) the Firebase unread subscription. Safe to call often.
  void ensureListening() {
    if (_trySubscribe()) return;
    _attachRetries();
  }

  void _attachRetries() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _unreadSub == null) {
        if (_trySubscribe()) _cancelRetries();
      }
    });
    _retryTimer ??= Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_trySubscribe()) {
        _cancelRetries();
      }
      if (timer.tick >= 60) {
        _cancelRetries();
      }
    });
  }

  bool _trySubscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _unreadSub?.cancel();
    _unreadSub = ChatRepository.instance.subscribeToTotalUnreadCount().listen(
      (value) {
        if (count.value != value) {
          count.value = value;
        }
      },
      onError: (e) {
        debugPrint('⚠️ ChatUnreadBadgeService: unread stream error: $e');
      },
    );
    return true;
  }

  void _cancelRetries() {
    _authSub?.cancel();
    _authSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Stop listening and clear badge (logout).
  Future<void> stop() async {
    _unreadSub?.cancel();
    _unreadSub = null;
    _cancelRetries();
    count.value = 0;
  }
}
