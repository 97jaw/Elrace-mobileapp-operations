import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/project_chat_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Opens [ProjectChatPickerScreen] — one project direct, several → quick picker.
class TimesheetChatLauncher {
  TimesheetChatLauncher._();

  static Future<void> open(BuildContext context, WidgetRef ref) async {
    try {
      final projects = await ref.read(timesheetProjectsProvider.future);
      if (!context.mounted) return;

      if (projects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No in-progress projects to chat on')),
        );
        return;
      }

      if (projects.length == 1) {
        _openHub(context, projects.first);
        return;
      }

      final picked = await showModalBottomSheet<Project>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ProjectPickSheet(projects: projects),
      );
      if (picked != null && context.mounted) {
        _openHub(context, picked);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

  static void _openHub(BuildContext context, Project project) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProjectChatPickerScreen(
          projectId: project.id,
          projectName: project.name,
        ),
      ),
    );
  }
}

class _ProjectPickSheet extends StatelessWidget {
  const _ProjectPickSheet({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.55,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Choose project chat',
                style: TimesheetModuleTypography.h2(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final p = projects[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: TimesheetModuleColors.bgGradientEnd,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: Icon(
                          PhosphorIcons.chatCircleText(),
                          color: TimesheetModuleColors.primary,
                        ),
                        title: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: p.woRefNo.trim().isNotEmpty
                            ? Text(p.woRefNo)
                            : null,
                        trailing: Icon(PhosphorIcons.caretRight()),
                        onTap: () => Navigator.of(context).pop(p),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
