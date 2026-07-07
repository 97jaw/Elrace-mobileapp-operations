import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// List tile for a request — clean white card; title and badge colored by status.
class HrRequestCard extends StatelessWidget {
  const HrRequestCard({
    super.key,
    required this.requestTypeTitle,
    required this.referenceNumber,
    required this.uiStatus,
    this.statusLabelOverride,
    this.statusBadgeKind = HrBadgeKind.request,
    this.secondaryLine,
    this.onTap,
    this.showEmployeeHeader = false,
    this.employeeName,
    this.employeeRoleLine,
    this.employeeId,
  });

  final String requestTypeTitle;
  final String referenceNumber;
  final String uiStatus;
  final String? statusLabelOverride;
  final HrBadgeKind statusBadgeKind;
  final String? secondaryLine;
  final VoidCallback? onTap;

  final bool showEmployeeHeader;
  final String? employeeName;
  final String? employeeRoleLine;
  final String? employeeId;

  static Color statusAccent(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'PENDING':
        return HrModuleColors.warning;
      case 'APPROVED':
        return HrModuleColors.success;
      case 'REJECTED':
        return HrModuleColors.danger;
      case 'DRAFT':
        return HrModuleColors.secondary;
      default:
        return HrModuleColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = statusAccent(uiStatus);
    final radius = HrModuleLayout.cardRadius.r;
    final body = Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEmployeeHeader && employeeName != null) ...[
            _TeamEmployeeHeader(
              name: employeeName!,
              roleLine: employeeRoleLine ?? '',
              employeeId: employeeId ?? '',
            ),
            Divider(height: 20.h, color: HrModuleColors.border.withValues(alpha: 0.6)),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestTypeTitle,
                      style: HrModuleTypography.cardTitle().copyWith(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                            color: accent,
                          ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      referenceNumber,
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: HrModuleColors.mutedText,
                          ),
                    ),
                    if (secondaryLine != null && secondaryLine!.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        secondaryLine!,
                        style: HrModuleTypography.body().copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: HrModuleColors.text.withValues(alpha: 0.75),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              HrStatusBadge(
                uiStatus: uiStatus,
                kind: statusBadgeKind,
                solid: true,
                labelOverride: statusLabelOverride,
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

class _TeamEmployeeHeader extends StatelessWidget {
  const _TeamEmployeeHeader({
    required this.name,
    required this.roleLine,
    required this.employeeId,
  });

  final String name;
  final String roleLine;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final initials = HrEmployeeInfoCard.initialsFromName(name);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: HrModuleColors.primary.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: HrModuleTypography.caption().copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: HrModuleColors.primary,
                ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: HrModuleTypography.cardTitle().copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
              ),
              if (roleLine.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  roleLine,
                  style: HrModuleTypography.caption().copyWith(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              if (employeeId.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  employeeId,
                  style: HrModuleTypography.body().copyWith(
                        fontSize: 12.sp,
                        color: HrModuleColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
