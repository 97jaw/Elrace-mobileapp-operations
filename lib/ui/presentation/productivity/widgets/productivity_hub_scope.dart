import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_bottom_bar.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:flutter/material.dart';

/// Lets tab bodies switch the fixed hub bottom bar without pushing routes.
class ProductivityHubScope extends InheritedWidget {
  const ProductivityHubScope({
    super.key,
    required this.selected,
    required this.selectTab,
    required super.child,
  });

  final ProductivityLightNavTab selected;
  final void Function(
    ProductivityLightNavTab tab, {
    TaskFilter? tasksFilter,
    bool? ticketsHighPriorityOnly,
  }) selectTab;

  static ProductivityHubScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProductivityHubScope>();
  }

  static ProductivityHubScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ProductivityHubScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ProductivityHubScope oldWidget) =>
      selected != oldWidget.selected;
}
