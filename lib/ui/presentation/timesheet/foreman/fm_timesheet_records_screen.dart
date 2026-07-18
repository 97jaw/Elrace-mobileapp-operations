import 'dart:typed_data';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_employee_picker_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// FM timesheet report — Odoo print PDF for current month (or selected range).
class FmTimesheetRecordsScreen extends ConsumerStatefulWidget {
  const FmTimesheetRecordsScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<FmTimesheetRecordsScreen> createState() =>
      _FmTimesheetRecordsScreenState();
}

class _FmTimesheetRecordsScreenState
    extends ConsumerState<FmTimesheetRecordsScreen> {
  List<TimesheetOdooEmployee> _roster = const [];
  List<TimesheetOdooEmployee> _selected = const [];
  late DateTime _from;
  late DateTime _to;
  bool _loadingRoster = true;
  bool _generating = false;
  Uint8List? _pdfBytes;
  String _fileName = 'Timesheet report.pdf';
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = DateTime(now.year, now.month, 1);
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _loadingRoster = true;
      _error = null;
    });
    final client = ref.read(timesheetApiClientProvider);

    try {
      if (!client.hasLiveSession) {
        throw TimesheetOdooException(
          'Not signed in — open Site Management after login',
        );
      }

      final roster = await client.fetchLaborEmployeesForReport(
        projectId: widget.projectId,
      );

      if (!mounted) return;
      setState(() {
        _roster = roster;
        _selected = const [];
        _pdfBytes = null;
        _loadingRoster = false;
      });
    } on TimesheetOdooException catch (e) {
      if (!mounted) return;
      setState(() {
        _roster = const [];
        _selected = const [];
        _loadingRoster = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roster = const [];
        _selected = const [];
        _loadingRoster = false;
        _error = 'Could not load labors: $e';
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
      title: 'Employees in report (max 30)',
      multiSelect: true,
      maxSelection: 30,
      initialSelectedIds: _selected.map((e) => e.employeeId).toList(),
    );
    if (picked != null) {
      setState(() {
        _selected = picked;
        _error = null;
      });
      await _generatePdf();
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    if (_selected.isNotEmpty) {
      await _generatePdf();
    }
  }

  Future<void> _generatePdf() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one employee (max 30)');
      return;
    }
    if (_selected.length > 30) {
      setState(() => _selected = _selected.take(30).toList());
    }

    setState(() {
      _generating = true;
      _error = null;
      _pdfBytes = null;
    });

    try {
      final client = ref.read(timesheetApiClientProvider);
      final result = await client.printTimesheetReport(
        employeeIds: _selected.map((e) => e.employeeId).toList(),
        fromDate: _from,
        toDate: _to,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = 'Could not generate timesheet PDF from server');
        return;
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = result.pdfBytes;
        _fileName = result.fileName;
        _generating = false;
        _error = null;
      });
      await _openPdfViewer();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Print request failed');
      }
    } finally {
      if (mounted && _generating) setState(() => _generating = false);
    }
  }

  Future<void> _openPdfViewer() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TmPdfBytesPreviewScreen(
          pdfBytes: bytes,
          title: _fileName,
          projectId: widget.projectId,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await TmSharePdfSheet.downloadToDevice(context, bytes, _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: _buildGlassBody(dateFmt),
    );
  }

  Widget _buildGlassBody(DateFormat dateFmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TmModuleGlassHeader(
          title: widget.projectName ?? 'Timesheet report',
          trailing: [
            IconButton(
              tooltip: 'Employees',
              onPressed: _loadingRoster || _generating ? null : _pickEmployees,
              icon: Icon(PhosphorIcons.users()),
            ),
            IconButton(
              tooltip: 'Print / refresh PDF',
              onPressed: _loadingRoster || _generating ? null : _generatePdf,
              icon: Icon(PhosphorIcons.printer()),
            ),
          ],
        ),
        Expanded(child: _buildRecordsBody(dateFmt)),
      ],
    );
  }

  Widget _buildRecordsBody(DateFormat dateFmt) {
    return _loadingRoster
          ? const TimesheetLoadingState(style: TimesheetLoadingStyle.list)
          : _roster.isEmpty
              ? TimesheetErrorState(
                  message: _error ??
                      'No labors returned from /timesheet/labor_list or '
                      '/employee/list. Deploy backend endpoint and retry.',
                  onRetry: _retryLoadRoster,
                )
              : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: TimesheetModuleColors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    TimesheetModuleLayout.cardSpacing,
                    TimesheetModuleLayout.screenPaddingH,
                    TimesheetModuleLayout.cardSpacing,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${dateFmt.format(_from)} – ${dateFmt.format(_to)}',
                        style: TimesheetModuleTypography.cardTitle(),
                      ),
                      Text(
                        _selected.isEmpty
                            ? 'No employees selected (max 30)'
                            : '${_selected.length} of 30 selected',
                        style: TimesheetModuleTypography.caption(),
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      Row(
                        children: [
                          Expanded(
                            child: TmSecondaryButton(
                              label: 'Date range',
                              icon: PhosphorIcons.calendar(),
                              onPressed: _generating ? null : _pickRange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TmSecondaryButton(
                              label: 'Download',
                              icon: PhosphorIcons.downloadSimple(),
                              onPressed: _pdfBytes == null || _generating
                                  ? null
                                  : _downloadPdf,
                            ),
                          ),
                        ],
                      ),
                      if (widget.projectId != null) ...[
                        const SizedBox(
                          height: TimesheetModuleLayout.cardSpacing,
                        ),
                        TmTaskRow(
                          title: 'Site reports',
                          subtitle: 'Open site reports for this project',
                          icon: PhosphorIcons.clipboardText(),
                          onTap: () => Navigator.of(context).pushNamed(
                            TimesheetRouteNames.projectDetail,
                            arguments: TimesheetProjectArgs(
                              projectId: widget.projectId!,
                              projectName: widget.projectName,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _buildPdfBody(),
                ),
              ],
            );
  }

  Widget _buildPdfBody() {
    if (_generating) {
      return const TimesheetLoadingState(style: TimesheetLoadingStyle.list);
    }
    if (_error != null && _pdfBytes == null) {
      return TimesheetErrorState(
        message: _error!,
        onRetry: _selected.isEmpty ? _pickEmployees : _generatePdf,
      );
    }
    final bytes = _pdfBytes;
    if (bytes == null) {
      return TimesheetErrorState(
        message:
            'Select up to 30 employees (toolbar icon), then tap Print',
        onRetry: _pickEmployees,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.filePdf(),
              size: 56,
              color: TimesheetModuleColors.primary,
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            Text(
              'Timesheet PDF ready',
              style: TimesheetModuleTypography.h2(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_selected.length} employee(s) · same layout as Odoo print',
              style: TimesheetModuleTypography.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmPrimaryButton(
              label: 'View PDF',
              icon: PhosphorIcons.eye(),
              onPressed: _generating ? null : _openPdfViewer,
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'Download',
              icon: PhosphorIcons.downloadSimple(),
              onPressed: _generating ? null : _downloadPdf,
            ),
          ],
        ),
      ),
    );
  }
}
