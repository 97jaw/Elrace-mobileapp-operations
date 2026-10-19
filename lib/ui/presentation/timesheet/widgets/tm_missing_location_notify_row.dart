import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/services/tm_project_location_notify_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Callback used by Active Sites + confirm sheet Notify buttons.
typedef TmNotifyMissingLocation = Future<int> Function(Project project);

/// Always-expanded red "Location not set" row with Notify → Notified.
class TmMissingLocationNotifyRow extends StatefulWidget {
  const TmMissingLocationNotifyRow({
    super.key,
    required this.project,
    this.onNotify,
    this.label = 'Location not set',
  });

  final Project project;
  final TmNotifyMissingLocation? onNotify;
  final String label;

  static const Color danger = Color(0xFFD93025);

  @override
  State<TmMissingLocationNotifyRow> createState() =>
      _TmMissingLocationNotifyRowState();
}

class _TmMissingLocationNotifyRowState
    extends State<TmMissingLocationNotifyRow> {
  late bool _notified =
      TmProjectLocationNotifyService.wasNotified(widget.project.id);
  bool _sending = false;

  Future<void> _notify() async {
    final notify = widget.onNotify;
    if (notify == null || _notified || _sending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = widget.project.name;
    setState(() => _sending = true);
    final delivered = await notify(widget.project);
    if (!mounted) return;
    if (delivered > 0) {
      setState(() {
        _sending = false;
        _notified = true;
      });
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Staff notified about $name ($delivered '
            '${delivered == 1 ? 'person' : 'people'})',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _sending = false);
    messenger?.showSnackBar(
      SnackBar(content: Text("Couldn't notify staff for $name — try again")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_off_rounded,
          size: 18,
          color: TmMissingLocationNotifyRow.danger,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TimesheetModuleTypography.caption().copyWith(
              color: TmMissingLocationNotifyRow.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (widget.onNotify != null) ...[
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _sending
                ? const SizedBox(
                    key: ValueKey('sending'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TmMissingLocationNotifyRow.danger,
                    ),
                  )
                : _notified
                    ? Row(
                        key: const ValueKey('notified'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            size: 16,
                            color: const Color(0xFF2E9E5B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Notified',
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: const Color(0xFF2E9E5B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        key: const ValueKey('notify'),
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: _notify,
                          icon: Icon(PhosphorIcons.bellRinging(), size: 14),
                          label: const Text('Notify'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TimesheetModuleColors.ink,
                            side: const BorderSide(
                              color: TimesheetModuleColors.ink,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ],
    );
  }
}
