import 'package:el_race/core/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService', () {
    final service = UpdateService.instance;

    test('forces update when current version is below minVersion', () {
      final result = service.buildResultFromPayload(
        currentVersion: '1.0.17+74',
        payload: {
          'minVersion': '1.0.18',
          'latestVersion': '1.0.18',
          'updateUrl': 'https://example.com/store',
        },
      );

      expect(result.forceUpdate, isTrue);
      expect(result.optionalUpdate, isFalse);
      expect(result.updateUrl, 'https://example.com/store');
    });

    test('does not show update when current version satisfies minimum', () {
      final result = service.buildResultFromPayload(
        currentVersion: '1.0.18+75',
        payload: {
          'min_version': '1.0.18',
          'latest_version': '1.0.18',
        },
      );

      expect(result.forceUpdate, isFalse);
      expect(result.optionalUpdate, isFalse);
    });

    test('marks optional update when latest version is newer but min is met',
        () {
      final result = service.buildResultFromPayload(
        currentVersion: '1.0.17',
        payload: {
          'minimum_version': '1.0.16',
          'latest_version': '1.0.18',
        },
      );

      expect(result.forceUpdate, isFalse);
      expect(result.optionalUpdate, isTrue);
    });

    test('supports explicit forceUpdate with latestVersion', () {
      final result = service.buildResultFromPayload(
        currentVersion: '1.0.17',
        payload: {
          'force_update': true,
          'latestVersion': '1.0.18',
        },
      );

      expect(result.forceUpdate, isTrue);
      expect(result.optionalUpdate, isFalse);
    });

    test('ignores build metadata while comparing semver', () {
      expect(
        service.compareVersions(
          service.parseVersion('1.0.17+74'),
          service.parseVersion('1.0.17'),
        ),
        0,
      );
    });
  });
}
