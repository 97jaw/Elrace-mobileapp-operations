import 'package:el_race/core/services/attendance_server_time.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceServerTime', () {
    test('parses Odoo yyyy-MM-dd HH:mm stamps', () {
      final parsed = AttendanceServerTime.tryParse('2026-11-04 08:30');
      expect(parsed, isNotNull);
      expect(parsed!.hour, 8);
      expect(parsed.minute, 30);
      expect(AttendanceServerTime.formatDisplay(parsed), '08:30:00');
    });

    test('falls back when server time is missing', () {
      final display = AttendanceServerTime.displayOrLocalFallback(null);
      expect(display.split(':'), hasLength(3));
    });
  });

  group('CheckinContextModel.locationRequired', () {
    test('missing key defaults to true', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'biotime_offices': const [],
        'biotime_terminals': const [],
        'thresholds': {'default_radius_m': 100},
      });
      expect(model.locationRequired, isTrue);
    });

    test('explicit false is respected', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'location_required': false,
        'biotime_offices': const [],
        'biotime_terminals': const [],
      });
      expect(model.locationRequired, isFalse);
    });
  });

  group('CheckinContextModel.requireLinkedLocation', () {
    test('missing key defaults to false', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'location_required': false,
        'biotime_offices': const [],
        'biotime_terminals': const [],
      });
      expect(model.requireLinkedLocation, isFalse);
    });

    test('explicit true is respected', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'location_required': false,
        'require_linked_location': true,
        'biotime_offices': const [],
        'biotime_terminals': const [],
      });
      expect(model.requireLinkedLocation, isTrue);
    });

    test('explicit false is respected', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'location_required': false,
        'require_linked_location': false,
        'biotime_offices': const [],
        'biotime_terminals': const [],
      });
      expect(model.requireLinkedLocation, isFalse);
    });
  });

  group('CheckinTodayStatus.checkout_mode', () {
    test('parses mode and message', () {
      final today = CheckinTodayStatus.fromJson({
        'checked_in': true,
        'checked_out': false,
        'can_check_out': false,
        'checkout_mode': 'blocked',
        'checkout_message': 'Apply for Temporary Permission',
        'check_in_time': '08:00:00',
        'check_out_time': null,
        'check_in_record_id': 9,
        'is_today': true,
      });
      expect(today.checkoutMode, CheckinCheckoutMode.blocked);
      expect(today.checkoutMessage, 'Apply for Temporary Permission');
      expect(today.canCheckOut, isFalse);
    });

    test('not_required mode', () {
      final today = CheckinTodayStatus.fromJson({
        'checked_in': true,
        'can_check_out': false,
        'checkout_mode': 'not_required',
        'checkout_message': 'Job Mission – check-out not required',
        'check_in_record_id': 1,
        'is_today': true,
      });
      expect(today.checkoutMode, CheckinCheckoutMode.notRequired);
    });
  });
}
