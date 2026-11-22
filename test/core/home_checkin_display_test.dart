import 'package:el_race/core/attendance/home_checkin_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeCheckInDisplay', () {
    test('checked-in subtitle is elapsed since check-in, not 8h remaining', () {
      final checkInAt = DateTime(2026, 11, 22, 8, 26);
      final now = DateTime(2026, 11, 22, 14, 33);

      final display = HomeCheckInDisplay.resolve(
        isCheckedIn: true,
        checkInAt: checkInAt,
        checkOutDisplayTime: '00:00:00',
        now: now,
      );

      expect(display.checkedIn, isTrue);
      expect(display.status, 'Checked in');
      expect(display.time, '08:26');
      // 14:33 - 08:26 = 6h 07m (previously wrongly showed remaining 01:53)
      expect(display.sub, 'In 06:07');
    });

    test('absent / empty clocks render as dash', () {
      final display = HomeCheckInDisplay.resolve(
        isCheckedIn: false,
        checkInAt: null,
        checkOutDisplayTime: '-',
        now: DateTime(2026, 11, 22, 14, 30),
      );

      expect(display.checkedIn, isFalse);
      expect(display.time, '-');
      expect(display.sub, 'In -');
    });

    test('checked-out shows Out clock', () {
      final display = HomeCheckInDisplay.resolve(
        isCheckedIn: false,
        checkInAt: DateTime(2026, 11, 22, 8, 26),
        checkOutDisplayTime: '17:05:00',
        now: DateTime(2026, 11, 22, 18, 0),
      );

      expect(display.checkedIn, isFalse);
      expect(display.status, 'Checked out');
      expect(display.time, '08:26');
      expect(display.sub, 'Out 17:05');
    });

    test('isBlankClock treats API dash and placeholders as blank', () {
      expect(HomeCheckInDisplay.isBlankClock('-'), isTrue);
      expect(HomeCheckInDisplay.isBlankClock('--:--'), isTrue);
      expect(HomeCheckInDisplay.isBlankClock('00:00:00'), isTrue);
      expect(HomeCheckInDisplay.isBlankClock('08:26'), isFalse);
    });
  });
}
