import 'package:el_race/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TS_SHADOW defaults on for the pilot build', () {
    expect(FeatureFlags.tsShadow, isTrue);
  });
}
