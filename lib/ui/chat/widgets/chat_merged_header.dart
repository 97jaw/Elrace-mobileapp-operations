import 'dart:ui';

import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:el_race/ui/chat/widgets/chat_top_glass_app_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Navy + silver glass card wrapping chat screen header content.
class ChatMergedHeaderShell extends StatelessWidget {
  const ChatMergedHeaderShell({
    super.key,
    required this.child,
    this.bottomRadius = 20,
  });

  final Widget child;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(bottomRadius.r),
      ),
      child: child,
    );
  }
}

/// Collapsing header for chat list: title + groups/support row + search.
class ChatListCollapsingHeader extends StatelessWidget {
  const ChatListCollapsingHeader({
    super.key,
    required this.tabIndexListenable,
    required this.groups,
    required this.supportGroups,
    required this.searchController,
    required this.searchExpanded,
    required this.onTabChanged,
    required this.onGroupTap,
    required this.onSupportTap,
    required this.onSearchClear,
    required this.shrinkRatio,
    required this.shrinkOffset,
  });

  final ValueNotifier<int> tabIndexListenable;
  final List<UserChat> groups;
  final List<Chat> supportGroups;
  final TextEditingController searchController;
  final ValueNotifier<bool> searchExpanded;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<UserChat> onGroupTap;
  final ValueChanged<Chat> onSupportTap;
  final VoidCallback onSearchClear;
  final double shrinkRatio;
  final double shrinkOffset;

  static const double _scrollCollapseOffset = 20;

  static double filterExpandedHeight = 100.h;
  static double filterCollapsedHeight = 72.h;
  static double filterSearchHeight = 88.h;

  @override
  Widget build(BuildContext context) {
    final scrolled = shrinkOffset > _scrollCollapseOffset;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<bool>(
          valueListenable: searchExpanded,
          builder: (context, expanded, _) {
            return _ChatFilterRow(
              maxHeight: constraints.maxHeight,
              tabIndexListenable: tabIndexListenable,
              groups: groups,
              supportGroups: supportGroups,
              searchController: searchController,
              searchExpanded: expanded,
              scrolled: scrolled,
              onTabChanged: onTabChanged,
              onGroupTap: onGroupTap,
              onSupportTap: onSupportTap,
              onToggleSearch: () =>
                  searchExpanded.value = !searchExpanded.value,
              onSearchClear: () {
                searchController.clear();
                onSearchClear();
                searchExpanded.value = false;
              },
            );
          },
        );
      },
    );
  }
}

class ChatListHeaderDelegate extends SliverPersistentHeaderDelegate {
  ChatListHeaderDelegate({
    required double topBarExtent,
    required this.tabIndexListenable,
    required this.groups,
    required this.supportGroups,
    required this.searchController,
    required this.searchExpanded,
    required this.onTabChanged,
    required this.onGroupTap,
    required this.onSupportTap,
    required this.onSearchClear,
  }) : _topBarExtent = topBarExtent;

  final double _topBarExtent;
  final ValueNotifier<int> tabIndexListenable;
  final List<UserChat> groups;
  final List<Chat> supportGroups;
  final TextEditingController searchController;
  final ValueNotifier<bool> searchExpanded;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<UserChat> onGroupTap;
  final ValueChanged<Chat> onSupportTap;
  final VoidCallback onSearchClear;

  double _filterExtent(bool search) {
    if (search) return ChatListCollapsingHeader.filterSearchHeight;
    return ChatListCollapsingHeader.filterExpandedHeight;
  }

  double _filterMinExtent() => ChatListCollapsingHeader.filterCollapsedHeight;

  @override
  double get minExtent => _topBarExtent + _filterMinExtent();

  @override
  double get maxExtent =>
      _topBarExtent + _filterExtent(searchExpanded.value);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final topExtent = ChatTopGlassAppBar.extent(context);
    final filterMax = _filterExtent(searchExpanded.value);
    final filterMin = _filterMinExtent();
    final totalMax = topExtent + filterMax;
    final totalMin = topExtent + filterMin;
    final totalH = (totalMax - shrinkOffset).clamp(totalMin, totalMax);
    final filterH = (totalH - topExtent).clamp(0.0, filterMax);

    final extentSpan = filterMax - filterMin;
    final ratio = extentSpan > 0
        ? ((filterMax - filterH) / extentSpan).clamp(0.0, 1.0)
        : 0.0;
    final filterShrink = filterMax - filterH;

    return SizedBox(
      height: totalH,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChatUnifiedHeaderBackdrop.layer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChatTopGlassAppBar(),
                SizedBox(
                  height: filterH,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 12.w, 6.h),
                    child: ChatListCollapsingHeader(
                      tabIndexListenable: tabIndexListenable,
                      groups: groups,
                      supportGroups: supportGroups,
                      searchController: searchController,
                      searchExpanded: searchExpanded,
                      onTabChanged: onTabChanged,
                      onGroupTap: onGroupTap,
                      onSupportTap: onSupportTap,
                      onSearchClear: onSearchClear,
                      shrinkRatio: ratio,
                      shrinkOffset: filterShrink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ChatListHeaderDelegate oldDelegate) {
    return oldDelegate.groups.length != groups.length ||
        oldDelegate.supportGroups.length != supportGroups.length ||
        oldDelegate.searchExpanded.value != searchExpanded.value;
  }
}

class _ChatFilterRow extends StatelessWidget {
  const _ChatFilterRow({
    required this.maxHeight,
    required this.tabIndexListenable,
    required this.groups,
    required this.supportGroups,
    required this.searchController,
    required this.searchExpanded,
    required this.scrolled,
    required this.onTabChanged,
    required this.onGroupTap,
    required this.onSupportTap,
    required this.onToggleSearch,
    required this.onSearchClear,
  });

  final double maxHeight;
  final ValueNotifier<int> tabIndexListenable;
  final List<UserChat> groups;
  final List<Chat> supportGroups;
  final TextEditingController searchController;
  final bool searchExpanded;
  final bool scrolled;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<UserChat> onGroupTap;
  final ValueChanged<Chat> onSupportTap;
  final VoidCallback onToggleSearch;
  final VoidCallback onSearchClear;

  @override
  Widget build(BuildContext context) {
    final usable = maxHeight.clamp(0.0, double.infinity);
    final navH = 28.h.clamp(0.0, usable * 0.38);
    final gap = 4.h;

    if (scrolled || usable < 54.h) {
      if (searchExpanded && usable >= 36.h) {
        return SizedBox(
          height: usable,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _InlineSearchField(
                  controller: searchController,
                  onClear: onSearchClear,
                ),
              ),
              SizedBox(width: 8.w),
              _SearchToggleButton(
                expanded: true,
                onTap: onToggleSearch,
              ),
            ],
          ),
        );
      }
      final compactNavH = (usable * 0.42).clamp(24.h, 30.h);
      final bubbleH = (usable - compactNavH - gap).clamp(0.0, usable);
      return SizedBox(
        height: usable,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: compactNavH,
              child: ValueListenableBuilder<int>(
                valueListenable: tabIndexListenable,
                builder: (context, tabIndex, _) {
                  return _NavTitleRow(
                    tabIndex: tabIndex,
                    searchExpanded: false,
                    compact: true,
                    onTabChanged: onTabChanged,
                    onToggleSearch: onToggleSearch,
                  );
                },
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: bubbleH,
              child: ValueListenableBuilder<int>(
                valueListenable: tabIndexListenable,
                builder: (context, tabIndex, _) {
                  return tabIndex == 0
                      ? _buildGroupsScroll(iconOnly: false)
                      : _buildSupportScroll(iconOnly: false);
                },
              ),
            ),
          ],
        ),
      );
    }

    if (searchExpanded) {
      final searchH = (usable - navH - gap).clamp(0.0, usable);
      return SizedBox(
        height: usable,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: navH,
              child: ValueListenableBuilder<int>(
                valueListenable: tabIndexListenable,
                builder: (context, tabIndex, _) {
                  return _NavTitleRow(
                    tabIndex: tabIndex,
                    searchExpanded: true,
                    onTabChanged: onTabChanged,
                    onToggleSearch: onToggleSearch,
                  );
                },
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: searchH,
              child: _InlineSearchField(
                controller: searchController,
                onClear: onSearchClear,
              ),
            ),
          ],
        ),
      );
    }

    final bubbleH = (usable - navH - gap).clamp(0.0, 50.h);
    return SizedBox(
      height: usable,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: navH,
            child: ValueListenableBuilder<int>(
              valueListenable: tabIndexListenable,
              builder: (context, tabIndex, _) {
                return _NavTitleRow(
                  tabIndex: tabIndex,
                  searchExpanded: false,
                  onTabChanged: onTabChanged,
                  onToggleSearch: onToggleSearch,
                );
              },
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: bubbleH,
            child: ValueListenableBuilder<int>(
              valueListenable: tabIndexListenable,
              builder: (context, tabIndex, _) {
                return tabIndex == 0
                    ? _buildGroupsScroll(iconOnly: false)
                    : _buildSupportScroll(iconOnly: false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsScroll({required bool iconOnly}) {
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'No groups yet',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54), fontSize: 12.sp),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: groups.length,
      separatorBuilder: (_, __) => SizedBox(width: 10.w),
      itemBuilder: (context, i) {
        final g = groups[i];
        return _QuickBubble(
          label: g.title ?? 'Group',
          iconOnly: iconOnly,
          onTap: () => onGroupTap(g),
        );
      },
    );
  }

  Widget _buildSupportScroll({required bool iconOnly}) {
    if (supportGroups.isEmpty) {
      return Center(
        child: Text(
          'No departments available',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54), fontSize: 12.sp),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: supportGroups.length,
      separatorBuilder: (_, __) => SizedBox(width: 10.w),
      itemBuilder: (context, i) {
        final g = supportGroups[i];
        return _QuickBubble(
          label: g.title ?? 'Dept ${g.roleId}',
          iconOnly: iconOnly,
          onTap: () => onSupportTap(g),
        );
      },
    );
  }
}

/// Single row: Chats · Groups · Supports · search.
class _NavTitleRow extends StatelessWidget {
  const _NavTitleRow({
    required this.tabIndex,
    required this.searchExpanded,
    required this.onTabChanged,
    required this.onToggleSearch,
    this.compact = false,
  });

  final int tabIndex;
  final bool searchExpanded;
  final bool compact;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 13.sp : 15.sp;
    final chipSize = compact ? 12.sp : 14.sp;
    final iconSize = compact ? 16.w : 18.w;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/newapp/newicon/chat-round-line_svgrepo.com.png',
          width: iconSize,
          height: iconSize,
          color: Colors.white,
        ),
        SizedBox(width: 5.w),
        Text(
          'Discuss',
          style: GoogleFonts.poppins(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
        SizedBox(width: compact ? 10.w : 14.w),
        _TopTabChip(
          label: 'Groups',
          isActive: tabIndex == 0,
          fontSize: chipSize,
          onTap: () => onTabChanged(0),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6.w : 8.w),
          child: Text(
            '|',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: chipSize,
              height: 1,
            ),
          ),
        ),
        _TopTabChip(
          label: 'Supports',
          isActive: tabIndex == 1,
          fontSize: chipSize,
          onTap: () => onTabChanged(1),
        ),
        const Spacer(),
        _SearchToggleButton(
          expanded: searchExpanded,
          onTap: onToggleSearch,
        ),
      ],
    );
  }
}

class _TopTabChip extends StatelessWidget {
  const _TopTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.fontSize,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: fontSize ?? 14.sp,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _QuickBubble extends StatelessWidget {
  const _QuickBubble({
    required this.label,
    required this.onTap,
    this.iconOnly = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool iconOnly;

  Widget _avatar(double radius) {
    const borderColor = ChatGlassTheme.avatarRing;
    return Container(
      padding: EdgeInsets.all(1.2.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(3.w),
          child: Image.asset(
            'assets/logo/rcc2.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 50.w,
          child: Center(child: _avatar(18.r)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 70.w;
        final tight = maxH.isFinite && maxH < 52;

        final labelSize = tight ? 7.sp : 8.sp;
        final gap = tight ? 1.0 : 2.h;
        final labelH = labelSize * 1.15;
        final avatarRadius = maxH.isFinite
            ? ((maxH - gap - labelH) / 2 - 2).clamp(11.0, 17.r)
            : 17.r;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _avatar(avatarRadius),
            SizedBox(height: gap),
            Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        );

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: maxW,
            height: maxH.isFinite ? maxH : null,
            child: maxH.isFinite
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: maxW,
                      child: content,
                    ),
                  )
                : content,
          ),
        );
      },
    );
  }
}

class _SearchToggleButton extends StatelessWidget {
  const _SearchToggleButton({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                expanded ? Icons.close_rounded : Icons.search_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSearchField extends StatelessWidget {
  const _InlineSearchField({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 13.sp,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.r),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: onClear,
        ),
      ),
      style: TextStyle(fontSize: 14.sp),
    );
  }
}

/// Conversation header with back chevron (collapses on scroll).
class ChatConversationHeader extends StatelessWidget {
  const ChatConversationHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.leading,
    required this.subtitle,
    required this.trailing,
    required this.shrinkRatio,
    required this.availableHeight,
  });

  final String title;
  final VoidCallback onBack;
  final Widget leading;
  final Widget? subtitle;
  final Widget trailing;
  final double shrinkRatio;
  final double availableHeight;

  static double expandedHeight = 92.h;
  static double collapsedHeight = 52.h;

  @override
  Widget build(BuildContext context) {
    final compact = shrinkRatio > 0.35;
    final showSubtitle =
        subtitle != null && !compact && availableHeight >= 62.h;

    return SizedBox(
      height: availableHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: AdaptiveGlassLayer(
          borderRadius: BorderRadius.circular(16.r),
          sigma: 14,
          fallbackColor: ChatGlassTheme.waterFillStrong,
          fallbackBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.38),
            width: 1,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ChatGlassTheme.waterFill,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ChatGlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: onBack,
                  size: 36.w,
                  iconColor: Colors.white,
                ),
                SizedBox(width: 4.w),
                leading,
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: compact ? 14.sp : 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      if (showSubtitle)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: DefaultTextStyle.merge(
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                            child: subtitle!,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same merged chrome as chat list: glass bar + conversation row, one backdrop.
class ChatConversationHeaderDelegate extends SliverPersistentHeaderDelegate {
  ChatConversationHeaderDelegate({
    required double topBarExtent,
    required this.title,
    required this.onBack,
    required this.leading,
    required this.subtitle,
    required this.trailing,
  }) : _topBarExtent = topBarExtent;

  final double _topBarExtent;
  final String title;
  final VoidCallback onBack;
  final Widget leading;
  final Widget? subtitle;
  final Widget trailing;

  @override
  double get minExtent =>
      _topBarExtent + ChatConversationHeader.collapsedHeight;

  @override
  double get maxExtent =>
      _topBarExtent + ChatConversationHeader.expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final convMax = ChatConversationHeader.expandedHeight;
    final convMin = ChatConversationHeader.collapsedHeight;
    final totalMax = _topBarExtent + convMax;
    final totalMin = _topBarExtent + convMin;
    final totalH = (totalMax - shrinkOffset).clamp(totalMin, totalMax);
    final convH = (totalH - _topBarExtent).clamp(0.0, convMax);
    final ratio = convMax > convMin
        ? ((convMax - convH) / (convMax - convMin)).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      height: totalH,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChatUnifiedHeaderBackdrop.layer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChatTopGlassAppBar(),
                SizedBox(
                  height: convH,
                  child: ChatConversationHeader(
                    title: title,
                    onBack: onBack,
                    leading: leading,
                    subtitle: subtitle,
                    trailing: trailing,
                    shrinkRatio: ratio,
                    availableHeight: convH,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ChatConversationHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle;
  }
}
