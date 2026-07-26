import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:flutter/material.dart';

/// WhatsApp-style collapsing header: large title + actions + search scroll together.
/// Title shrinks on scroll; search stays in the pinned min extent.
class WhatsAppChatListHeaderDelegate extends SliverPersistentHeaderDelegate {
  WhatsAppChatListHeaderDelegate({
    required this.searchController,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onOpenMenu,
    this.title = 'Discuss',
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onNewChat;
  final VoidCallback onOpenMenu;
  final String title;

  static const double _expandedTitleBlock = 72;
  static const double _collapsedTitleBlock = 48;
  static const double _searchBlock = 56;
  static const double _glassPad = 10;

  @override
  double get maxExtent =>
      _glassPad + _expandedTitleBlock + _searchBlock + _glassPad;

  @override
  double get minExtent =>
      _glassPad + _collapsedTitleBlock + _searchBlock + _glassPad;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = (maxExtent - minExtent).clamp(1.0, 2000.0);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final titleSize = 34.0 - (12.0 * t);
    final titleHeight =
        _expandedTitleBlock - ((_expandedTitleBlock - _collapsedTitleBlock) * t);

    return Material(
      color: Colors.transparent,
      child: AdaptiveGlassLayer(
        borderRadius: BorderRadius.zero,
        sigma: overlapsContent || shrinkOffset > 4 ? 16 : 8,
        fallbackColor: ChatGlassTheme.waterFill,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06 + (0.08 * t)),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.22 + (0.12 * t)),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, _glassPad, 8, _glassPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: titleHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ChatGlassIconButton(
                      icon: Icons.more_horiz,
                      tooltip: 'More',
                      onPressed: onOpenMenu,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          title,
                          style: ChatGlassTheme.title(fontSize: titleSize),
                        ),
                      ),
                    ),
                    ChatGlassIconButton(
                      icon: Icons.add,
                      tooltip: 'New chat',
                      iconColor: Colors.white,
                      onPressed: onNewChat,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AdaptiveGlassLayer(
                  borderRadius: BorderRadius.circular(22),
                  sigma: 12,
                  fallbackColor: ChatGlassTheme.waterFillStrong,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => onSearchChanged(),
                      style: ChatGlassTheme.body(fontSize: 16),
                      cursorColor: Colors.white,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: ChatGlassTheme.muted(fontSize: 16),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 22,
                        ),
                        filled: true,
                        fillColor: ChatGlassTheme.waterFill,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged();
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant WhatsAppChatListHeaderDelegate oldDelegate) {
    return searchController != oldDelegate.searchController ||
        title != oldDelegate.title;
  }
}
