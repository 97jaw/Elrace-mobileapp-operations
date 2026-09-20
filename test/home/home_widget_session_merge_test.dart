import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'loginResponse': jsonEncode({
        'result': {
          'data': {
            'default_widgets': {
              'status': 'success',
              'data': {
                'media': {
                  'is_disabled': false,
                  'widget_number': 7,
                  'record_to_show': {'title': 'News', 'count': 3},
                },
                'attendance': {'is_disabled': false},
              },
            },
          },
        },
      }),
    });
    await SharedPref().instantiatePreferences();
  });

  Map<String, dynamic> cachedWidgets() {
    final login = jsonDecode(
      SharedPref.sharedPreferences.getString('loginResponse')!,
    );
    return login['result']['data']['default_widgets']['data']
        as Map<String, dynamic>;
  }

  test('visibility refresh preserves card metadata and unrelated widgets',
      () async {
    expect(
      await SharedPref.mergeLoginRoleFields({
        'default_widgets': {
          'data': {
            'media': {
              'is_disabled': true,
              'record_to_show': <String, dynamic>{},
            },
          },
        },
      }),
      isTrue,
    );
    final widgets = cachedWidgets();
    expect(widgets['media']['is_disabled'], isTrue);
    expect(widgets['media']['widget_number'], 7);
    expect(widgets['media']['record_to_show'], {'title': 'News', 'count': 3});
    expect(widgets['attendance'], {'is_disabled': false});
  });

  test('refresh accepts new records and adds newly assigned widgets', () async {
    expect(
      await SharedPref.mergeLoginRoleFields({
        'default_widgets': {
          'data': {
            'media': {
              'record_to_show': {'title': 'Latest News', 'count': 4},
            },
            'notes': {'is_disabled': false, 'widget_number': 9},
          },
        },
      }),
      isTrue,
    );
    final widgets = cachedWidgets();
    expect(widgets['media']['record_to_show'],
        {'title': 'Latest News', 'count': 4});
    expect(widgets['media']['is_disabled'], isFalse);
    expect(widgets['notes'], {'is_disabled': false, 'widget_number': 9});
  });
}
