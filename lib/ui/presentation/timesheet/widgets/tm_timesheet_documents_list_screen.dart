import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/signature/signature_style_doc_row.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_documents_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full foreman list of sent timesheet approvals (newest first, paged).
class TmTimesheetDocumentsListScreen extends StatefulWidget {
  const TmTimesheetDocumentsListScreen({super.key});

  static const int pageSize = 20;

  @override
  State<TmTimesheetDocumentsListScreen> createState() =>
      _TmTimesheetDocumentsListScreenState();
}

class _TmTimesheetDocumentsListScreenState
    extends State<TmTimesheetDocumentsListScreen> {
  int _limit = TmTimesheetDocumentsListScreen.pageSize;
  bool _opening = false;
  Stream<List<TimesheetApproval>>? _stream;

  @override
  void initState() {
    super.initState();
    _restartStream();
  }

  void _restartStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _stream = TimesheetApprovalRepository.instance.watchMine(
      uid,
      limit: _limit,
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

  void _loadMore() {
    setState(() {
      _limit += TmTimesheetDocumentsListScreen.pageSize;
      _restartStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimesheetModuleColors.warmGradientStart,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: TimesheetModuleColors.warmGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TmModuleGlassHeader(
              title: 'Timesheet documents',
              titleColor: Color(0xFF2A2A2A),
              scrimColor: TimesheetModuleColors.warmGradientEnd,
            ),
            Expanded(
              child: StreamBuilder<List<TimesheetApproval>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return TimesheetErrorState(
                      message: 'Could not load timesheet documents',
                      warm: true,
                      onRetry: () => setState(_restartStream),
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
                    return const TimesheetEmptyState(
                      message: 'No timesheet documents yet',
                    );
                  }
                  final hasMore = docs.length >= _limit;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= docs.length) {
                        return TextButton(
                          onPressed: _loadMore,
                          child: const Text('Load more'),
                        );
                      }
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
      ),
    );
  }
}
