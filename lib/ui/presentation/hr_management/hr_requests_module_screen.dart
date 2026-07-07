import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/ui/presentation/hr_management/hr_employee_landing_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_manager_landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Module 1 — HR Requests & approvals (E1 / M1). Opened from [HrManagementHubScreen].
class HrRequestsModuleScreen extends ConsumerWidget {
  const HrRequestsModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hrEffectiveViewProvider);
    if (view == HrEffectiveView.employee) {
      return const HrEmployeeLandingScreen();
    }
    return const HrManagerLandingScreen();
  }
}
