import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// While the user touches the news-card mid strip, parent [ScrollView] physics
/// switch to [NeverScrollableScrollPhysics] so taps are not delayed by scroll.
class MidSectionScrollLock extends InheritedNotifier<ValueNotifier<bool>> {
  const MidSectionScrollLock({
    super.key,
    required ValueNotifier<bool> lock,
    required super.child,
  }) : super(notifier: lock);

  /// Non-listening lookup — avoids rebuilding the news block on lock changes.
  static ValueNotifier<bool>? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<MidSectionScrollLock>()?.notifier;
  }
}
