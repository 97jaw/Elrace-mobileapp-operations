import 'package:el_race/ui/presentation/timesheet/project_chat_picker_screen.dart';
import 'package:flutter/material.dart';

/// Opens project chat picker (group on top + staff DMs).
class ProjectChatEntry extends StatelessWidget {
  const ProjectChatEntry({
    super.key,
    required this.projectId,
    this.projectName,
  });

  final String projectId;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    return ProjectChatPickerScreen(
      projectId: projectId,
      projectName: projectName,
    );
  }
}
