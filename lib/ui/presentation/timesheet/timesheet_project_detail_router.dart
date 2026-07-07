import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm2_project_detail.dart';
import 'package:el_race/ui/presentation/timesheet/pm/pm2_project_detail.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimesheetProjectDetailRouter extends ConsumerWidget {
  const TimesheetProjectDetailRouter({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(tmEffectiveRoleProvider);
    if (role == TimesheetEffectiveRole.pm) {
      return Pm2ProjectDetail(projectId: projectId);
    }
    return Fm2ProjectDetail(projectId: projectId);
  }
}
