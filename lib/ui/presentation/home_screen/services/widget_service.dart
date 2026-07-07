import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';

class WidgetService {
  static const String _activeWidgetsKey = 'active_widgets';

  /// Retired from home grid — superseded by categorized home cards.
  static const Set<String> _retiredWidgetIds = {
    'attendance',
    'my_report',
  };

  static Future<List<WidgetModel>> getActiveWidgets() async {
    final activeWidgetsJson =
        SharedPref().getPreferenceString(_activeWidgetsKey);

    if (activeWidgetsJson.isEmpty) {
      await _initializeDefaultWidgets();
      return getActiveWidgets();
    }

    try {
      final List<dynamic> decoded = jsonDecode(activeWidgetsJson);
      var widgets =
          decoded.map((json) => WidgetModel.fromJson(json)).toList();

      final before = widgets.length;
      widgets = widgets
          .where((w) => !_retiredWidgetIds.contains(w.id))
          .toList();
      var dirty = widgets.length != before;

      for (final requiredId in ['site_management', 'time_sheet']) {
        if (!widgets.any((w) => w.id == requiredId)) {
          final widget = getAvailableWidgets().firstWhere(
            (w) => w.id == requiredId,
          );
          widgets.add(widget.copyWith(isActive: true));
          dirty = true;
        }
      }
      if (dirty) {
        await saveActiveWidgets(widgets);
      }

      return widgets;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _initializeDefaultWidgets() async {
    const defaultWidgets = [
      'petty_cash',
      'lpo',
      'documents',
      'todo_list',
      'projects',
      'my_request',
      'site_management',
      'time_sheet',
      'media',
      'qr_code',
      'prayer',
    ];

    final allWidgets = getAvailableWidgets();
    final activeWidgets = allWidgets
        .where((widget) => defaultWidgets.contains(widget.id))
        .map((widget) => widget.copyWith(isActive: true))
        .toList();

    await saveActiveWidgets(activeWidgets);
  }

  static Future<void> saveActiveWidgets(List<WidgetModel> widgets) async {
    final widgetsJson = jsonEncode(widgets.map((w) => w.toJson()).toList());
    SharedPref().setPreferencesString(_activeWidgetsKey, widgetsJson);
  }

  static Future<List<WidgetModel>> getAvailableWidgetsWithState() async {
    final activeWidgets = await getActiveWidgets();
    final allWidgets = getAvailableWidgets();

    return allWidgets.map((widget) {
      final isActive = activeWidgets.any((active) => active.id == widget.id);
      return widget.copyWith(isActive: isActive);
    }).toList();
  }

  static Future<void> toggleWidget(String widgetId) async {
    if (_retiredWidgetIds.contains(widgetId)) return;

    final currentWidgets = await getActiveWidgets();
    final widgetExists = currentWidgets.any((w) => w.id == widgetId);

    if (widgetExists) {
      currentWidgets.removeWhere((w) => w.id == widgetId);
    } else {
      final availableWidget =
          getAvailableWidgets().firstWhere((w) => w.id == widgetId);
      currentWidgets.add(availableWidget.copyWith(isActive: true));
    }

    await saveActiveWidgets(currentWidgets);
  }

  static Future<void> resetToDefaultWidgets() async {
    await _initializeDefaultWidgets();
  }
}
