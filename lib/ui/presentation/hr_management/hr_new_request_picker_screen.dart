import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/my_request/RequestEffectiveDate.dart';
import 'package:el_race/ui/presentation/my_request/RequestJobMissionPage.dart';
import 'package:el_race/ui/presentation/my_request/RequestLeavePageNew.dart';
import 'package:el_race/ui/presentation/my_request/RequestPermission.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// E2 — New request type picker: single flat grid of all types.
class HrNewRequestPickerScreen extends ConsumerStatefulWidget {
  const HrNewRequestPickerScreen({super.key});

  static const int _crossAxisCount = 3;

  @override
  ConsumerState<HrNewRequestPickerScreen> createState() =>
      _HrNewRequestPickerScreenState();
}

class _HrNewRequestPickerScreenState
    extends ConsumerState<HrNewRequestPickerScreen> {
  bool _loadingEligibility = true;
  bool _eligibleSim = false;
  /// Contract `eligible_car_rent_request` — gates mobile **Car Allowance**
  /// (Odoo `car_rent_request` / Car Allowance type).
  bool _eligibleCarAllowance = false;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    try {
      final env =
          await ref.read(hrApiClientProvider).fetchPickerCapabilities();
      final raw = env.data?['eligibility'];
      Map<String, dynamic>? elig;
      if (raw is Map) {
        elig = Map<String, dynamic>.from(raw);
      }
      if (mounted) {
        setState(() {
          _eligibleSim = elig?['eligible_sim_card_request'] == true;
          _eligibleCarAllowance =
              elig?['eligible_car_rent_request'] == true;
          _loadingEligibility = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingEligibility = false);
      }
    }
  }

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

  List<_RequestTypeSpec> _specs(BuildContext context) {
    final specs = <_RequestTypeSpec>[
      _RequestTypeSpec(
        label: 'Sick',
        icon: Icons.medical_services_outlined,
        iconColor: const Color(0xFF1565C0),
        onTap: () => _openLeave(context, 'SICK'),
      ),
      _RequestTypeSpec(
        label: 'Short',
        icon: Icons.event_note_outlined,
        iconColor: HrModuleColors.secondary,
        onTap: () => _openLeave(context, 'SHORT'),
      ),
      _RequestTypeSpec(
        label: 'Annual',
        icon: Icons.beach_access_outlined,
        iconColor: const Color(0xFF00897B),
        onTap: () => _openLeave(context, 'ANNUAL'),
      ),
      _RequestTypeSpec(
        label: 'Job mission',
        icon: Icons.flight_takeoff_outlined,
        iconColor: const Color(0xFF6A1B9A),
        onTap: () => _openJobMission(context),
      ),
      _RequestTypeSpec(
        label: 'Temp. permission',
        icon: Icons.schedule_outlined,
        iconColor: HrModuleColors.warning,
        onTap: () => _openPermission(context),
      ),
      _RequestTypeSpec(
        label: 'Effective date',
        icon: Icons.edit_calendar_outlined,
        iconColor: HrModuleColors.secondary,
        onTap: () => _openEffectiveDate(context),
      ),
      if (_eligibleCarAllowance)
        _RequestTypeSpec(
          label: 'Car Allowance',
          icon: Icons.local_gas_station_outlined,
          iconColor: const Color(0xFF5D4037),
          onTap: () => Navigator.of(context)
              .pushNamed(HrRouteNames.carAllowanceRequest),
        ),
      if (_eligibleSim)
        _RequestTypeSpec(
          label: 'SIM',
          icon: Icons.sim_card_outlined,
          iconColor: const Color(0xFF0277BD),
          onTap: () =>
              Navigator.of(context).pushNamed(HrRouteNames.simRequest),
        ),
      _RequestTypeSpec(
        label: 'Increment',
        icon: Icons.trending_up_outlined,
        iconColor: const Color(0xFF2E7D32),
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.incrementRequest),
      ),
      _RequestTypeSpec(
        label: 'Promotion',
        icon: Icons.workspace_premium_outlined,
        iconColor: const Color(0xFF6A1B9A),
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.promotionRequest),
      ),
      _RequestTypeSpec(
        label: 'Resignation',
        icon: Icons.logout_outlined,
        iconColor: HrModuleColors.warning,
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.resignationRequest),
      ),
      _RequestTypeSpec(
        label: 'Termination',
        icon: Icons.person_off_outlined,
        iconColor: HrModuleColors.danger,
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.terminationRequest),
      ),
      _RequestTypeSpec(
        label: 'Certificate',
        icon: Icons.badge_outlined,
        iconColor: const Color(0xFF1565C0),
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.certificateRequest),
      ),
      _RequestTypeSpec(
        label: 'Loan',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: const Color(0xFF00897B),
        onTap: () => Navigator.of(context).pushNamed(HrRouteNames.loanRequest),
      ),
      _RequestTypeSpec(
        label: 'Encashment',
        icon: Icons.payments_outlined,
        iconColor: const Color(0xFFEF6C00),
        onTap: () =>
            Navigator.of(context).pushNamed(HrRouteNames.encashmentRequest),
      ),
    ];
    return specs;
  }

  @override
  Widget build(BuildContext context) {
    final pad = HrModuleLayout.screenPaddingH.tw;
    final specs = _specs(context);

    return HrRequestsGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'New request',
            accentTint: HrModuleHeaderTints.requests,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8.th, pad, 8.th),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.tr),
                        decoration: BoxDecoration(
                          color: HrModuleColors.surface,
                          borderRadius: BorderRadius.circular(
                            HrModuleLayout.cardRadius.tr,
                          ),
                          boxShadow: HrModuleColors.cardShadow,
                        ),
                        child: _loadingEligibility
                            ? const Center(child: CircularProgressIndicator())
                            : GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      HrNewRequestPickerScreen._crossAxisCount,
                                  mainAxisSpacing: 10.th,
                                  crossAxisSpacing: 10.tw,
                                  childAspectRatio:
                                      HrModuleLayout.tileAspectRatio,
                                ),
                                itemCount: specs.length,
                                itemBuilder: (context, i) {
                                  final s = specs[i];
                                  return _RequestTypeTile(
                                    label: s.label,
                                    icon: s.icon,
                                    iconColor: s.iconColor,
                                    onTap: s.onTap,
                                  );
                                },
                              ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      SizedBox(height: 4.th),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(HrRouteNames.widgetSandbox);
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
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTypeSpec {
  const _RequestTypeSpec({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
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
            border: Border.all(
              color: HrModuleColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 10.th),
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
