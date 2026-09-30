import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_api_client.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_resolve.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Location is not set" flow on the timesheet project picker: tell the
/// project's staff list (DM → their mobile chat notification) and post the
/// same note in the project group chat so support can set the coordinates.
abstract final class TmProjectLocationNotifyService {
  /// Projects already notified this app session (no repeat spam).
  static final Set<String> _notified = {};

  static bool wasNotified(String projectId) => _notified.contains(projectId);

  /// Marks notified immediately (UI shows the tick), then delivers in the
  /// background. Returns how many staff DMs were delivered; on total failure
  /// the mark is cleared so the foreman can retry.
  static Future<int> notifyStaff({
    required TimesheetApiClient client,
    required Project project,
  }) async {
    _notified.add(project.id);
    final text = _message(project);
    var delivered = 0;
    try {
      final staff = await client.fetchProjectStaff(project.id);
      final self = FirebaseAuth.instance.currentUser?.uid;
      final uids = <String>[];
      for (final member in staff) {
        try {
          final uid = await TimesheetChatResolve.firebaseUidForEmployee(
            member.employeeId,
            odooUserId: member.odooUserId,
          );
          if (uid == null || uid.isEmpty || uid == self) continue;
          uids.add(uid);
          final chatId = await TimesheetChatResolve.ensureDmForMember(member);
          await ChatRepository.instance.sendText(chatId, text);
          delivered++;
        } catch (e) {
          debugPrint('LocationNotify: DM ${member.employeeId} failed: $e');
        }
      }

      final roomId = project.chatRoomId.trim().isNotEmpty
          ? project.chatRoomId.trim()
          : 'project_${project.id}';
      try {
        await ChatRepository.instance.ensureProjectGroupChat(
          chatId: roomId,
          title: project.name,
          memberUids: uids,
        );
        await ChatRepository.instance.sendText(roomId, text);
      } catch (e) {
        debugPrint('LocationNotify: group $roomId failed: $e');
      }
      debugPrint(
        'LocationNotify: project=${project.id} staff=${staff.length} '
        'delivered=$delivered',
      );
    } catch (e) {
      debugPrint('LocationNotify: failed for ${project.id}: $e');
    }
    if (delivered == 0) _notified.remove(project.id);
    return delivered;
  }

  /// Bypasses the API client's project cache so support-side coordinate
  /// updates show up immediately.
  static Future<List<Project>> reloadInProgressProjects(WidgetRef ref) async {
    ref.read(timesheetApiClientProvider).clearCache();
    ref.invalidate(timesheetProjectBucketsProvider);
    final buckets = await ref.read(timesheetProjectBucketsProvider.future);
    return buckets.inProgress;
  }

  static String _message(Project project) {
    final foreman =
        SharedPref.getLoginDataOrNull()?.result?.data?.name?.toString().trim();
    final who = foreman == null || foreman.isEmpty ? 'A foreman' : foreman;
    final code = project.code.trim().isEmpty ? '' : ' (${project.code.trim()})';
    return '📍 Location not set — ${project.name}$code\n'
        '$who cannot submit the timesheet for this project because its site '
        'coordinates are missing. Please set the project location so it can '
        'be selected.';
  }
}
