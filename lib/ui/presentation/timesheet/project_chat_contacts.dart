import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Project staff split for Site Management chat pickers.
class ProjectChatContacts {
  const ProjectChatContacts({
    required this.all,
    required this.supervisors,
    required this.projectManagers,
    required this.otherStaff,
  });

  final List<TimesheetTeamMember> all;
  final List<TimesheetTeamMember> supervisors;
  final List<TimesheetTeamMember> projectManagers;
  final List<TimesheetTeamMember> otherStaff;

  static String projectGroupChatId(String projectId) =>
      'project_${projectId.trim()}';

  static String foremenGroupChatId(String projectId) =>
      'project_${projectId.trim()}_foremen';

  factory ProjectChatContacts.fromStaff(List<TimesheetTeamMember> staff) {
    final supervisors = <TimesheetTeamMember>[];
    final projectManagers = <TimesheetTeamMember>[];
    final otherStaff = <TimesheetTeamMember>[];

    for (final member in staff) {
      if (member.isSupervisor) {
        supervisors.add(member);
      } else if (member.isProjectManager) {
        projectManagers.add(member);
      } else {
        otherStaff.add(member);
      }
    }

    int sortKey(TimesheetTeamMember a, TimesheetTeamMember b) =>
        a.name.compareTo(b.name);
    supervisors.sort(sortKey);
    projectManagers.sort(sortKey);
    otherStaff.sort(sortKey);

    return ProjectChatContacts(
      all: List<TimesheetTeamMember>.from(staff)..sort(sortKey),
      supervisors: supervisors,
      projectManagers: projectManagers,
      otherStaff: otherStaff,
    );
  }
}

final projectChatContactsProvider = FutureProvider.autoDispose
    .family<ProjectChatContacts, String>((ref, projectId) async {
  final staff =
      await ref.watch(timesheetProjectStaffProvider(projectId).future);
  return ProjectChatContacts.fromStaff(staff);
});
