import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/hr_module_manager_access.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hrServerManagerForModule', () {
    test('uses hr_module_manager when present — evaluation-only', () {
      final d = Data(
        hrModuleManager: const HrModuleManagerAccess(
          payslip: false,
          attendance: false,
          hrRequest: true,
          recruitment: true,
          evaluation: true,
        ),
      );
      expect(hrServerManagerForModule(d, HrManagedModule.payslip), false);
      expect(hrServerManagerForModule(d, HrManagedModule.hrRequest), true);
    });

    test('falls back to legacy view when hr_module_manager is null', () {
      final d = Data(isManagement: true);
      expect(hrServerManagerForModule(d, HrManagedModule.payslip), true);
      expect(hrServerManagerForModule(d, HrManagedModule.evaluation), true);
    });

    test('hr_module_manager all false but is_hr_manager still HR Manager tier', () {
      final d = Data(
        isHrManager: true,
        isManagement: true,
        hrModuleManager: const HrModuleManagerAccess(
          payslip: false,
          attendance: false,
          hrRequest: false,
          recruitment: false,
          evaluation: false,
        ),
      );
      expect(hrEffectiveViewFromData(d), HrEffectiveView.hrManager);
    });

    test('hr_module_manager all false overrides is_management for hub view', () {
      final d = Data(
        isManagement: true,
        hrModuleManager: const HrModuleManagerAccess(
          payslip: false,
          attendance: false,
          hrRequest: false,
          recruitment: false,
          evaluation: false,
        ),
      );
      expect(hrEffectiveViewFromData(d), HrEffectiveView.employee);
    });

    test('hr_module_manager with any true yields manager when not is_hr_manager', () {
      final d = Data(
        isManagement: false,
        hrModuleManager: const HrModuleManagerAccess(
          payslip: false,
          attendance: false,
          hrRequest: true,
          recruitment: false,
          evaluation: false,
        ),
      );
      expect(hrEffectiveViewFromData(d), HrEffectiveView.manager);
    });
  });

  group('hrEffectiveViewFromData', () {
    test('null data is employee', () {
      expect(hrEffectiveViewFromData(null), HrEffectiveView.employee);
    });

    test('is_hr_manager wins over management', () {
      final d = Data(isHrManager: true, isManagement: true);
      expect(hrEffectiveViewFromData(d), HrEffectiveView.hrManager);
    });

    test('is_management gives manager', () {
      final d = Data(isManagement: true);
      expect(hrEffectiveViewFromData(d), HrEffectiveView.manager);
    });

    test('is_pm gives manager', () {
      final d = Data(isPm: true);
      expect(hrEffectiveViewFromData(d), HrEffectiveView.manager);
    });

    test('is_fleet alone is employee', () {
      final d = Data(isFleet: true);
      expect(hrEffectiveViewFromData(d), HrEffectiveView.employee);
    });
  });
}
