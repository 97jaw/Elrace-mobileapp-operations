import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_loading_placeholders.dart';
import 'package:flutter/material.dart';

enum TimesheetLoadingStyle {
  spinner,
  list,
  folders,
  gallery,
}

class TimesheetLoadingState extends StatelessWidget {
  const TimesheetLoadingState({
    super.key,
    this.style = TimesheetLoadingStyle.spinner,
    this.itemCount = 4,
  });

  final TimesheetLoadingStyle style;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case TimesheetLoadingStyle.list:
        return TimesheetListLoadingPlaceholders(itemCount: itemCount);
      case TimesheetLoadingStyle.folders:
        return ListView.separated(
          padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) =>
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          itemBuilder: (_, __) => const TimesheetFolderCardPlaceholder(),
        );
      case TimesheetLoadingStyle.gallery:
        return const TimesheetGalleryLoadingPlaceholders();
      case TimesheetLoadingStyle.spinner:
        return const Center(
          child: CircularProgressIndicator(
            color: TimesheetModuleColors.primary,
          ),
        );
    }
  }
}

class TimesheetEmptyState extends StatelessWidget {
  const TimesheetEmptyState({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TimesheetModuleTypography.body(),
      ),
    );
  }
}

class TimesheetErrorState extends StatelessWidget {
  const TimesheetErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.warm = false,
  });

  final String message;
  final VoidCallback? onRetry;

  /// Warm theme (foreman Timesheet screens): gradient Retry button.
  final bool warm;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TimesheetModuleTypography.body().copyWith(
              color: TimesheetModuleColors.danger,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            SizedBox(
              width: 180,
              child: warm
                  ? TmPrimaryButton(
                      label: 'Retry',
                      warm: true,
                      onPressed: onRetry,
                    )
                  : TmSecondaryButton(
                      label: 'Retry',
                      onPressed: onRetry,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
