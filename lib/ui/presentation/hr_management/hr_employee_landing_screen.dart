import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/hr_management/hr_new_request_picker_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_personal_request_list_content.dart';
import 'package:el_race/core/hr_management/hr_request_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// E1 — Employee HR landing (SRD §3.1).
class HrEmployeeLandingScreen extends ConsumerWidget {
  const HrEmployeeLandingScreen({super.key});

  void _openDetail(BuildContext context, HrRequestSummary e) {
    openHrRequestDetail(context, e, managerContext: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HrRequestsGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'HR Requests',
            accentTint: HrModuleHeaderTints.requests,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: HrPersonalRequestListContent(
                onOpenDetail: (e) => _openDetail(context, e),
                bottomInset: 100,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const HrNewRequestPickerScreen(),
            ),
          );
        },
        backgroundColor: HrModuleColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New request',
          style: HrModuleTypography.button().copyWith(
                fontSize: 14.tsp,
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}
