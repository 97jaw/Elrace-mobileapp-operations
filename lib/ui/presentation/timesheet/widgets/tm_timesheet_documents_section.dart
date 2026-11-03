import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/ui/chat/stamp_signature_on_zone.dart';
import 'package:el_race/ui/presentation/my_actions/theme/signature_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/signature/signature_style_doc_row.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Foreman dashboard list of sent timesheet approvals (flag ON only).
class TmTimesheetDocumentsSection extends StatefulWidget {
  const TmTimesheetDocumentsSection({super.key});

  @override
  State<TmTimesheetDocumentsSection> createState() =>
      _TmTimesheetDocumentsSectionState();
}

class _TmTimesheetDocumentsSectionState
    extends State<TmTimesheetDocumentsSection> {
  static const int _pageSize = 20;
  int _visibleCount = _pageSize;
  bool _opening = false;

  Color _statusColor(TimesheetApproval doc) {
    switch (doc.status) {
      case TimesheetApprovalStatus.approved:
        return SignatureTheme.signed;
      case TimesheetApprovalStatus.rejected:
        return SignatureTheme.expired;
      case TimesheetApprovalStatus.pending:
        return SignatureTheme.waiting;
    }
  }

  Future<void> _open(TimesheetApproval doc) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final bytes =
          await TimesheetApprovalRepository.instance.downloadPdf(doc.pdfPath);
      final stamped = stampTimesheetApprovalTexts(
        pdfBytes: bytes,
        cells: doc.cells,
        approvers: doc.approvers,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TmPdfBytesPreviewScreen(
            pdfBytes: stamped,
            title: doc.fileName,
            projectId: doc.projectId,
            projectName: doc.projectName,
            allowSignTimesheet: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Timesheet documents',
          style: TimesheetModuleTypography.h2(),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<TimesheetApproval>>(
          stream: TimesheetApprovalRepository.instance.watchMine(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return TimesheetErrorState(
                message: 'Could not load timesheet documents',
                onRetry: () => setState(() {}),
              );
            }
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
              );
            }
            final all = snap.data ?? const <TimesheetApproval>[];
            if (all.isEmpty) {
              return const TimesheetEmptyState(
                message: 'No timesheet documents yet',
              );
            }
            final visible = all.take(_visibleCount).toList();
            final hasMore = _visibleCount < all.length;
            return Column(
              children: [
                for (final doc in visible)
                  SignatureStyleDocRow(
                    fileName: doc.fileName,
                    detailLine: doc.projectName.trim().isEmpty
                        ? null
                        : doc.projectName,
                    dateLabel: DateFormat('dd-MMM-yy  HH:mm')
                        .format(doc.createdAt),
                    statusLabel: doc.statusLabel,
                    statusColor: _statusColor(doc),
                    onTap: _opening ? () {} : () => _open(doc),
                  ),
                if (hasMore)
                  TextButton(
                    onPressed: () {
                      setState(() => _visibleCount += _pageSize);
                    },
                    child: const Text('Load more'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
