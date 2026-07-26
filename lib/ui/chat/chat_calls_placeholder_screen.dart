import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_hub_glass_header.dart';
import 'package:flutter/material.dart';

/// Calls tab — Discuss-style header only; placeholder content below.
class ChatCallsPlaceholderScreen extends StatefulWidget {
  const ChatCallsPlaceholderScreen({super.key});

  @override
  State<ChatCallsPlaceholderScreen> createState() =>
      _ChatCallsPlaceholderScreenState();
}

class _ChatCallsPlaceholderScreenState
    extends State<ChatCallsPlaceholderScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatHubGlassHeader(
          title: 'Calls',
          subtitle: 'Voice and video',
          searchController: _searchController,
          onSearchChanged: () => setState(() {}),
          searchHint: 'Search calls',
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call_outlined,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Calls coming soon',
                    style: ChatGlassTheme.body(
                      fontSize: 20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voice and video calls will appear here. '
                    'This tab is read-only for now.',
                    textAlign: TextAlign.center,
                    style: ChatGlassTheme.muted(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
