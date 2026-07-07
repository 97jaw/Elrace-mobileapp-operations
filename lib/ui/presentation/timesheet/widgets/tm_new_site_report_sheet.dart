import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Themed bottom sheet — name a new site report before opening the camera flow.
class TmNewSiteReportSheet {
  static Future<String?> show(
    BuildContext context, {
    String? initialTitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TmNewSiteReportSheetBody(initialTitle: initialTitle);
      },
    );
  }
}

class _TmNewSiteReportSheetBody extends StatefulWidget {
  const _TmNewSiteReportSheetBody({this.initialTitle});

  final String? initialTitle;

  @override
  State<_TmNewSiteReportSheetBody> createState() =>
      _TmNewSiteReportSheetBodyState();
}

class _TmNewSiteReportSheetBodyState extends State<_TmNewSiteReportSheetBody> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
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
            Text('New site report', style: TimesheetModuleTypography.h2()),
            const SizedBox(height: 6),
            Text(
              'Add a title, then capture photos on site.',
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
                hintText: 'e.g. Daily progress · 12 May',
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
              label: 'Continue to capture',
              icon: PhosphorIcons.camera(),
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
