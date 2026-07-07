import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_status_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pill badge for normalized API `ui_status` (SRD §6.4).
///
/// ```dart
/// HrStatusBadge(uiStatus: 'PENDING')
/// HrStatusBadge(uiStatus: 'IN_RECRUITMENT', kind: HrBadgeKind.requisition)
/// ```
class HrStatusBadge extends StatelessWidget {
  const HrStatusBadge({
    super.key,
    required this.uiStatus,
    this.kind = HrBadgeKind.request,
    this.solid = false,
    this.labelOverride,
  });

  final String uiStatus;
  final HrBadgeKind kind;

  /// Solid fill + white label (HR request list on white cards).
  final bool solid;

  /// Human label from API (e.g. "HR officer approval").
  final String? labelOverride;

  String get _label {
    if (labelOverride != null && labelOverride!.trim().isNotEmpty) {
      return labelOverride!;
    }
    final upper = uiStatus.toUpperCase();
    if (kind == HrBadgeKind.request) return upper;
    return upper.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final bg = solid
        ? HrModuleStatusColors.solidBackgroundForKind(uiStatus, kind)
        : HrModuleStatusColors.backgroundForKind(uiStatus, kind);
    final fg = solid
        ? Colors.white
        : HrModuleStatusColors.textColorForKind(uiStatus, kind);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: HrModuleTypography.statusBadge(color: fg).copyWith(
              fontSize: 11.sp,
            ),
      ),
    );
  }
}
