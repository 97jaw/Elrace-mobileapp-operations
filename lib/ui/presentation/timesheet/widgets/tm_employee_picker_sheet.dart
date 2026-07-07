import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Slide-up employee picker (single or multi).
class TmEmployeePickerSheet {
  static const int reportMaxSelection = 30;

  static Future<List<TimesheetOdooEmployee>?> show(
    BuildContext context, {
    required List<TimesheetOdooEmployee> employees,
    required String title,
    bool multiSelect = true,
    List<int> initialSelectedIds = const [],
    int? maxSelection,
  }) {
    return showModalBottomSheet<List<TimesheetOdooEmployee>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _Body(
        title: title,
        employees: employees,
        multiSelect: multiSelect,
        initialSelectedIds: initialSelectedIds,
        maxSelection: maxSelection,
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.title,
    required this.employees,
    required this.multiSelect,
    required this.initialSelectedIds,
    this.maxSelection,
  });

  final String title;
  final List<TimesheetOdooEmployee> employees;
  final bool multiSelect;
  final List<int> initialSelectedIds;
  final int? maxSelection;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final Set<int> _selected = widget.initialSelectedIds.toSet();
  String _query = '';

  List<TimesheetOdooEmployee> get _filtered {
    return widget.employees.where((e) => e.matchesSearchQuery(_query)).toList();
  }

  void _toggle(TimesheetOdooEmployee e) {
    final max = widget.maxSelection;
    if (widget.multiSelect &&
        max != null &&
        !_selected.contains(e.employeeId) &&
        _selected.length >= max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can select up to $max employees')),
      );
      return;
    }

    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(e.employeeId)) {
          _selected.remove(e.employeeId);
        } else {
          _selected.add(e.employeeId);
        }
      } else {
        _selected
          ..clear()
          ..add(e.employeeId);
      }
    });
  }

  void _confirm() {
    final max = widget.maxSelection;
    if (max != null && _selected.length > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select at most $max employees')),
      );
      return;
    }
    final picked = widget.employees
        .where((e) => _selected.contains(e.employeeId))
        .toList();
    Navigator.of(context).pop(picked);
  }

  Widget _leadingAvatar(TimesheetOdooEmployee e) {
    final imageUrl = e.imageUrl;
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipOval(
        child: imageUrl != null
            ? TmFastNetworkImage(
                url: imageUrl,
                width: 44,
                height: 44,
                memCacheWidth: 88,
              )
            : ColoredBox(
                color: TimesheetModuleColors.navyTint,
                child: Center(
                  child: Text(
                    e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: TimesheetModuleColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final list = _filtered;
    final max = widget.maxSelection;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TimesheetModuleColors.navy,
              TimesheetModuleColors.primaryGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      PhosphorIcons.x(),
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TimesheetModuleTypography.body(),
                decoration: InputDecoration(
                  hintText: 'Search by file ID or name',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  filled: true,
                  fillColor: TimesheetModuleColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (widget.multiSelect && max != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_selected.length} / $max selected · ${list.length} shown',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'No employees match your search',
                        style: TimesheetModuleTypography.body().copyWith(
                          color: TimesheetModuleColors.surface,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: list.length,
                      itemExtent: 80,
                      itemBuilder: (context, index) {
                        final e = list[index];
                        final selected = _selected.contains(e.employeeId);
                        final subtitleParts = <String>[
                          e.displayFileId,
                          if (e.jobPosition != null &&
                              e.jobPosition!.isNotEmpty)
                            e.jobPosition!,
                        ];
                        final titleStyle = TimesheetModuleTypography.body()
                            .copyWith(
                          color: selected
                              ? TimesheetModuleColors.text
                              : TimesheetModuleColors.surface,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        );
                        final subtitleStyle =
                            TimesheetModuleTypography.caption().copyWith(
                          color: selected
                              ? TimesheetModuleColors.mutedText
                              : TimesheetModuleColors.surface
                                  .withValues(alpha: 0.82),
                        );
                        return Material(
                            color: TimesheetModuleColors.surface
                                .withValues(alpha: selected ? 1 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              onTap: () => _toggle(e),
                              leading: _leadingAvatar(e),
                              title: Text(
                                e.name,
                                style: titleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                subtitleParts.join(' · '),
                                style: subtitleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                selected
                                    ? PhosphorIcons.checkCircle()
                                    : PhosphorIcons.circle(),
                                color: selected
                                    ? TimesheetModuleColors.primary
                                    : TimesheetModuleColors.surface
                                        .withValues(alpha: 0.55),
                              ),
                            ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
              child: TmPrimaryButton(
                label: widget.multiSelect
                    ? (max != null
                        ? 'Done (${_selected.length}/$max)'
                        : 'Select (${_selected.length})')
                    : 'Select',
                icon: PhosphorIcons.check(),
                onPressed: _selected.isEmpty ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
