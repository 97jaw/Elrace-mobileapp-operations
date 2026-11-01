import 'package:flutter/widgets.dart';

/// Drops the keyboard when a route changes, including dialogs and sheets.
class UnfocusOnNavigate extends NavigatorObserver {
  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unfocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unfocus();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _unfocus();
  }
}
