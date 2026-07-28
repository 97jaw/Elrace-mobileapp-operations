import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../chat/chat.dart';
import '../screens/sign_document_screen.dart';

/// Shared Media / Docs / Links tabs for DM and group profile screens.
class ChatSharedContentTabs extends StatelessWidget {
  const ChatSharedContentTabs({
    super.key,
    required this.chatId,
    required this.messages,
    this.showTabBar = true,
    this.showTabView = true,
    this.expandTabView = false,
  });

  final String chatId;
  final List<Message> messages;
  final bool showTabBar;
  final bool showTabView;

  /// When true, [TabBarView] expands to fill remaining space (hub screens).
  final bool expandTabView;

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final media = <_SharedItem>[];
    final docs = <_SharedItem>[];
    final links = <_SharedItem>[];

    for (final m in messages) {
      if (m.type == MessageType.image || m.type == MessageType.video) {
        final url = (m.mediaUrl ?? '').trim();
        if (url.isEmpty) continue;
        media.add(_SharedItem(
          message: m,
          kind: m.type == MessageType.video
              ? _SharedKind.video
              : _SharedKind.image,
          url: url,
          title: m.fileName ?? (m.type == MessageType.video ? 'Video' : 'Photo'),
        ));
      } else if (m.type == MessageType.file ||
          m.type == MessageType.signableDoc) {
        final url = (m.signedPdfUrl ?? m.mediaUrl ?? '').trim();
        docs.add(_SharedItem(
          message: m,
          kind: m.type == MessageType.signableDoc
              ? _SharedKind.signable
              : _SharedKind.doc,
          url: url,
          title: m.fileName ??
              (m.type == MessageType.signableDoc
                  ? 'Signable document'
                  : 'Document'),
          subtitle: m.fileSize != null ? _formatBytes(m.fileSize!) : null,
        ));
      } else if (m.type == MessageType.text) {
        final text = (m.text ?? '').trim();
        if (text.isEmpty) continue;
        for (final match in _urlRegex.allMatches(text)) {
          final raw = match.group(0)!;
          links.add(_SharedItem(
            message: m,
            kind: _SharedKind.link,
            url: raw.startsWith('http') ? raw : 'https://$raw',
            title: raw,
          ));
        }
      }
    }

    final tabBar = TabBar(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      tabs: const [
        Tab(text: 'Media'),
        Tab(text: 'Docs'),
        Tab(text: 'Links'),
      ],
    );

    final tabView = TabBarView(
      children: [
        _MediaGrid(items: media),
        _DocsList(chatId: chatId, items: docs),
        _LinksList(items: links),
      ],
    );

    // Parent already provides [DefaultTabController] when splitting bar/view.
    final needsController = showTabBar && showTabView;
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTabBar) tabBar,
        if (showTabView)
          expandTabView
              ? Expanded(child: tabView)
              : SizedBox(height: 320, child: tabView),
      ],
    );

    if (!needsController) return body;
    return DefaultTabController(length: 3, child: body);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum _SharedKind { image, video, doc, signable, link }

class _SharedItem {
  const _SharedItem({
    required this.message,
    required this.kind,
    required this.url,
    required this.title,
    this.subtitle,
  });

  final Message message;
  final _SharedKind kind;
  final String url;
  final String title;
  final String? subtitle;
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<_SharedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyShared(label: 'No media yet');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _openPreview(context, item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: item.message.thumbUrl?.isNotEmpty == true
                      ? item.message.thumbUrl!
                      : item.url,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.08),
                    child: const Icon(Icons.broken_image_outlined,
                        color: ChatGlassTheme.textSecondary),
                  ),
                ),
                if (item.kind == _SharedKind.video)
                  const Center(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0x77000000),
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPreview(BuildContext context, _SharedItem item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: item.url,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocsList extends StatelessWidget {
  const _DocsList({required this.chatId, required this.items});

  final String chatId;
  final List<_SharedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyShared(label: 'No documents yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: Colors.white.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: Icon(
              item.kind == _SharedKind.signable
                  ? Icons.draw_outlined
                  : Icons.insert_drive_file_outlined,
              color: ChatGlassTheme.gold,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ChatGlassTheme.body(),
          ),
          subtitle: Text(
            item.subtitle ??
                (item.kind == _SharedKind.signable
                    ? 'Signable document'
                    : 'Document'),
            style: ChatGlassTheme.muted(),
          ),
          onTap: () async {
            if (item.kind == _SharedKind.signable) {
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignDocumentScreen(
                    chatId: chatId,
                    message: item.message,
                  ),
                ),
              );
              return;
            }
            final uri = Uri.tryParse(item.url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList({required this.items});

  final List<_SharedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyShared(label: 'No links yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: Colors.white.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: const Icon(Icons.link, color: ChatGlassTheme.gold),
          ),
          title: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ChatGlassTheme.accent(fontSize: 14),
          ),
          subtitle: Text(
            _formatDate(item.message.createdAt),
            style: ChatGlassTheme.muted(fontSize: 12),
          ),
          onTap: () async {
            final uri = Uri.tryParse(item.url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _EmptyShared extends StatelessWidget {
  const _EmptyShared({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: ChatGlassTheme.muted(fontSize: 15)),
    );
  }
}
