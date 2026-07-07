import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Themed sheet to name a new report folder for a project.
class TmNewSiteReportFolderSheet {
  static Future<String?> show(
    BuildContext context, {
    String? projectName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Body(projectName: projectName),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({this.projectName});

  final String? projectName;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final hint = widget.projectName?.trim() ?? '';
    _controller = TextEditingController(
      text: hint.isNotEmpty ? hint : '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TimesheetModuleLayout.cardRadiusLg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          12,
          TimesheetModuleLayout.screenPaddingH,
          TimesheetModuleLayout.sectionGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('New report folder', style: TimesheetModuleTypography.h2()),
            const SizedBox(height: 6),
            Text(
              'Folders are linked to this project. You can add multiple reports inside each folder.',
              style: TimesheetModuleTypography.caption(),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: TimesheetModuleTypography.body(),
              decoration: InputDecoration(
                hintText: 'Folder name',
                hintStyle: TimesheetModuleTypography.body().copyWith(
                  color: TimesheetModuleColors.mutedText,
                ),
                filled: true,
                fillColor: TimesheetModuleColors.bgGradientEnd,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmPrimaryButton(
              label: 'Create & continue',
              icon: PhosphorIcons.folderPlus(),
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TimesheetModuleTypography.button(
                  color: TimesheetModuleColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
