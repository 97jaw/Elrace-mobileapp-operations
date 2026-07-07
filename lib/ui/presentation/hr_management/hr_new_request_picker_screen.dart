import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/my_request/RequestEffectiveDate.dart';
import 'package:el_race/ui/presentation/my_request/RequestJobMissionPage.dart';
import 'package:el_race/ui/presentation/my_request/RequestLeavePageNew.dart';
import 'package:el_race/ui/presentation/my_request/RequestPermission.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// E2 — New request type picker (SRD §3.2): frequent grid + “More” groups.
class HrNewRequestPickerScreen extends StatelessWidget {
  const HrNewRequestPickerScreen({super.key});

  void _openLeave(BuildContext context, String leaveType) {
    final login = SharedPref.getLoginData();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RequestLeavePageNew(
          loginResponseModel: login,
          leaveType: leaveType,
        ),
      ),
    );
  }

  void _openJobMission(BuildContext context) {
    final login = SharedPref.getLoginData();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RequestJobMissionPage(loginResponseModel: login),
      ),
    );
  }

  void _openPermission(BuildContext context) {
    final login = SharedPref.getLoginData();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RequestPermission(loginResponseModel: login),
      ),
    );
  }

  void _openEffectiveDate(BuildContext context) {
    final login = SharedPref.getLoginData();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EffectiveDatePage(loginResponseModel: login),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = HrModuleLayout.screenPaddingH.w;

    return HrRequestsGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'New request',
          style: HrModuleTypography.pageTitle().copyWith(fontSize: 20.sp),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 8.h, pad, 32.h),
          children: [
            _SectionCard(
              title: 'Frequent',
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: HrModuleLayout.tileAspectRatio,
                children: [
                  _RequestTypeTile(
                    label: 'Sick',
                    icon: Icons.medical_services_outlined,
                    iconColor: const Color(0xFF1565C0),
                    onTap: () => _openLeave(context, 'SICK'),
                  ),
                  _RequestTypeTile(
                    label: 'Short',
                    icon: Icons.event_note_outlined,
                    iconColor: HrModuleColors.secondary,
                    onTap: () => _openLeave(context, 'SHORT'),
                  ),
                  _RequestTypeTile(
                    label: 'Annual',
                    icon: Icons.beach_access_outlined,
                    iconColor: const Color(0xFF00897B),
                    onTap: () => _openLeave(context, 'ANNUAL'),
                  ),
                  _RequestTypeTile(
                    label: 'Job mission',
                    icon: Icons.flight_takeoff_outlined,
                    iconColor: const Color(0xFF6A1B9A),
                    onTap: () => _openJobMission(context),
                  ),
                  _RequestTypeTile(
                    label: 'Temp. permission',
                    icon: Icons.schedule_outlined,
                    iconColor: HrModuleColors.warning,
                    onTap: () => _openPermission(context),
                  ),
                  _RequestTypeTile(
                    label: 'Effective date',
                    icon: Icons.edit_calendar_outlined,
                    iconColor: HrModuleColors.secondary,
                    onTap: () => _openEffectiveDate(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'More request types',
                  style: HrModuleTypography.sectionHeading()
                      .copyWith(fontSize: 16.sp),
                ),
                children: [
                  _SectionCard(
                    title: 'Asset',
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 12.w,
                      childAspectRatio: HrModuleLayout.tileAspectRatio,
                      children: [
                        _RequestTypeTile(
                          label: 'Car rent',
                          icon: Icons.directions_car_outlined,
                          iconColor: HrModuleColors.secondary,
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.carRentRequest),
                        ),
                        _RequestTypeTile(
                          label: 'SIM',
                          icon: Icons.sim_card_outlined,
                          iconColor: HrModuleColors.primary,
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.simRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Car allowance',
                          icon: Icons.local_gas_station_outlined,
                          iconColor: const Color(0xFF5D4037),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.carAllowanceRequest),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(HrRouteNames.widgetSandbox);
                },
                child: Text(
                  'F.2 widget sandbox',
                  style: HrModuleTypography.body().copyWith(
                    fontSize: 13.sp,
                    color: HrModuleColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _RequestTypeTile extends StatelessWidget {
  const _RequestTypeTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HrModuleColors.lightBg,
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius),
            border: Border.all(color: HrModuleColors.border.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28.sp, color: iconColor),
                SizedBox(height: 8.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 11.sp,
                    color: HrModuleColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
