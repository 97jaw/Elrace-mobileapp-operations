import 'dart:async';

import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// After approve/reject: refresh Your Team providers + walk-up face roster.
abstract final class LaborTransferRosterRefresh {
  static Future<void> afterTeamChange(ProviderContainer container) async {
    final client = container.read(timesheetApiClientProvider);
    client.clearCache();
    container.invalidate(timesheetHrScopeProvider);
    container.invalidate(timesheetForemanLaborsProvider);

    if (!ProfilePhotoMatchTest.enabled) return;

    var fromNetwork = true;
    List<TimesheetTeamMember> team;
    try {
      team = await container.refresh(timesheetForemanLaborsProvider.future);
    } catch (e) {
      fromNetwork = false;
      debugPrint('LaborTransferRosterRefresh: Your Team load failed: $e');
      team = const [];
    }

    final labour = <TimesheetOdooEmployee>[
      for (final m in team) m.toOdooEmployee(),
    ];
    await ProfilePhotoFaceDb.instance.refreshRosterForCameraOpen(
      labour: labour,
      targetIds: {for (final m in team) m.employeeId},
      teamCount: team.length,
      fromNetwork: fromNetwork,
    );
  }
}
