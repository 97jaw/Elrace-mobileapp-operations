import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_employee_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// FM timesheet print wizard — employee(s) + date range → PDF (Odoo report).
class FmTimesheetPrintReportScreen extends ConsumerStatefulWidget {
  const FmTimesheetPrintReportScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<FmTimesheetPrintReportScreen> createState() =>
      _FmTimesheetPrintReportScreenState();
}

class _FmTimesheetPrintReportScreenState
    extends ConsumerState<FmTimesheetPrintReportScreen> {
  List<TimesheetOdooEmployee> _roster = const [];
  List<TimesheetOdooEmployee> _selected = const [];
  late DateTime _from;
  late DateTime _to;
  bool _loadingRoster = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
    _loadRoster();
  }

  String? _rosterError;

  Future<void> _loadRoster() async {
    setState(() {
      _loadingRoster = true;
      _rosterError = null;
    });
    final client = ref.read(timesheetApiClientProvider);

    try {
      if (!client.hasLiveSession) {
        throw TimesheetOdooException('Not signed in');
      }
      final roster = await client.fetchLaborEmployeesForReport(
        projectId: widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _selected = const [];
        _loadingRoster = false;
      });
    } on TimesheetOdooException catch (e) {
      if (!mounted) return;
      setState(() {
        _roster = const [];
        _selected = const [];
        _loadingRoster = false;
        _rosterError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roster = const [];
        _selected = const [];
        _loadingRoster = false;
        _rosterError = 'Could not load labors: $e';
      });
    }
  }

  void _retryLoadRoster() {
    ref.read(timesheetApiClientProvider).clearCache();
    ref.invalidate(timesheetHrScopeProvider);
    _loadRoster();
  }

  Future<void> _pickEmployees() async {
    final picked = await TmEmployeePickerSheet.show(
      context,
      employees: _roster,
      title: 'Select employees (max 30)',
      multiSelect: true,
      maxSelection: 30,
      initialSelectedIds: _selected.map((e) => e.employeeId).toList(),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _generate() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one employee (max 30)'),
        ),
      );
      return;
    }
    if (_selected.length > 30) {
      setState(() => _selected = _selected.take(30).toList());
    }

    setState(() => _generating = true);
    try {
      final client = ref.read(timesheetApiClientProvider);
      final result = await client.printTimesheetReport(
        employeeIds: _selected.map((e) => e.employeeId).toList(),
        fromDate: _from,
        toDate: _to,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate timesheet PDF')),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _TimesheetPrintPdfViewer(
            pdfBytes: result.pdfBytes,
            fileName: result.fileName,
            projectId: widget.projectId,
            projectName: widget.projectName,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      appBar: AppBar(
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        title: Text(
          'Timesheet report',
          style: TimesheetModuleTypography.h2(),
        ),
      ),
      body: _loadingRoster
          ? const TimesheetLoadingState(style: TimesheetLoadingStyle.list)
          : _roster.isEmpty
              ? TimesheetErrorState(
                  message: _rosterError ??
                      'No labors loaded from employee list API',
                  onRetry: _retryLoadRoster,
                )
              : ListView(
              padding: const EdgeInsets.all(
                TimesheetModuleLayout.screenPaddingH,
              ),
              children: [
                if (widget.projectName != null) ...[
                  Text(
                    widget.projectName!,
                    style: TimesheetModuleTypography.caption(),
                  ),
                  const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                ],
                Text(
                  'Employees',
                  style: TimesheetModuleTypography.caption().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TmSecondaryButton(
                  label: _selected.isEmpty
                      ? 'Select employees (max 30)'
                      : '${_selected.length} / 30 selected',
                  icon: PhosphorIcons.users(),
                  onPressed: _pickEmployees,
                ),
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
                Text(
                  'Date range',
                  style: TimesheetModuleTypography.caption().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _DateTile(
                  label: 'From',
                  value: dateFmt.format(_from),
                  onTap: () => _pickDate(isFrom: true),
                ),
                const SizedBox(height: 8),
                _DateTile(
                  label: 'To',
                  value: dateFmt.format(_to),
                  onTap: () => _pickDate(isFrom: false),
                ),
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
                TmPrimaryButton(
                  label: _generating ? 'Generating…' : 'Generate PDF',
                  icon: PhosphorIcons.filePdf(),
                  onPressed: _generating ? null : _generate,
                ),
              ],
            ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TimesheetModuleColors.surface,
      borderRadius:
          BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      child: ListTile(
        onTap: onTap,
        title: Text(label, style: TimesheetModuleTypography.caption()),
        subtitle: Text(value, style: TimesheetModuleTypography.body()),
        trailing: Icon(PhosphorIcons.calendar()),
      ),
    );
  }
}

class _TimesheetPrintPdfViewer extends StatelessWidget {
  const _TimesheetPrintPdfViewer({
    required this.pdfBytes,
    required this.fileName,
    this.projectId,
    this.projectName,
  });

  final Uint8List pdfBytes;
  final String fileName;
  final String? projectId;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    return TmPdfBytesPreviewScreen(
      pdfBytes: pdfBytes,
      title: fileName,
      projectId: projectId,
      projectName: projectName,
    );
  }
}
