import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Employee header block for team views (SRD §4.3 / component inventory).
///
/// ```dart
/// HrEmployeeInfoCard(
///   name: 'Jane Doe',
///   positionDepartmentLine: 'Engineer · R&D',
///   employeeId: 'EMP-1024',
///   email: 'jane@example.com',
///   phone: '+971 50 000 0000',
/// )
/// ```
class HrEmployeeInfoCard extends StatelessWidget {
  const HrEmployeeInfoCard({
    super.key,
    required this.name,
    required this.positionDepartmentLine,
    required this.employeeId,
    this.email,
    this.phone,
    this.initialsOverride,
  });

  final String name;
  final String positionDepartmentLine;
  final String employeeId;
  final String? email;
  final String? phone;
  final String? initialsOverride;

  static String initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      return list.first.length >= 2
          ? list.first.substring(0, 2).toUpperCase()
          : list.first.toUpperCase();
    }
    return ('${list.first[0]}${list[1][0]}').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsOverride ?? initialsFromName(name);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        border: Border.all(color: HrModuleColors.border),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: HrModuleColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: HrModuleTypography.cardTitle().copyWith(
                    fontSize: 16.sp,
                    color: HrModuleColors.primary,
                  ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: HrModuleTypography.cardTitle().copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  positionDepartmentLine,
                  style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                ),
                SizedBox(height: 6.h),
                Text(
                  employeeId,
                  style: HrModuleTypography.body().copyWith(
                        fontSize: 13.sp,
                        color: HrModuleColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (email != null && email!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _contactRow(icon: Icons.email_outlined, text: email!),
                ],
                if (phone != null && phone!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  _contactRow(icon: Icons.phone_outlined, text: phone!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: HrModuleColors.mutedText),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
          ),
        ),
      ],
    );
  }
}
