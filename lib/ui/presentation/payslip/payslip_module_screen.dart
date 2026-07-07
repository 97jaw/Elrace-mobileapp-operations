import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/ui/presentation/payslip/employee_payslip_module_screen.dart';
import 'package:el_race/ui/presentation/payslip/hr_payslip_module_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Module 4 entry — employees: own payslips; HR supervisor: all employees.
/// Line managers / PMs stay on employee view (SRD §2).
class PayslipModuleScreen extends ConsumerWidget {
  const PayslipModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hrAccess = ref.watch(payslipHrAccessProvider);
    if (hrAccess) {
      return const HrPayslipModuleScreen();
    }
    return const EmployeePayslipModuleScreen();
  }
}
