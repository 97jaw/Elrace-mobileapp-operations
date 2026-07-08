import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_attendance_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_hrms_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_library_widgets_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_lpo_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_notes_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_petty_cash_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_projects_widgets_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_task_management_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_tickets_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_timesheet_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_config_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pull-to-refresh: visibility config + widget card data in parallel.
class HomeWidgetRefreshService {
  HomeWidgetRefreshService._();

  static Future<void> refresh(ProviderContainer container) async {
    await HomeWidgetConfigClient.refresh();
    final visible = visibleCategoryCodes();
    await HomeWidgetApiClient.refreshIfStale(
      force: true,
      onlyCodes: visible,
    );
    _invalidateHomeWidgetProviders(container);
  }

  static void _invalidateHomeWidgetProviders(ProviderContainer container) {
    container.invalidate(homeAttendanceWidgetProvider);
    container.invalidate(homeHrmsWidgetProvider);
    container.invalidate(homeTimesheetWidgetProvider);
    container.invalidate(homeMyProjectsWidgetProvider);
    container.invalidate(homeSiteManagementWidgetProvider);
    container.invalidate(homeMyReportsWidgetProvider);
    container.invalidate(homeLpoWidgetProvider);
    container.invalidate(homeNotesWidgetProvider);
    container.invalidate(homeTaskManagementWidgetProvider);
    container.invalidate(homeTicketsWidgetProvider);
    container.invalidate(homePettyCashWidgetProvider);
    container.invalidate(homeMyDocumentsWidgetProvider);
    container.invalidate(homeMediaWidgetProvider);
    container.invalidate(homePrayerTimesWidgetProvider);
  }

  /// Visible v7 category widgets after the latest pref merge.
  static Set<HomeWidgetCode> visibleCategoryCodes() {
    final visibility = HomeWidgetVisibility.fromLoginPref();
    return HomeWidgetCode.values.where(visibility.isVisible).toSet();
  }
}
