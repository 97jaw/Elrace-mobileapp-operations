import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:el_race/ui/chat/stamp_signature_on_zone.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Approver (or read-only) view of a timesheet approval PDF.
class TimesheetApprovalDocumentScreen extends StatefulWidget {
  const TimesheetApprovalDocumentScreen({
    super.key,
    required this.approval,
    this.viewerUid,
  });

  final TimesheetApproval approval;

  /// Defaults to the signed-in Firebase uid.
  final String? viewerUid;

  @override
  State<TimesheetApprovalDocumentScreen> createState() =>
      _TimesheetApprovalDocumentScreenState();
}

class _TimesheetApprovalDocumentScreenState
    extends State<TimesheetApprovalDocumentScreen> {
  late TimesheetApproval _approval;
  Uint8List? _pdfBytes;
  String? _error;
  bool _loading = true;
  bool _acting = false;

  String get _uid =>
      widget.viewerUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canAct => _approval.showsApproverActionsFor(_uid);

  @override
  void initState() {
    super.initState();
    _approval = widget.approval;
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await TimesheetApprovalRepository.instance
          .downloadPdf(_approval.pdfPath);
      final stamped = await stampTimesheetApprovalTextsCompute(
        pdfBytes: bytes,
        cells: _approval.cells,
        approvers: _approval.approvers,
      );
      if (!mounted) return;
      setState(() {
        _pdfBytes = stamped;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TimesheetApprovalDocumentScreen._loadPdf: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not open this timesheet';
        _loading = false;
      });
    }
  }

  Future<void> _onLocalAction(bool approve) async {
    if (_acting) return;
    _acting = true;
    try {
      await TimesheetApprovalRepository.instance.act(
        id: _approval.id,
        approve: approve,
      );
      ApprovalCountService.invalidateCache();
      ApprovalCountService.notifyListeners();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('TimesheetApprovalDocumentScreen._onLocalAction: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This timesheet is no longer waiting for you'),
        ),
      );
      Navigator.of(context).pop(false);
    } finally {
      _acting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TmModuleGlassHeader(title: _approval.fileName),
          if (!_canAct)
            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 0),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
                decoration: BoxDecoration(
                  color: ApprovalsOverviewTheme.statCardSignDocument,
                  borderRadius: BorderRadius.circular(10.tr),
                ),
                child: Text(
                  _approval.statusLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w600,
                    color: ApprovalsOverviewTheme.signDocument,
                  ),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
          if (_canAct && _pdfBytes != null && _error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.tw, 8.th, 12.tw, 10.th),
                child: OverviewGlassPanel(
                  fillAlpha: 0.78,
                  blurSigma: 14,
                  radius: 20,
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.tw, vertical: 6.th),
                  child: ApprovalActionButtons(
                    requestId: _approval.id,
                    type: 'timesheet_approval',
                    userIds: const [],
                    variant: ApprovalActionButtonsVariant.glass,
                    disabled: _acting,
                    onLocalAction: _onLocalAction,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const TimesheetLoadingState(style: TimesheetLoadingStyle.list);
    }
    if (_error != null) {
      return TimesheetErrorState(message: _error!, onRetry: _loadPdf);
    }
    final bytes = _pdfBytes;
    if (bytes == null) {
      return const TimesheetEmptyState(message: 'No PDF file');
    }
    return TmPdfFileViewer(pdfBytes: bytes, fileName: _approval.fileName);
  }
}

/// Fetches a timesheet approval by id and opens the right mode
/// (pending for me → buttons; otherwise read-only).
class TimesheetApprovalByIdLoader extends StatefulWidget {
  const TimesheetApprovalByIdLoader({super.key, required this.id});

  final String id;

  @override
  State<TimesheetApprovalByIdLoader> createState() =>
      _TimesheetApprovalByIdLoaderState();
}

class _TimesheetApprovalByIdLoaderState
    extends State<TimesheetApprovalByIdLoader> {
  late Future<TimesheetApproval?> _future;

  @override
  void initState() {
    super.initState();
    _future = TimesheetApprovalRepository.instance.getById(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TimesheetApproval?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: TimesheetLoadingState(style: TimesheetLoadingStyle.list),
          );
        }
        final doc = snap.data;
        if (snap.hasError || doc == null) {
          return Scaffold(
            body: TimesheetErrorState(
              message: 'This timesheet could not be opened',
              onRetry: () {
                setState(() {
                  _future =
                      TimesheetApprovalRepository.instance.getById(widget.id);
                });
              },
            ),
          );
        }
        return TimesheetApprovalDocumentScreen(approval: doc);
      },
    );
  }
}
