import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_calls_placeholder_screen.dart';
import 'chat_files_hub_screen.dart';
import 'chat_groups_hub_screen.dart';
import 'chat_list_screen.dart';
import 'widgets/blue_geometric_background.dart';
import 'widgets/chat_top_glass_app_bar.dart';

/// Chat module shell: blue wallpaper + 4-tab frosted pill (Discuss / Groups / Files / Calls).
class ChatShellScreen extends StatefulWidget {
  const ChatShellScreen({super.key});

  @override
  State<ChatShellScreen> createState() => _ChatShellScreenState();
}

class _ChatShellScreenState extends State<ChatShellScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: Column(
          children: [
            const ChatTopGlassAppBar(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(
                      index: _tabIndex,
                      children: const [
                        ChatListScreen(embeddedInShell: true),
                        ChatGroupsHubScreen(),
                        ChatFilesHubScreen(),
                        ChatCallsPlaceholderScreen(),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: bottomInset > 0 ? bottomInset * 0.3 + 8 : 12,
                    child: _ChatGlassPillBottomBar(
                      selectedIndex: _tabIndex,
                      onSelected: (i) => setState(() => _tabIndex = i),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating water-glass capsule — frosted active / soft inactive.
class _ChatGlassPillBottomBar extends StatelessWidget {
  const _ChatGlassPillBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Discuss'),
    (Icons.groups_outlined, Icons.groups, 'Groups'),
    (Icons.folder_outlined, Icons.folder, 'Files'),
    (Icons.call_outlined, Icons.call, 'Calls'),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return AdaptiveGlassLayer(
      borderRadius: radius,
      sigma: 20,
      fallbackColor: ChatGlassTheme.waterFillStrong,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: ChatGlassTheme.waterFill,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2848).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _PillTab(
                  label: _tabs[i].$3,
                  icon: _tabs[i].$1,
                  selectedIcon: _tabs[i].$2,
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: selected ? ChatGlassTheme.waterActiveGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.55 : 0.22),
              width: selected ? 1 : 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: Colors.white.withValues(alpha: selected ? 1 : 0.75),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
