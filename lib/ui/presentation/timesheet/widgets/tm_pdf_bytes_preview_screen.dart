import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/chat/models/chat_user.dart';
import 'package:el_race/chat/repositories/user_repository.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/core/timesheet/repositories/timesheet_approval_repository.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/timesheet_approval_feature.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:el_race/ui/chat/screens/sign_zone_picker_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signature/recipient_picker_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Writes PDF bytes to a temp file and shows them with [PDFView] (stable on iOS).
class TmPdfFileViewer extends StatefulWidget {
  const TmPdfFileViewer({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  final Uint8List pdfBytes;
  final String fileName;

  @override
  State<TmPdfFileViewer> createState() => _TmPdfFileViewerState();
}

class _TmPdfFileViewerState extends State<TmPdfFileViewer> {
  bool _loading = true;
  String? _filePath;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    try {
      final file = await TmSharePdfSheet.writeTempFile(
        widget.pdfBytes,
        widget.fileName,
      );
      if (!mounted) return;
      setState(() {
        _filePath = file.path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open PDF preview';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TimesheetLoadingState(style: TimesheetLoadingStyle.list);
    }
    if (_error != null) {
      return TimesheetErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
            _filePath = null;
          });
          _prepareFile();
        },
      );
    }
    final path = _filePath;
    if (path == null) {
      return const TimesheetEmptyState(message: 'No PDF file');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PDFView(
            filePath: path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            onRender: (pages) {
              if (!mounted || pages == null) return;
              setState(() => _totalPages = pages);
            },
            onPageChanged: (page, total) {
              if (!mounted) return;
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? _totalPages;
              });
            },
            onError: (message) {
              if (!mounted) return;
              setState(() => _error = message);
            },
          ),
        ),
        if (_totalPages > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Page ${_currentPage + 1} of $_totalPages',
              textAlign: TextAlign.center,
              style: TimesheetModuleTypography.caption(),
            ),
          ),
      ],
    );
  }
}

/// Full-screen timesheet / generated PDF preview.
class TmPdfBytesPreviewScreen extends ConsumerStatefulWidget {
  const TmPdfBytesPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
    this.projectId,
    this.projectName,
    this.allowSignTimesheet = true,
  });

  final Uint8List pdfBytes;
  final String title;
  final String? projectId;
  final String? projectName;

  /// When false (e.g. Timesheet documents viewer), hide Sign Timesheet.
  final bool allowSignTimesheet;

  @override
  ConsumerState<TmPdfBytesPreviewScreen> createState() =>
      _TmPdfBytesPreviewScreenState();
}

class _TmPdfBytesPreviewScreenState
    extends ConsumerState<TmPdfBytesPreviewScreen> {
  bool _openingSign = false;

  String get _fileName {
    final name = widget.title.trim();
    if (name.toLowerCase().endsWith('.pdf')) return name;
    return '$name.pdf';
  }

  Future<void> _share() {
    return TmSharePdfSheet.shareExternal(
      context,
      widget.pdfBytes,
      _fileName,
    );
  }

  Future<void> _download() {
    return TmSharePdfSheet.downloadToDevice(
      context,
      widget.pdfBytes,
      _fileName,
    );
  }

  Future<void> _signTimesheet() async {
    if (_openingSign) return;
    setState(() => _openingSign = true);
    try {
      final file = await TmSharePdfSheet.writeTempFile(
        widget.pdfBytes,
        _fileName,
      );
      if (!mounted) return;

      final pickerResult = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => SignZonePickerScreen(
            pdfFile: file,
            fileName: _fileName,
            timesheetMode: true,
          ),
        ),
      );
      if (pickerResult == null || !mounted) return;

      final signedBytes = pickerResult['pdfBytes'];
      final approvalCells = pickerResult['approvalCells'];
      final pageCount = pickerResult['pageCount'] as int? ?? 0;
      if (signedBytes is! Uint8List) return;
      final cells = approvalCells is List<TimesheetApprovalCell>
          ? approvalCells
          : const <TimesheetApprovalCell>[];

      final recipients = await Navigator.of(context).push<List<ChatUser>>(
        MaterialPageRoute(
          builder: (_) => const RecipientPickerScreen(
            stampNeeded: true,
            maxSignees: 2,
            blockCurrentUser: true,
          ),
        ),
      );
      if (recipients == null || recipients.isEmpty || !mounted) return;

      await _uploadApproval(
        signedBytes: signedBytes,
        cells: cells,
        pageCount: pageCount,
        recipients: recipients,
      );
    } finally {
      if (mounted) setState(() => _openingSign = false);
    }
  }

  Future<void> _uploadApproval({
    required Uint8List signedBytes,
    required List<TimesheetApprovalCell> cells,
    required int pageCount,
    required List<ChatUser> recipients,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final temp = await TmSharePdfSheet.writeTempFile(signedBytes, _fileName);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final me = uid != null ? await UserRepository.instance.getUser(uid) : null;
      await TimesheetApprovalRepository.instance.create(
        pdfFile: File(temp.path),
        fileName: _fileName,
        ownerName: me?.name ?? 'User',
        projectId: widget.projectId ?? '',
        projectName: widget.projectName ?? '',
        pageCount: pageCount,
        recipients: [
          for (final user in recipients) (uid: user.uid, name: user.name),
        ],
        cells: cells,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // progress

      final names = recipients.map((u) => u.name).toList();
      final snack = names.length >= 2
          ? 'Sent to ${names[0]} & ${names[1]}'
          : 'Sent to ${names.first}';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == TimesheetRouteNames.home || route.isFirst,
      );
      messenger.showSnackBar(SnackBar(content: Text(snack)));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagAsync = ref.watch(timesheetApprovalEnabledProvider);
    final showSign =
        widget.allowSignTimesheet && (flagAsync.asData?.value ?? false);

    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TmModuleGlassHeader(title: widget.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: _PdfActionButton(
                    icon: PhosphorIcons.shareNetwork(),
                    label: 'Share',
                    onTap: _share,
                  ),
                ),
                Expanded(
                  child: _PdfActionButton(
                    icon: PhosphorIcons.download(),
                    label: 'Download',
                    onTap: _download,
                  ),
                ),
                if (showSign)
                  Expanded(
                    child: _PdfActionButton(
                      icon: PhosphorIcons.signature(),
                      label: 'Sign Timesheet',
                      onTap: _openingSign ? null : _signTimesheet,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: TmPdfFileViewer(
                pdfBytes: widget.pdfBytes,
                fileName: widget.title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfActionButton extends StatelessWidget {
  const _PdfActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.iconSurface,
                shape: BoxShape.circle,
                border: Border.all(color: TimesheetModuleColors.glassBorder),
              ),
              child: Icon(icon, size: 26, color: TimesheetModuleColors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TimesheetModuleTypography.caption().copyWith(
                fontWeight: FontWeight.w600,
                color: TimesheetModuleColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
