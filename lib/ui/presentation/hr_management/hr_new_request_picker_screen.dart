import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
    final pad = HrModuleLayout.screenPaddingH.tw;

    return HrRequestsGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'New request',
          style: HrModuleTypography.pageTitle().copyWith(fontSize: 20.tsp),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 8.th, pad, 32.th),
          children: [
            _SectionCard(
              title: 'Frequent',
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12.th,
                crossAxisSpacing: 12.tw,
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
            SizedBox(height: 12.th),
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
                      .copyWith(fontSize: 16.tsp),
                ),
                children: [
                  _SectionCard(
                    title: 'Employment & pay',
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12.th,
                      crossAxisSpacing: 12.tw,
                      childAspectRatio: HrModuleLayout.tileAspectRatio,
                      children: [
                        _RequestTypeTile(
                          label: 'Car allowance',
                          icon: Icons.local_gas_station_outlined,
                          iconColor: const Color(0xFF5D4037),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.carAllowanceRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Increment',
                          icon: Icons.trending_up_outlined,
                          iconColor: const Color(0xFF2E7D32),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.incrementRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Promotion',
                          icon: Icons.workspace_premium_outlined,
                          iconColor: const Color(0xFF6A1B9A),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.promotionRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Resignation',
                          icon: Icons.logout_outlined,
                          iconColor: HrModuleColors.warning,
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.resignationRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Termination',
                          icon: Icons.person_off_outlined,
                          iconColor: HrModuleColors.danger,
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.terminationRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Certificate',
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF1565C0),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.certificateRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Loan',
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF00897B),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.loanRequest),
                        ),
                        _RequestTypeTile(
                          label: 'Encashment',
                          icon: Icons.payments_outlined,
                          iconColor: const Color(0xFFEF6C00),
                          onTap: () => Navigator.of(context)
                              .pushNamed(HrRouteNames.encashmentRequest),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              SizedBox(height: 16.th),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(HrRouteNames.widgetSandbox);
                },
                child: Text(
                  'F.2 widget sandbox',
                  style: HrModuleTypography.body().copyWith(
                    fontSize: 13.tsp,
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
      padding: EdgeInsets.all(14.tr),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.tsp),
          ),
          SizedBox(height: 12.th),
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
            padding: EdgeInsets.symmetric(horizontal: 6.tw, vertical: 10.th),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28.tsp, color: iconColor),
                SizedBox(height: 8.th),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 11.tsp,
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
