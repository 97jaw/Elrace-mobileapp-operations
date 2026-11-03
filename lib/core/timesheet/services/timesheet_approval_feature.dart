import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads `config/features.timesheet_approval` once per successful load.
///
/// Missing doc/field or any error → false (feature stays off). Errors are not
/// cached so a later call (after sign-in / resume) can succeed.
///
/// Use [instance] everywhere (badge, provider) so resume / sign-in refresh
/// clears one shared cache instead of spawning a new reader each time.
class TimesheetApprovalFeature {
  TimesheetApprovalFeature({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Process-wide shared reader (same cache the Riverpod provider uses).
  static final TimesheetApprovalFeature instance = TimesheetApprovalFeature();

  final FirebaseFirestore _firestore;
  bool? _cached;
  Future<bool>? _inFlight;

  Future<bool> isEnabled({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) {
      return Future.value(_cached);
    }
    if (forceRefresh) {
      _cached = null;
      _inFlight = null;
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
  (ref) => TimesheetApprovalFeature.instance,
);

/// Cached bool; invalidate (resume / sign-in) to force a fresh Firestore read.
final timesheetApprovalEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(timesheetApprovalFeatureProvider).isEnabled();
});

/// Clears the feature cache and invalidates the provider so watchers reload.
void refreshTimesheetApprovalFlag(ProviderContainer container) {
  try {
    container.read(timesheetApprovalFeatureProvider).clearCache();
  } catch (_) {}
  container.invalidate(timesheetApprovalEnabledProvider);
}
