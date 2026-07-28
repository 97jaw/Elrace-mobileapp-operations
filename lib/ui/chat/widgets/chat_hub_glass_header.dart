import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:flutter/material.dart';

/// Discuss-style water-glass header for Groups / Files / Calls hubs.
/// Title row + search (+ optional bottom slot e.g. Files tabs).
class ChatHubGlassHeader extends StatelessWidget {
  const ChatHubGlassHeader({
    super.key,
    required this.title,
    required this.searchController,
    required this.onSearchChanged,
    this.onOpenMenu,
    this.trailing,
    this.subtitle,
    this.bottom,
    this.searchHint = 'Search',
  });

  final String title;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback? onOpenMenu;
  final Widget? trailing;
  final String? subtitle;
  final Widget? bottom;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AdaptiveGlassLayer(
        borderRadius: BorderRadius.zero,
        sigma: 16,
        fallbackColor: ChatGlassTheme.waterFill,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ChatGlassIconButton(
                      icon: Icons.more_horiz,
                      tooltip: 'More',
                      onPressed: onOpenMenu ?? () {},
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          title,
                          style: ChatGlassTheme.title(fontSize: 28),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              if (subtitle != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(subtitle!, style: ChatGlassTheme.muted()),
                ),
              ],
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
                        hintText: searchHint,
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
              if (bottom != null) ...[
                const SizedBox(height: 8),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
