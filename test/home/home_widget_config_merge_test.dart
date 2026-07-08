import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeDefaultWidgetsVisibility', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'isRegistered': true,
        'loginResponse': jsonEncode({
          'result': {
            'data': {
              'default_widgets': {
                'data': {
                  'media_widget': {
                    'widget_number': 5,
                    'widget_name': 'Media',
                    'is_disabled': false,
                    'record_to_show': {'count': 3},
                  },
                  'hrms_widget': {
                    'widget_number': 18,
                    'is_disabled': false,
                  },
                },
              },
            },
          },
        }),
      });
      await SharedPref().instantiatePreferences();
    });

    test('updates is_disabled while preserving record_to_show', () async {
      final ok = await SharedPref.mergeDefaultWidgetsVisibility({
        'media_widget': {'widget_number': 5, 'is_disabled': true},
      });
      expect(ok, isTrue);

      final login = SharedPref.getLoginData();
      final media = login.result?.data?.defaultWidgets?.data?.mediaWidget;
      expect(media?.isDisabled, isTrue);
      expect(media?.recordMap?['count'], 3);
    });

    test('adds missing widget keys from refresh payload', () async {
      final ok = await SharedPref.mergeDefaultWidgetsVisibility({
        'lpo_widget': {'widget_number': 13, 'is_disabled': false},
      });
      expect(ok, isTrue);

      final login = SharedPref.getLoginData();
      expect(
        login.result?.data?.defaultWidgets?.data?.lpoWidget?.isDisabled,
        isFalse,
      );
    });
  });
}
