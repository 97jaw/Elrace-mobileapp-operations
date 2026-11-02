import 'package:el_race/core/hr_management/special_leave_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpecialLeaveRules', () {
    test('bereavement duration follows the relative', () {
      expect(
        SpecialLeaveRules.durationFor(
          kind: SpecialLeaveKind.death,
          relative: 'first',
        ),
        5,
      );
      expect(
        SpecialLeaveRules.durationFor(
          kind: SpecialLeaveKind.death,
          relative: 'second',
        ),
        3,
      );
      expect(
        SpecialLeaveRules.durationFor(kind: SpecialLeaveKind.death),
        isNull,
      );
    });

    test('end date is start plus duration minus one day', () {
      final end = SpecialLeaveRules.endDate(DateTime(2026, 11, 1), 5);
      expect(end, DateTime(2026, 11, 5));
    });

    test('a missing start date is rejected', () {
      expect(
        SpecialLeaveRules.validate(
          kind: SpecialLeaveKind.parental,
          start: null,
          duration: 2,
          hasAttachment: true,
        ),
        'Start date is required.',
      );
    });

    test('maternity and death require their attachments', () {
      expect(
        SpecialLeaveRules.validate(
          kind: SpecialLeaveKind.maternity,
          start: DateTime(2026, 11, 1),
          duration: 45,
          hasAttachment: false,
        ),
        'Discharge report is required.',
      );
      expect(
        SpecialLeaveRules.validate(
          kind: SpecialLeaveKind.death,
          start: DateTime(2026, 11, 1),
          duration: 5,
          relative: 'first',
          hasAttachment: false,
        ),
        'Death certificate is required.',
      );
      expect(
        SpecialLeaveRules.validate(
          kind: SpecialLeaveKind.parental,
          start: DateTime(2026, 11, 1),
          duration: 5,
          hasAttachment: true,
        ),
        isNull,
      );
    });
  });
}
