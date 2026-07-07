import 'package:el_race/core/hr_management/hr_effective_view.dart';

/// SRD §3.3.1 / §7.5 — salary on requisitions.
bool recruitmentShowsRequisitionSalary({
  required HrEffectiveView view,
  required String raisedBy,
  String? currentUserDisplayName,
}) {
  if (view == HrEffectiveView.hrManager) return true;
  if (view == HrEffectiveView.manager) {
    if (currentUserDisplayName == null || currentUserDisplayName.isEmpty) {
      return false;
    }
    return raisedBy.toLowerCase().trim() ==
        currentUserDisplayName.toLowerCase().trim();
  }
  return false;
}

/// Offer compensation — hiring managers and HR can view (per product).
bool recruitmentShowsOfferCompensation({required HrEffectiveView view}) {
  return view == HrEffectiveView.hrManager ||
      view == HrEffectiveView.manager;
}
