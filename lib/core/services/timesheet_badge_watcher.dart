import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/notifications/app_notifications_repository.dart';
import 'package:el_race/core/services/app_icon_badge_service.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/badge_refresh_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/core/timesheet/services/timesheet_approval_feature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Live Sign Document pending count + Firestore result unread for home badges.
///
/// Started once at app bootstrap; restarts on auth / flag refresh.
class TimesheetBadgeWatcher {
  TimesheetBadgeWatcher._();

  static final TimesheetBadgeWatcher instance = TimesheetBadgeWatcher._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<int>? _sdSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  bool _started = false;
  int _restartGen = 0;

  /// Idempotent — safe to call from bootstrap and after login.
  void start() {
    if (_started) {
      unawaited(restart());
      return;
    }
    _started = true;
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(restart());
    });
    // Keep the auth subscription strongly referenced for the app lifetime.
    assert(_authSub != null);
    unawaited(restart());
  }

  /// Re-read the flag and (re)subscribe. Called after resume / sign-in flag refresh.
  Future<void> restart() async {
    final gen = ++_restartGen;
    await _cancelDataSubs();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      ApprovalCountService.clearSignDocumentPart();
      AppNotificationsRepository.instance.clearLiveUnread();
      await _publishBellBadge();
      return;
    }

    bool flagOn = false;
    try {
      flagOn = await TimesheetApprovalFeature.instance.isEnabled();
    } catch (e) {
      debugPrint('TimesheetBadgeWatcher flag: $e');
    }
    if (gen != _restartGen) return;

    if (!flagOn) {
      ApprovalCountService.clearSignDocumentPart();
      AppNotificationsRepository.instance.clearLiveUnread();
      await _publishBellBadge();
      BadgeRefreshService.notifyListeners();
      return;
    }

    final uid = user.uid;
    _sdSub = TimesheetApprovalRepository.instance
        .watchPendingCountFor(uid)
        .listen(
      (pendingCount) {
        ApprovalCountService.updateSignDocumentCount(pendingCount);
        BadgeRefreshService.notifyListeners();
      },
      onError: (e) {
        debugPrint('TimesheetBadgeWatcher SD stream: $e');
        ApprovalCountService.updateSignDocumentCount(0);
        BadgeRefreshService.notifyListeners();
      },
    );

    _notifSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('app_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snap) async {
        AppNotificationsRepository.instance.setLiveUnreadCount(snap.size);
        await _publishBellBadge();
        BadgeRefreshService.notifyListeners();
      },
      onError: (e) async {
        debugPrint('TimesheetBadgeWatcher notif stream: $e');
        AppNotificationsRepository.instance.clearLiveUnread();
        await _publishBellBadge();
        BadgeRefreshService.notifyListeners();
      },
    );
  }

  Future<void> _cancelDataSubs() async {
    await _sdSub?.cancel();
    _sdSub = null;
    await _notifSub?.cancel();
    _notifSub = null;
  }

  Future<void> _publishBellBadge() async {
    try {
      final local = await NotificationStorageService.getLocalStoredCount();
      final total =
          await AppNotificationsRepository.instance.addUnreadTo(local);
      await AppIconBadgeService.setCount(total, force: true);
    } catch (e) {
      debugPrint('TimesheetBadgeWatcher bell badge: $e');
    }
  }
}
