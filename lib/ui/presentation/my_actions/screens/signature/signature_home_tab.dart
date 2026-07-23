import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../chat/models/message.dart';
import '../../../../../ui/chat/screens/sign_document_screen.dart';
import '../../data/models/signature_document.dart';
import '../../data/repositories/signature_actions_repository.dart';
import '../../data/repositories/signature_documents_repository.dart';
import '../../theme/signature_theme.dart';
import '../../widgets/signature/signature_action_tile.dart';
import 'signature_document_viewer_screen.dart';

enum _HomeFilter { all, needsSignature, waiting, completed }

/// DocuSign-style landing: brown header from top of screen + recent docs.
class SignatureHomeTab extends StatefulWidget {
  final VoidCallback? onFabPressed;

  const SignatureHomeTab({super.key, this.onFabPressed});

  @override
  State<SignatureHomeTab> createState() => SignatureHomeTabState();
}

class SignatureHomeTabState extends State<SignatureHomeTab> {
  _HomeFilter _filter = _HomeFilter.all;

  List<SignatureActionItem> _applyFilter(List<SignatureActionItem> items) {
    switch (_filter) {
      case _HomeFilter.all:
        return items;
      case _HomeFilter.needsSignature:
        return items
            .where((i) => i.bucket == SignatureItemBucket.needsSignature)
            .toList();
      case _HomeFilter.waiting:
        return items
            .where((i) => i.bucket == SignatureItemBucket.waitingForOthers)
            .toList();
      case _HomeFilter.completed:
        return items
            .where((i) => i.bucket == SignatureItemBucket.completed)
            .toList();
    }
  }

  void _openItem(SignatureActionItem item) {
    switch (item.bucket) {
      case SignatureItemBucket.needsSignature:
        final personal = item.personalDoc;
        final useChatPipeline = item.chatId.isNotEmpty;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SignDocumentScreen(
              message: item.message,
              chatId: item.chatId,
              onSigned: useChatPipeline || personal == null
                  ? null
                  : (bytes) => SignatureDocumentsRepository.instance
                      .markSelfSigned(
                        docId: personal.id,
                        signedBytes: bytes,
                        fileName: personal.fileName,
                      ),
            ),
          ),
        );
      case SignatureItemBucket.waitingForOthers:
        _openViewer(item,
            statusLabel: 'Waiting for ${item.waitingForDisplayName}',
            statusColor: SignatureTheme.waiting);
      case SignatureItemBucket.completed:
        _openViewer(
          item,
          statusLabel: item.isSender
              ? 'Signed by ${item.peerName}'
              : 'Completed by you',
          statusColor: SignatureTheme.signed,
        );
      case SignatureItemBucket.expired:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This document has expired'),
            backgroundColor: SignatureTheme.expired,
          ),
        );
    }
  }

  void _openViewer(
    SignatureActionItem item, {
    required String statusLabel,
    required Color statusColor,
  }) {
    final url = item.message.signStatus == SignStatus.signed
        ? (item.message.signedPdfUrl ?? item.message.mediaUrl)
        : item.message.mediaUrl;
    if (url == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureDocumentViewerScreen(
          pdfUrl: url,
          title: item.message.fileName ?? 'Document.pdf',
          statusLabel: statusLabel,
          statusColor: statusColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SignatureActionItem>>(
      stream: SignatureActionsRepository.instance.watchMySignatureActions(),
      builder: (context, snapshot) {
        final hasData = snapshot.hasData;
        final loading =
            snapshot.connectionState == ConnectionState.waiting && !hasData;
        final items = snapshot.data ?? const <SignatureActionItem>[];

        final needsSignature = items
            .where((i) => i.bucket == SignatureItemBucket.needsSignature)
            .length;
        final waiting = items
            .where((i) => i.bucket == SignatureItemBucket.waitingForOthers)
            .length;

        final filtered = _applyFilter(items);

        return RefreshIndicator(
          color: SignatureTheme.brown,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _TopBrownSection(
                  needsSignature: needsSignature,
                  waiting: waiting,
                  onNeedsTap: () =>
                      setState(() => _filter = _HomeFilter.needsSignature),
                  onWaitingTap: () =>
                      setState(() => _filter = _HomeFilter.waiting),
                  onFabPressed: widget.onFabPressed,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.tw, 16.th, 16.tw, 8.th),
                  child: Row(
                    children: [
                      Text('Recent Documents',
                          style: SignatureTheme.sectionTitle),
                      const Spacer(),
                      if (_filter != _HomeFilter.all)
                        TextButton(
                          onPressed: () =>
                              setState(() => _filter = _HomeFilter.all),
                          child: Text(
                            'Clear filter',
                            style: SignatureTheme.cardSubtitle.copyWith(
                              color: SignatureTheme.brown,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: SignatureTheme.brown),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(filter: _filter),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 24.th),
                  sliver: SliverList.builder(
                    itemCount: filtered.length.clamp(0, 5),
                    itemBuilder: (context, index) => SignatureActionTile(
                      item: filtered[index],
                      onTap: () => _openItem(filtered[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Brown section from the very top of the screen: logo, back, italic
/// "Signatures", stats, and overlapping + FAB.
class _TopBrownSection extends StatelessWidget {
  final int needsSignature;
  final int waiting;
  final VoidCallback onNeedsTap;
  final VoidCallback onWaitingTap;
  final VoidCallback? onFabPressed;

  const _TopBrownSection({
    required this.needsSignature,
    required this.waiting,
    required this.onNeedsTap,
    required this.onWaitingTap,
    this.onFabPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 28.th),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SignatureTheme.brownDeep,
                SignatureTheme.brown,
                SignatureTheme.khakiDeep,
              ],
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: SubAppGlassAppBar.extent(context),
                child: const SubAppGlassAppBar(
                  transparentPill: true,
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
                          color: Colors.white,
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
                          'Signatures',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22.tsp,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 40.tw),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8.tw, 8.th, 8.tw, 28.th),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onNeedsTap,
                        child: Column(
                          children: [
                            Text(
                              '$needsSignature',
                              style: GoogleFonts.poppins(
                                fontSize: 36.tsp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 6.th),
                            Text(
                              'Needs My Signature',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48.th,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onWaitingTap,
                        child: Column(
                          children: [
                            Text(
                              '$waiting',
                              style: GoogleFonts.poppins(
                                fontSize: 36.tsp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 6.th),
                            Text(
                              'Waiting for Others',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20.tw,
          bottom: 4.th,
          child: Material(
            color: SignatureTheme.khaki,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onFabPressed,
              child: SizedBox(
                width: 52.tr,
                height: 52.tr,
                child: Icon(Icons.add,
                    color: SignatureTheme.brownDeep, size: 28.tsp),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _HomeFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      _HomeFilter.all =>
        'No signature activity yet.\nDocuments related to you will appear here.',
      _HomeFilter.needsSignature => 'Nothing needs your signature right now.',
      _HomeFilter.waiting => 'Nothing is waiting on others right now.',
      _HomeFilter.completed => 'No completed documents yet.',
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.tr),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_outlined, size: 56.tsp, color: SignatureTheme.khaki),
            SizedBox(height: 14.th),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SignatureTheme.cardSubtitle,
            ),
          ],
        ),
      ),
    );
  }
}
