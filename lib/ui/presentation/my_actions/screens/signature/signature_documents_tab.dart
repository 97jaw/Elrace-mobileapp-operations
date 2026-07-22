import 'dart:async';
import 'dart:io';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../chat/models/chat_user.dart';
import '../../../../../chat/models/message.dart';
import '../../../../../chat/repositories/user_repository.dart';
import '../../../../../ui/chat/screens/sign_document_screen.dart';
import '../../../../../ui/chat/screens/sign_zone_picker_screen.dart';
import '../../data/models/signature_document.dart';
import '../../data/repositories/signature_actions_repository.dart';
import '../../data/repositories/signature_documents_repository.dart';
import '../../theme/signature_theme.dart';
import '../../widgets/signature/signature_document_card.dart';
import 'recipient_picker_screen.dart';
import 'signature_document_viewer_screen.dart';

/// Unified row for Documents tab (personal uploads + chat-related docs).
class _DocRow {
  final String id;
  final String fileName;
  final String fileUrl;
  final DateTime createdAt;
  final SignatureDocumentStatus status;
  final String? recipientName;
  final SignatureDocument? personal;
  final SignatureActionItem? action;

  const _DocRow({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.createdAt,
    required this.status,
    this.recipientName,
    this.personal,
    this.action,
  });

  SignatureDocument asCardModel() {
    if (personal != null) return personal!;
    return SignatureDocument(
      id: id,
      ownerUid: '',
      fileName: fileName,
      fileUrl: fileUrl,
      status: status,
      createdAt: createdAt,
      recipientName: recipientName,
      signedPdfUrl: action?.message.signedPdfUrl,
      chatId: action?.chatId,
      messageId: action?.message.id,
    );
  }
}

/// Documents tab: all docs related to the logged-in user, with pagination.
/// Upload is only via the Home tab + button (no duplicate CTAs here).
class SignatureDocumentsTab extends StatefulWidget {
  const SignatureDocumentsTab({super.key});

  @override
  State<SignatureDocumentsTab> createState() => SignatureDocumentsTabState();
}

class SignatureDocumentsTabState extends State<SignatureDocumentsTab> {
  static const int _pageSize = 15;

  bool _busy = false;
  int _visibleCount = _pageSize;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<_DocRow>>? _sub;
  List<_DocRow> _allRows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _sub = _watchCombined().listen((rows) {
      if (!mounted) return;
      setState(() {
        _allRows = rows;
        _loading = false;
        if (_visibleCount > rows.length && rows.isNotEmpty) {
          _visibleCount = rows.length;
        }
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _allRows = const [];
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void startUpload() => _pickPdf();

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= _allRows.length) return;
    setState(() {
      _visibleCount =
          (_visibleCount + _pageSize).clamp(0, _allRows.length);
    });
  }

  Stream<List<_DocRow>> _watchCombined() {
    final actions =
        SignatureActionsRepository.instance.watchMySignatureActions();
    final personal =
        SignatureDocumentsRepository.instance.watchMyDocuments();

    return Rx.combineLatest2<List<SignatureActionItem>,
        List<SignatureDocument>, List<_DocRow>>(
      actions,
      personal,
      (actionItems, personalDocs) {
        final rows = <_DocRow>[];
        final seenKeys = <String>{};

        for (final doc in personalDocs) {
          final key = doc.messageId != null
              ? 'msg:${doc.chatId}:${doc.messageId}'
              : 'doc:${doc.id}';
          seenKeys.add(key);
          rows.add(_DocRow(
            id: doc.id,
            fileName: doc.fileName,
            fileUrl: doc.status == SignatureDocumentStatus.signed
                ? (doc.signedPdfUrl ?? doc.fileUrl)
                : doc.fileUrl,
            createdAt: doc.createdAt,
            status: doc.status,
            recipientName: doc.recipientName,
            personal: doc,
          ));
        }

        for (final item in actionItems) {
          final key = 'msg:${item.chatId}:${item.message.id}';
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          final status = switch (item.bucket) {
            SignatureItemBucket.needsSignature =>
              SignatureDocumentStatus.pendingSelf,
            SignatureItemBucket.waitingForOthers =>
              SignatureDocumentStatus.pendingOther,
            SignatureItemBucket.completed => SignatureDocumentStatus.signed,
            SignatureItemBucket.expired => SignatureDocumentStatus.expired,
          };

          final url = item.message.signStatus == SignStatus.signed
              ? (item.message.signedPdfUrl ?? item.message.mediaUrl ?? '')
              : (item.message.mediaUrl ?? '');

          rows.add(_DocRow(
            id: item.message.id,
            fileName: item.message.fileName ?? 'Document.pdf',
            fileUrl: url,
            createdAt: item.message.createdAt,
            status: status,
            recipientName: item.isSender ? item.peerName : null,
            action: item,
          ));
        }

        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return rows;
      },
    );
  }

  // ─── Upload (triggered only from Home +) ───────────────────

  Future<void> _pickPdf() async {
    if (_busy) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final file = File(path);
    final fileName = result.files.single.name;

    if (!mounted) return;
    await _showZonePickerThenChoose(file, fileName);
  }

  Future<void> _showZonePickerThenChoose(File file, String fileName) async {
    final pickerResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SignZonePickerScreen(pdfFile: file, fileName: fileName),
      ),
    );
    if (pickerResult == null || !mounted) return;

    final signZones = pickerResult['signZones'] as List<SignZone>;
    final pageCount = pickerResult['pageCount'] as int?;

    final choice = await _askUploadPurpose();
    if (choice == null) return;

    if (choice == _UploadPurpose.signMyself) {
      await _selfSign(file, signZones, pageCount);
    } else {
      await _requestSignature(file, signZones, pageCount);
    }
  }

  Future<_UploadPurpose?> _askUploadPurpose() {
    return showModalBottomSheet<_UploadPurpose>(
      context: context,
      backgroundColor: SignatureTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.tr)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.tw, 20.th, 20.tw, 12.th),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What would you like to do?',
                    style: SignatureTheme.sectionTitle),
                SizedBox(height: 4.th),
                Text('Choose how this document should be signed.',
                    style: SignatureTheme.cardSubtitle),
                SizedBox(height: 16.th),
                _PurposeOption(
                  icon: Icons.edit_rounded,
                  title: 'Sign it myself',
                  subtitle: 'Draw your signature and stamp the zones you set.',
                  onTap: () =>
                      Navigator.pop(sheetContext, _UploadPurpose.signMyself),
                ),
                SizedBox(height: 10.th),
                _PurposeOption(
                  icon: Icons.send_rounded,
                  title: 'Request signatures',
                  subtitle:
                      'Pick one or more signees — they sign one by one with chat notifications.',
                  onTap: () => Navigator.pop(
                      sheetContext, _UploadPurpose.requestSignature),
                ),
                SizedBox(height: 8.th),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selfSign(
      File file, List<SignZone> signZones, int? pageCount) async {
    setState(() => _busy = true);
    try {
      final draft = await SignatureDocumentsRepository.instance
          .createSelfSignDraft(
              pdfFile: file, signZones: signZones, pageCount: pageCount);
      if (!mounted) return;
      _openSelfSignDraft(draft);
    } catch (e) {
      _showMessage('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestSignature(
      File file, List<SignZone> signZones, int? pageCount) async {
    final recipients = await Navigator.push<List<ChatUser>>(
      context,
      MaterialPageRoute(builder: (_) => const RecipientPickerScreen()),
    );
    if (recipients == null || recipients.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final currentUser = currentUid != null
          ? await UserRepository.instance.getUser(currentUid)
          : null;

      await SignatureDocumentsRepository.instance.createSendForSignature(
        pdfFile: file,
        signZones: signZones,
        recipients: recipients,
        currentUserName: currentUser?.name ?? 'User',
        pageCount: pageCount,
      );
      final label = recipients.length == 1
          ? recipients.first.name
          : '${recipients.first.name} +${recipients.length - 1} others';
      _showMessage('Sent to $label for signature');
    } catch (e) {
      _showMessage('Failed to send: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSelfSignDraft(SignatureDocument doc) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final message = Message(
      id: doc.id,
      senderId: currentUid,
      type: MessageType.signableDoc,
      mediaUrl: doc.fileUrl,
      fileName: doc.fileName,
      createdAt: doc.createdAt,
      clientMsgId: doc.id,
      signZones: doc.signZones,
      signStatus: SignStatus.pending,
      pageCount: doc.pageCount,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignDocumentScreen(
          message: message,
          chatId: '',
          onSigned: (bytes) => SignatureDocumentsRepository.instance
              .markSelfSigned(
                  docId: doc.id, signedBytes: bytes, fileName: doc.fileName),
        ),
      ),
    );
  }

  void _openRow(_DocRow row) {
    if (row.action != null) {
      final item = row.action!;
      if (item.bucket == SignatureItemBucket.needsSignature) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SignDocumentScreen(
              message: item.message,
              chatId: item.chatId,
            ),
          ),
        );
        return;
      }
    }
    if (row.personal?.status == SignatureDocumentStatus.pendingSelf) {
      _openSelfSignDraft(row.personal!);
      return;
    }

    final statusLabel = switch (row.status) {
      SignatureDocumentStatus.draft => 'Draft',
      SignatureDocumentStatus.pendingSelf => 'Awaiting your signature',
      SignatureDocumentStatus.pendingOther =>
        'Waiting for ${row.recipientName ?? 'recipient'}',
      SignatureDocumentStatus.signed => 'Signed',
      SignatureDocumentStatus.expired => 'Expired',
    };
    final statusColor = switch (row.status) {
      SignatureDocumentStatus.pendingSelf => SignatureTheme.pending,
      SignatureDocumentStatus.pendingOther => SignatureTheme.waiting,
      SignatureDocumentStatus.signed => SignatureTheme.signed,
      SignatureDocumentStatus.expired => SignatureTheme.expired,
      _ => SignatureTheme.textMuted,
    };

    if (row.fileUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureDocumentViewerScreen(
          pdfUrl: row.fileUrl,
          title: row.fileName,
          statusLabel: statusLabel,
          statusColor: statusColor,
        ),
      ),
    );
  }

  Future<void> _shareRow(_DocRow row) async {
    if (row.fileUrl.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(row.fileUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${row.fileName}');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      }
    } catch (e) {
      _showMessage('Share failed: $e', isError: true);
    }
  }

  Future<void> _downloadRow(_DocRow row) async {
    if (row.fileUrl.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(row.fileUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final dir = await getApplicationDocumentsDirectory();
      final signaturesDir = Directory('${dir.path}/Signatures');
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
      }
      final file = File('${signaturesDir.path}/${row.fileName}');
      await file.writeAsBytes(response.bodyBytes);
      _showMessage('Saved to app storage: Signatures/${row.fileName}');
    } catch (e) {
      _showMessage('Download failed: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(_DocRow row) async {
    if (row.personal == null) {
      _showMessage('Chat documents can’t be deleted from here');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${row.fileName}" from your Documents list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete',
                style: TextStyle(color: SignatureTheme.expired)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SignatureDocumentsRepository.instance.deleteDocument(row.personal!.id);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? SignatureTheme.expired : SignatureTheme.signed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _allRows.take(_visibleCount).toList();
    final hasMore = _visibleCount < _allRows.length;

    return Column(
      children: [
        _DocumentsHeader(),
        Expanded(
          child: Stack(
            children: [
              if (_loading)
                const Center(
                  child:
                      CircularProgressIndicator(color: SignatureTheme.brown),
                )
              else if (_allRows.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.tr),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            size: 64.tsp, color: SignatureTheme.khaki),
                        SizedBox(height: 16.th),
                        Text('No documents yet',
                            style: SignatureTheme.sectionTitle),
                        SizedBox(height: 6.th),
                        Text(
                          'Use the + button on Home to upload a PDF\nand sign it yourself or send for signature.',
                          textAlign: TextAlign.center,
                          style: SignatureTheme.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                )
              else
                RefreshIndicator(
                  color: SignatureTheme.brown,
                  onRefresh: () async {
                    setState(() => _visibleCount = _pageSize);
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 24.th),
                    itemCount: visible.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _loadMore();
                        });
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.th),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: SignatureTheme.brown,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }
                      final row = visible[index];
                      return SignatureDocumentCard(
                        document: row.asCardModel(),
                        onTap: () => _openRow(row),
                        onShare: () => _shareRow(row),
                        onDownload: () => _downloadRow(row),
                        onDelete: row.personal != null
                            ? () => _confirmDelete(row)
                            : null,
                      );
                    },
                  ),
                ),
              if (_busy)
                Container(
                  color: Colors.black.withValues(alpha: 0.15),
                  child: const Center(
                    child:
                        CircularProgressIndicator(color: SignatureTheme.brown),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: SubAppGlassAppBar.extent(context),
          child: const SubAppGlassAppBar(
            lightSurfaceTransparentPill: true,
            logoOpacity: 1,
          ),
        ),
        SizedBox(
          height: 48.th,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.tw, 0, 8.tw, 4.th),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: SignatureTheme.textDark,
                    size: 18.tsp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 40.tw,
                    minHeight: 40.tw,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Documents',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22.tsp,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: SignatureTheme.textDark,
                    ),
                  ),
                ),
                SizedBox(width: 40.tw),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _UploadPurpose { signMyself, requestSignature }

class _PurposeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PurposeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.tr),
      child: Container(
        padding: EdgeInsets.all(14.tr),
        decoration: BoxDecoration(
          color: SignatureTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(16.tr),
          border: Border.all(color: SignatureTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.tr),
              decoration: BoxDecoration(
                color: SignatureTheme.khakiLight,
                borderRadius: BorderRadius.circular(12.tr),
              ),
              child: Icon(icon, color: SignatureTheme.brownDeep, size: 20.tsp),
            ),
            SizedBox(width: 12.tw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SignatureTheme.cardTitle),
                  SizedBox(height: 2.th),
                  Text(subtitle, style: SignatureTheme.cardSubtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: SignatureTheme.brown),
          ],
        ),
      ),
    );
  }
}
