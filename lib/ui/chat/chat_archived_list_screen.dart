import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/blue_geometric_background.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:el_race/ui/chat/widgets/chat_top_glass_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../chat/chat.dart';
import 'chat_screen.dart';

/// Archived conversations on water glass.
class ChatArchivedListScreen extends StatelessWidget {
  const ChatArchivedListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: Column(
          children: [
            const ChatTopGlassAppBar(),
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: Row(
                  children: [
                    ChatGlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Archived',
                      style: ChatGlassTheme.title(fontSize: 22),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text('Not signed in',
                          style: ChatGlassTheme.muted()),
                    )
                  : StreamBuilder<List<UserChat>>(
                      stream: ChatRepository.instance
                          .subscribeToArchivedUserChats(uid),
                      builder: (context, snap) {
                        final chats = snap.data ?? const [];
                        if (snap.connectionState == ConnectionState.waiting &&
                            chats.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: ChatGlassTheme.gold,
                            ),
                          );
                        }
                        if (chats.isEmpty) {
                          return Center(
                            child: Text(
                              'No archived chats',
                              style: ChatGlassTheme.muted(fontSize: 16),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final userChat = chats[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          chatId: userChat.chatId,
                                          title: userChat.title ?? 'Chat',
                                          chatType: userChat.type,
                                          peerUid: userChat.peerUid,
                                          supportGroupTitle:
                                              userChat.supportGroupTitle,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Ink(
                                    decoration:
                                        ChatGlassTheme.waterCardDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        child: Text(
                                          (userChat.title ?? '?')
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: ChatGlassTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        userChat.title ?? 'Chat',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ChatGlassTheme.body(
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Archived',
                                        style: ChatGlassTheme.muted(),
                                      ),
                                      trailing: ChatGlassButton(
                                        label: 'Unarchive',
                                        variant: ChatGlassButtonVariant.silver,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        fontSize: 12,
                                        onPressed: () {
                                          ChatRepository.instance.toggleArchive(
                                              userChat.chatId, false);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
