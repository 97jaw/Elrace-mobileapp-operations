import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads `config/features.timesheet_approval` once per app session.
///
/// Missing doc/field or any error → false (feature stays off).
class TimesheetApprovalFeature {
  TimesheetApprovalFeature({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  bool? _cached;
  Future<bool>? _inFlight;

  Future<bool> isEnabled({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) {
      return Future.value(_cached);
    }
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<bool> _load() async {
    try {
      final snap = await _firestore.collection('config').doc('features').get();
      final enabled = snap.data()?['timesheet_approval'] == true;
      _cached = enabled;
      return enabled;
    } catch (e) {
      // Do not cache errors (e.g. read before Firebase sign-in) so the next
      // call can succeed once auth is ready.
      debugPrint('TimesheetApprovalFeature: $e');
      return false;
    }
  }

  void clearCache() {
    _cached = null;
    _inFlight = null;
  }
}

final timesheetApprovalFeatureProvider = Provider<TimesheetApprovalFeature>(
  (ref) => TimesheetApprovalFeature(),
);

/// Session-cached bool; false when the flag is missing or unreadable.
final timesheetApprovalEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(timesheetApprovalFeatureProvider).isEnabled();
});
