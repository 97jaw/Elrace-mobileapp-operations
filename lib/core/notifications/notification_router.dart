import 'dart:convert';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/notifications/notification_config_service.dart';
import 'package:el_race/core/notifications/notification_payload.dart';
import 'package:el_race/core/notifications/route_registry.dart';
import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/ui/presentation/Notification/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationRouter {
  static Future<void> open(NotificationPayload payload) async {
    final navigator = navKey.currentState;
    final context = navKey.currentContext;
    if (navigator == null || context == null) {
      return;
    }

    if (payload.action == 'open_record' &&
        payload.model.isNotEmpty &&
        !payload.model.startsWith('firestore.') &&
        NotificationConfigService.current.enabled) {
      final allowed = await _odooAllows(payload.model, payload.resId);
      if (!navigator.mounted) return;
      if (!allowed) {
        _deny(navigator.context);
        return;
      }
    }

    if (payload.model == 'elrace.labor.transfer') {
      NotificationRouteRegistry.beforeLaborOpen(navigator.context, payload);
      final transferId = int.tryParse(payload.resId);
      if (transferId != null && transferId > 0) {
        navigator.pushNamed(
          TimesheetRouteNames.laborTransferDetail,
          arguments: transferId,
        );
        return;
      }
    }

    final page = NotificationRouteRegistry.pageFor(payload);
    if (page != null) {
      navigator.push(MaterialPageRoute(builder: (_) => page));
      return;
    }

    _openCenter(navigator);
  }

  static void _openCenter(NavigatorState? navigator) {
    navigator?.push(
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
        settings: const RouteSettings(name: '/notifications'),
      ),
    );
  }

  static void _deny(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('You no longer have access to this item.')),
    );
  }

  static Future<bool> _odooAllows(String model, String resId) async {
    try {
      final response = await http.post(
        Uri.parse('${NotificationApiService.baseUrl}/v2/notifications/open'),
        headers: NotificationApiService.headers(),
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {'model': model, 'res_id': resId},
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      final result = decoded['result'];
      if (result is! Map) return false;
      return result['allowed'] == true;
    } catch (_) {
      return false;
    }
  }
}
