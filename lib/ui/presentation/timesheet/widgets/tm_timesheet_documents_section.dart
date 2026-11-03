import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/ui/chat/stamp_signature_on_zone.dart';
import 'package:el_race/ui/presentation/my_actions/theme/signature_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/signature/signature_style_doc_row.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_documents_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared open / status helpers for foreman timesheet approval docs.
abstract final class TmTimesheetDocumentsActions {
  static Color statusColor(TimesheetApproval doc) {
    switch (doc.status) {
      case TimesheetApprovalStatus.approved:
        return SignatureTheme.signed;
      case TimesheetApprovalStatus.rejected:
        return SignatureTheme.expired;
      case TimesheetApprovalStatus.pending:
        return SignatureTheme.waiting;
    }
  }

  static Future<void> open(
    BuildContext context,
    TimesheetApproval doc,
  ) async {
    try {
      final bytes =
          await TimesheetApprovalRepository.instance.downloadPdf(doc.pdfPath);
      final stamped = await stampTimesheetApprovalTextsCompute(
        pdfBytes: bytes,
        cells: doc.cells,
        approvers: doc.approvers,
      );
      if (!context.mounted) return;
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
      debugPrint('TmTimesheetDocumentsActions.open: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this timesheet')),
      );
    }
  }
}

/// Foreman dashboard: latest 5 docs + Show all (flag ON only).
///
/// Must sit inside an [Expanded] so the list scrolls in its own viewport.
class TmTimesheetDocumentsSection extends StatefulWidget {
  const TmTimesheetDocumentsSection({super.key});

  static const int previewLimit = 5;

  @override
  State<TmTimesheetDocumentsSection> createState() =>
      _TmTimesheetDocumentsSectionState();
}

class _TmTimesheetDocumentsSectionState
    extends State<TmTimesheetDocumentsSection> {
  static const Color _orange = Color(0xFFF97316);
  static const Color _card = TimesheetModuleColors.glassSurface;
  static const Color _cardBorder = Color(0xFFE4DCCB);
  static const Color _ink = Color(0xFF2A2A2A);

  bool _opening = false;
  late final Stream<List<TimesheetApproval>> _mineStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _mineStream = TimesheetApprovalRepository.instance.watchMine(
      uid,
      limit: TmTimesheetDocumentsSection.previewLimit,
    );
  }

  Future<void> _open(TimesheetApproval doc) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await TmTimesheetDocumentsActions.open(context, doc);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Timesheet documents',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const TmTimesheetDocumentsListScreen(),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _orange,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Show all',
                  style: TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<TimesheetApproval>>(
              stream: _mineStream,
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
                final docs = snap.data ?? const <TimesheetApproval>[];
                if (docs.isEmpty) {
                  return const Align(
                    alignment: Alignment.topCenter,
                    child: TimesheetEmptyState(
                      message: 'No timesheet documents yet',
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    return SignatureStyleDocRow(
                      fileName: doc.fileName,
                      detailLine: doc.projectName.trim().isEmpty
                          ? null
                          : doc.projectName,
                      dateLabel: DateFormat('dd-MMM-yy  HH:mm')
                          .format(doc.createdAt),
                      statusLabel: doc.statusLabel,
                      statusColor:
                          TmTimesheetDocumentsActions.statusColor(doc),
                      onTap: _opening ? () {} : () => _open(doc),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
