import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:flutter/material.dart';

/// Navigate to the main home tab and clear pushed routes when possible.
abstract final class HomeNavigation {
  static const int homeTabIndex = 1;

  /// Logo tap / explicit "go home" from any screen under [MaterialApp].
  static void goToHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    _switchToHomeTab(context);
  }

  /// Android/iOS back: pop route if stacked, else show home tab.
  static void handleSystemBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _switchToHomeTab(context);
  }

  static void _switchToHomeTab(BuildContext context) {
    try {
      final bloc = HomeBloc.get(context);
      if (bloc.currentIndex != homeTabIndex) {
        bloc.add(const ChangeCurrentIndex(index: homeTabIndex));
      }
    } catch (_) {
      // Not under MainScreen — popUntil already ran if possible.
    }
  }
}
