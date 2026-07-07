import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/Notification/notification_category_theme.dart';
import 'package:el_race/ui/widgets/glass_sub_app_screen_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class _CategoryFilter {
  const _CategoryFilter({
    required this.key,
    required this.visual,
  });

  final String key;
  final NotificationCategoryVisual visual;
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const int _pageSize = 20;
  static const _allCategoryKey = '__all__';

  final ScrollController _listController = ScrollController();

  List<_CategoryFilter> _categories = const [];
  String _selectedCategory = _allCategoryKey;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _listController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _listController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await NotificationStorageService.acknowledgeBadge();
    await _loadCategories();
    await _loadNotifications(reset: true);
  }

  Future<void> _loadCategories() async {
    try {
      final apiCategories =
          await NotificationStorageService.getNotificationCategories();
      final chips = <_CategoryFilter>[
        const _CategoryFilter(
          key: _allCategoryKey,
          visual: NotificationCategoryTheme.all,
        ),
      ];

      for (final item in apiCategories) {
        final key = item.model.trim().toLowerCase();
        if (key.isEmpty || key == 'circular' || key == 'announcement') {
          continue;
        }
        if (chips.any((c) => c.key == key)) continue;
        chips.add(
          _CategoryFilter(
            key: key,
            visual: NotificationCategoryTheme.forKey(
              key,
              fallbackTitle: item.title.trim().isNotEmpty
                  ? item.title.trim()
                  : null,
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _categories = chips);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const [
          _CategoryFilter(
            key: _allCategoryKey,
            visual: NotificationCategoryTheme.all,
          ),
        ];
      });
    }
  }

  void _onScroll() {
    if (!_listController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _listController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadNotifications(reset: false);
    }
  }

  Future<void> _loadNotifications({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _offset = 0;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final batch = await NotificationStorageService.getNotifications(
        limit: _pageSize,
        offset: reset ? 0 : _offset,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _notifications = List<Map<String, dynamic>>.from(batch);
        } else {
          final ids = _notifications
              .map((n) => '${n['id'] ?? ''}')
              .where((id) => id.isNotEmpty)
              .toSet();
          for (final item in batch) {
            final id = '${item['id'] ?? ''}';
            if (id.isNotEmpty && ids.contains(id)) continue;
            _notifications.add(Map<String, dynamic>.from(item));
          }
        }
        _offset = reset ? batch.length : _offset + batch.length;
        _hasMore = batch.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _clearSelectedCategory() {
    if (_clearing) return;

    final category = _selectedCategory;

    setState(() {
      _clearing = true;
      _notifications = _notifications
          .where((n) => !_matchesClearScope(n))
          .toList();
      _offset = _notifications.length;
      _hasMore = false;
    });

    Future<void>(() async {
      try {
        if (category == _allCategoryKey) {
          await NotificationStorageService.markAllAsRead();
        } else {
          await NotificationStorageService.markCategoryAsRead(category);
        }
      } finally {
        if (mounted) setState(() => _clearing = false);
      }
    });
  }

  bool _matchesClearScope(Map<String, dynamic> item) {
    if (_selectedCategory == _allCategoryKey) {
      final cat = (item['category'] ?? '').toString().toLowerCase().trim();
      return cat != 'circular' && cat != 'announcement';
    }
    final cat = (item['category'] ?? 'notification').toString().toLowerCase();
    return cat == _selectedCategory.toLowerCase();
  }

  bool _isRead(Map<String, dynamic> item) {
    final value = item['isRead'] ?? item['is_read'] ?? false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  String _categoryKey(Map<String, dynamic> item) {
    return (item['category'] ?? 'notification').toString().toLowerCase().trim();
  }

  int _unreadCountForCategory(String key) {
    if (key == _allCategoryKey) {
      return _notifications.where((n) {
        if (_isRead(n)) return false;
        final cat = _categoryKey(n);
        return cat != 'circular' && cat != 'announcement';
      }).length;
    }
    return _notifications
        .where((n) => !_isRead(n) && _categoryKey(n) == key)
        .length;
  }

  List<Map<String, dynamic>> get _visibleNotifications {
    if (_selectedCategory == _allCategoryKey) {
      return _notifications.where((n) {
        final cat = _categoryKey(n);
        return cat != 'circular' && cat != 'announcement';
      }).toList();
    }

    return _notifications
        .where((n) => _categoryKey(n) == _selectedCategory.toLowerCase())
        .toList();
  }

  String _formatTime(Map<String, dynamic> item) {
    final timeAgo = (item['timeAgo'] ?? '').toString().trim();
    if (timeAgo.isNotEmpty) return timeAgo;

    final raw = (item['timestamp'] ?? '').toString();
    if (raw.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(raw);
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (_) {
      return '';
    }
  }

  Future<void> _onTapNotification(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isNotEmpty && !_isRead(item)) {
      await NotificationStorageService.markAsRead(id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) {
          if (n['id']?.toString() == id) {
            final updated = Map<String, dynamic>.from(n);
            updated['isRead'] = true;
            updated['is_read'] = true;
            return updated;
          }
          return n;
        }).toList();
      });
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4F6FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item['title']?.toString() ?? 'Notification',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            item['body']?.toString() ?? '',
            style: GoogleFonts.poppins(fontSize: 13.sp, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleNotifications;
    final categoryBarHeight = GlassSubAppScreenHeader.headerTabsHeight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        HomeNavigation.handleSystemBack(context);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: ChatUnifiedHeaderBackdrop.gradient,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.55,
                  child: Image.asset(
                    'assets/png/header_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: SubAppGlassAppBar.extent(context) +
                      GlassSubAppScreenHeader.titleRowHeight.h +
                      categoryBarHeight.h,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      ChatUnifiedHeaderBackdrop.layer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: SubAppGlassAppBar.extent(context),
                            child: const SubAppGlassAppBar(),
                          ),
                          SizedBox(
                            height: GlassSubAppScreenHeader.titleRowHeight.h,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(14.w, 2.h, 8.w, 0),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        HomeNavigation.handleSystemBack(
                                            context),
                                    icon: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(
                                      minWidth: 32.w,
                                      minHeight: 32.w,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Notifications',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  _ClearAllBadge(
                                    clearing: _clearing,
                                    onTap: _clearSelectedCategory,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: categoryBarHeight.h,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: _CategoryIconBar(
                                  categories: _categories,
                                  selectedKey: _selectedCategory,
                                  unreadForKey: _unreadCountForCategory,
                                  onSelected: (key) =>
                                      setState(() => _selectedCategory = key),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : items.isEmpty
                          ? Center(
                              child: Text(
                                'No notifications',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _listController,
                              padding: EdgeInsets.fromLTRB(
                                14.w,
                                10.h,
                                14.w,
                                context.systemBottomInset + 16.h,
                              ),
                              itemCount:
                                  items.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  return Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.h),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }
                                final item = items[index];
                                final visual = NotificationCategoryTheme.forKey(
                                  _categoryKey(item),
                                );
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: _NotificationGlassCard(
                                    visual: visual,
                                    title: item['title']?.toString() ??
                                        'Notification',
                                    body: item['body']?.toString() ?? '',
                                    timeLabel: _formatTime(item),
                                    isRead: _isRead(item),
                                    onTap: () => _onTapNotification(item),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIconBar extends StatelessWidget {
  const _CategoryIconBar({
    required this.categories,
    required this.selectedKey,
    required this.unreadForKey,
    required this.onSelected,
  });

  final List<_CategoryFilter> categories;
  final String selectedKey;
  final int Function(String key) unreadForKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.only(top: 8.h),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final chip = categories[index];
          final selected = chip.key == selectedKey;
          final unread = unreadForKey(chip.key);
          return GlassHeaderIconChip(
            icon: chip.visual.icon,
            color: chip.visual.color,
            isSelected: selected,
            badgeCount: unread,
            onTap: () => onSelected(chip.key),
          );
        },
      ),
    );
  }
}

class _ClearAllBadge extends StatelessWidget {
  const _ClearAllBadge({
    required this.clearing,
    required this.onTap,
  });

  final bool clearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: clearing ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        child: clearing
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              )
            : Text(
                'Clear all',
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
      ),
    );
  }
}

class _NotificationGlassCard extends StatelessWidget {
  const _NotificationGlassCard({
    required this.visual,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.isRead,
    required this.onTap,
  });

  final NotificationCategoryVisual visual;
  final String title;
  final String body;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white.withValues(alpha: isRead ? 0.14 : 0.22),
            border: Border.all(
              color: Colors.white.withValues(alpha: isRead ? 0.35 : 0.62),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassHeaderIconChip(
                  icon: visual.icon,
                  color: visual.color,
                  isSelected: true,
                  size: 42,
                  faded: true,
                  onTap: onTap,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8.w,
                              height: 8.w,
                              margin: EdgeInsets.only(left: 6.w, top: 4.h),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (body.trim().isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (timeLabel.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          timeLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
