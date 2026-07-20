import 'package:el_race/core/utils/responsive_breakpoints.dart';
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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const int _maxRecords = 50;
  static const Color _ink = Color(0xFF1A2248);

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _clearing = false;
  bool _clearAllVisible = false;
  String? _openSwipeId;
  void Function()? _previousCountCallback;

  @override
  void initState() {
    super.initState();
    _previousCountCallback = NotificationStorageService.onCountChanged;
    NotificationStorageService.onCountChanged = () {
      _previousCountCallback?.call();
      if (mounted && !_loading) {
        _loadNotifications(showLoader: false);
      }
    };
    _bootstrap();
  }

  @override
  void dispose() {
    NotificationStorageService.onCountChanged = _previousCountCallback;
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Load list, then snapshot unread baseline so only newer items bump the bell.
    await _loadNotifications();
    await NotificationStorageService.acknowledgeBadge(
      knownIds: _notifications.map((n) => '${n['id'] ?? ''}'),
    );
    await NotificationStorageService.markAllAsRead();
    if (!mounted) return;
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
        n['is_read'] = true;
      }
    });
  }

  Future<void> _loadNotifications({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }
    try {
      final batch = await NotificationStorageService.getNotifications(
        limit: _maxRecords,
        offset: 0,
      );
      if (!mounted) return;
      final filtered = List<Map<String, dynamic>>.from(batch).where((n) {
        final cat = (n['category'] ?? '').toString().toLowerCase().trim();
        return cat != 'circular' && cat != 'announcement';
      }).toList();
      filtered.sort(_compareNewestFirst);
      setState(() {
        _notifications = filtered;
        _loading = false;
        if (_notifications.isEmpty) {
          _clearAllVisible = false;
          _openSwipeId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _compareNewestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = DateTime.tryParse(
          (a['timestamp'] ?? a['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = DateTime.tryParse(
          (b['timestamp'] ?? b['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
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

  String _formatTime(Map<String, dynamic> item) {
    final timeAgo = (item['timeAgo'] ?? '').toString().trim();
    if (timeAgo.isNotEmpty) return timeAgo;

    final raw = (item['timestamp'] ?? item['created_at'] ?? '').toString();
    if (raw.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(raw).toLocal();
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

  String _formatClockTime(Map<String, dynamic> item) {
    final raw = (item['timestamp'] ?? item['created_at'] ?? '').toString();
    if (raw.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(raw).toLocal();
      return DateFormat('h:mm a').format(dateTime).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  void _onTapNotification(Map<String, dynamic> item) {
    // No popup — tap only closes open swipe / Clear all chrome.
    _collapseChrome();
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    setState(() {
      _notifications =
          _notifications.where((n) => n['id']?.toString() != id).toList();
      if (_openSwipeId == id) _openSwipeId = null;
      if (_notifications.isEmpty) _clearAllVisible = false;
    });
    await NotificationStorageService.deleteNotification(id);
  }

  void _onCrossTap() {
    if (_clearing || _notifications.isEmpty) return;
    setState(() {
      _openSwipeId = null;
      _clearAllVisible = !_clearAllVisible;
    });
  }

  Future<void> _performClearAll() async {
    if (_clearing || _notifications.isEmpty) return;

    setState(() {
      _clearing = true;
      _notifications = [];
      _openSwipeId = null;
    });
    try {
      await NotificationStorageService.clearAll();
      await NotificationStorageService.acknowledgeBadge();
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
          _clearAllVisible = false;
        });
      }
    }
  }

  void _collapseChrome() {
    if (!_clearAllVisible && _openSwipeId == null) return;
    setState(() {
      _clearAllVisible = false;
      _openSwipeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_clearAllVisible || _openSwipeId != null) {
          _collapseChrome();
          return;
        }
        HomeNavigation.handleSystemBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8ECF2),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _LightenedBrandBackdrop(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: SubAppGlassAppBar.extent(context),
                  child: const SubAppGlassAppBar(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8.tw, 2.th, 12.tw, 8.th),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_clearAllVisible || _openSwipeId != null) {
                            _collapseChrome();
                            return;
                          }
                          HomeNavigation.handleSystemBack(context);
                        },
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _ink,
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
                          'Notification center',
                          style: GoogleFonts.poppins(
                            fontSize: 17.tsp,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      _HeaderClearControls(
                        clearAllVisible: _clearAllVisible,
                        clearing: _clearing,
                        enabled: _notifications.isNotEmpty,
                        onCrossTap: _onCrossTap,
                        onClearAllTap: _performClearAll,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1A2248),
                          ),
                        )
                      : _notifications.isEmpty
                          ? Center(
                              child: Text(
                                'No notifications',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.tsp,
                                  fontWeight: FontWeight.w600,
                                  color: _ink.withValues(alpha: 0.55),
                                ),
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _collapseChrome,
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  12.tw,
                                  4.th,
                                  12.tw,
                                  context.systemBottomInset + 16.th,
                                ),
                                itemCount: _notifications.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 0.7,
                                  color: _ink.withValues(alpha: 0.10),
                                ),
                                itemBuilder: (context, index) {
                                  final item = _notifications[index];
                                  final id = '${item['id'] ?? index}';
                                  final visual =
                                      NotificationCategoryTheme.forKey(
                                    _categoryKey(item),
                                  );
                                  return _IosSwipeClearTile(
                                    key: ValueKey('notif_$id'),
                                    itemId: id,
                                    isOpen: _openSwipeId == id,
                                    onOpenChanged: (open) {
                                      setState(() {
                                        _clearAllVisible = false;
                                        _openSwipeId = open ? id : null;
                                      });
                                    },
                                    onClear: () => _deleteNotification(item),
                                    child: _NotificationRow(
                                      visual: visual,
                                      title: item['title']?.toString() ??
                                          'Notification',
                                      body: item['body']?.toString() ?? '',
                                      timeLabel: _formatTime(item),
                                      clockTime: _formatClockTime(item),
                                      isRead: _isRead(item),
                                      onTap: () => _onTapNotification(item),
                                    ),
                                  );
                                },
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
}

class _GlassPillDecoration {
  /// Transparent like notification rows — no drop shadow (avoids halo bug).
  static BoxDecoration get sameBackground => BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.transparent,
        border: Border.all(
          color: const Color(0xFF1A2248).withValues(alpha: 0.16),
        ),
      );
}

/// X stays put; "Clear all" pops in/out beside it with scale+fade.
class _HeaderClearControls extends StatelessWidget {
  const _HeaderClearControls({
    required this.clearAllVisible,
    required this.clearing,
    required this.enabled,
    required this.onCrossTap,
    required this.onClearAllTap,
  });

  final bool clearAllVisible;
  final bool clearing;
  final bool enabled;
  final VoidCallback onCrossTap;
  final VoidCallback onClearAllTap;

  static const Color _ink = Color(0xFF1A2248);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1.0).animate(animation),
                alignment: Alignment.centerRight,
                child: child,
              ),
            );
          },
          child: clearAllVisible
              ? Padding(
                  key: const ValueKey('clear_all_shown'),
                  padding: EdgeInsets.only(right: 8.tw),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (!enabled || clearing) ? null : onClearAllTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        height: 36.th,
                        padding: EdgeInsets.symmetric(horizontal: 12.tw),
                        decoration: _GlassPillDecoration.sameBackground,
                        child: Center(
                          child: clearing
                              ? SizedBox(
                                  width: 14.tw,
                                  height: 14.tw,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _ink,
                                  ),
                                )
                              : Text(
                                  'Clear all',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.tsp,
                                    fontWeight: FontWeight.w600,
                                    color: _ink.withValues(alpha: 0.85),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  key: const ValueKey('clear_all_hidden'),
                  height: 36.th,
                  width: 0,
                ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (!enabled && !clearAllVisible) || clearing
                ? null
                : onCrossTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 36.tw,
              height: 36.tw,
              decoration: _GlassPillDecoration.sameBackground,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 18.tsp,
                  color: enabled || clearAllVisible
                      ? _ink.withValues(alpha: 0.78)
                      : _ink.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS-style swipe: partial reveal shows Clear; full swipe dismisses.
class _IosSwipeClearTile extends StatefulWidget {
  const _IosSwipeClearTile({
    super.key,
    required this.itemId,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onClear,
    required this.child,
  });

  final String itemId;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final Future<void> Function() onClear;
  final Widget child;

  @override
  State<_IosSwipeClearTile> createState() => _IosSwipeClearTileState();
}

class _IosSwipeClearTileState extends State<_IosSwipeClearTile>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(0xFF1A2248);

  late final AnimationController _anim;
  double _dragExtent = 0;
  double _animFrom = 0;
  double _animTo = 0;
  Curve _animCurve = Curves.linear;
  bool _removing = false;
  bool _dragging = false;

  /// Match category icon chip size.
  double get _iconSize => 42.tw;
  double get _restActionWidth => _iconSize + 28.tw;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_onAnimTick);
    if (widget.isOpen) {
      _dragExtent = -_restActionWidth;
    }
  }

  void _onAnimTick() {
    final t = _animCurve.transform(_anim.value);
    setState(() {
      _dragExtent = _animFrom + (_animTo - _animFrom) * t;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _animateExtent(
    double target, {
    int ms = 120,
    Curve curve = Curves.easeOutCubic,
  }) async {
    _anim.stop();
    _animFrom = _dragExtent;
    _animTo = target;
    _animCurve = curve;
    _anim.duration = Duration(milliseconds: ms);
    await _anim.forward(from: 0);
    if (mounted) setState(() => _dragExtent = target);
  }

  void _onDragStart(DragStartDetails details) {
    if (_removing) return;
    _anim.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_removing) return;
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragging = true;
      _dragExtent =
          (_dragExtent + delta).clamp(-MediaQuery.sizeOf(context).width, 0.0);
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_removing) return;
    _dragging = false;
    final width = MediaQuery.sizeOf(context).width;
    final abs = _dragExtent.abs();
    final velocity = details.primaryVelocity ?? 0;
    final wasOpen = widget.isOpen || abs >= _restActionWidth * 0.85;
    // Snap open relative to Clear slot size (not screen %), so release
    // does not hide the button that was visible mid-swipe.
    final openThreshold = _restActionWidth * 0.55;

    // Full dismiss: 50% normally, or continue-swipe when Clear is already open.
    final fullDismiss = abs >= width * 0.50 ||
        (wasOpen && abs >= width * 0.32) ||
        (abs >= width * 0.28 && velocity < -1000);
    if (fullDismiss) {
      await _dismissFully();
      return;
    }

    if (abs >= openThreshold ||
        (velocity < -450 && abs >= _restActionWidth * 0.35)) {
      await _animateExtent(-_restActionWidth, ms: 110);
      if (!mounted) return;
      widget.onOpenChanged(true);
      return;
    }

    // Un-swipe: drop open flag first so Clear clips with the row, no lag hide.
    widget.onOpenChanged(false);
    final closeMs = velocity > 600 ? 55 : 75;
    await _animateExtent(0, ms: closeMs, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _IosSwipeClearTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_removing || _dragging) return;
    if (widget.isOpen == oldWidget.isOpen) return;
    if (!widget.isOpen && _dragExtent != 0) {
      _animateExtent(0, ms: 75, curve: Curves.easeOutCubic);
    } else if (widget.isOpen && _dragExtent > -_restActionWidth + 1) {
      _animateExtent(-_restActionWidth, ms: 110);
    }
  }

  Future<void> _dismissFully() async {
    if (_removing) return;
    setState(() => _removing = true);
    final width = MediaQuery.sizeOf(context).width;
    await _animateExtent(-width, ms: 140);
    await widget.onClear();
  }

  Future<void> _onClearTap() async {
    if (_removing || _dragging) return;
    await _dismissFully();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final abs = -_dragExtent;
    // Follow finger / animation exactly — no min-width clamp (that caused
    // Clear to stay full-size then pop away on un-swipe).
    final showClear = abs > 0.5;
    final trackWidth = abs.clamp(0.0, width);
    final clearOpacity =
        (abs / (_restActionWidth * 0.85)).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (showClear)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: trackWidth,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: clearOpacity,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4.tw),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onClearTap,
                          borderRadius: BorderRadius.circular(14.tr),
                          child: Ink(
                            width: _iconSize + 20.tw,
                            height: _iconSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.tr),
                              color: Colors.transparent,
                              border: Border.all(
                                color: _ink.withValues(alpha: 0.18),
                                width: 1.1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Clear',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.tsp,
                                  fontWeight: FontWeight.w600,
                                  color: _ink.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: ColoredBox(
                color: Colors.transparent,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightenedBrandBackdrop extends StatelessWidget {
  const _LightenedBrandBackdrop();

  static Color _lift(Color base, double towardWhite) =>
      Color.lerp(base, Colors.white, towardWhite)!;

  static final LinearGradient _lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      _lift(const Color(0xFFB4B9C2), 0.62),
      _lift(const Color(0xFF8E98A8), 0.58),
      _lift(const Color(0xFF6E7A92), 0.55),
      _lift(const Color(0xFF525E7A), 0.52),
      _lift(const Color(0xFF3D4768), 0.50),
      _lift(const Color(0xFF2C3560), 0.48),
      _lift(const Color(0xFF222B58), 0.46),
      _lift(const Color(0xFF1A2248), 0.44),
      _lift(const Color(0xFF161B54), 0.42),
    ],
    stops: ChatUnifiedHeaderBackdrop.gradient.stops,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: _lightGradient)),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                'assets/png/header_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.42),
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.visual,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.clockTime,
    required this.isRead,
    required this.onTap,
  });

  final NotificationCategoryVisual visual;
  final String title;
  final String body;
  final String timeLabel;
  final String clockTime;
  final bool isRead;
  final VoidCallback onTap;

  static const Color _ink = Color(0xFF1A2248);

  @override
  Widget build(BuildContext context) {
    final lightColor = Color.lerp(visual.color, Colors.white, 0.42)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.tw, vertical: 12.th),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassHeaderIconChip(
                icon: visual.icon,
                color: lightColor,
                isSelected: true,
                size: 42,
                faded: true,
                onTap: onTap,
              ),
              SizedBox(width: 12.tw),
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
                              fontSize: 14.tsp,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w700,
                              color: _ink,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8.tw,
                            height: 8.tw,
                            margin: EdgeInsets.only(left: 6.tw, top: 4.th),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (body.trim().isNotEmpty) ...[
                      SizedBox(height: 4.th),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          color: _ink.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (timeLabel.isNotEmpty || clockTime.isNotEmpty) ...[
                      SizedBox(height: 6.th),
                      Row(
                        children: [
                          if (timeLabel.isNotEmpty)
                            Expanded(
                              child: Text(
                                timeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.tsp,
                                  fontWeight: FontWeight.w500,
                                  color: _ink.withValues(alpha: 0.45),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (clockTime.isNotEmpty)
                            Text(
                              clockTime,
                              style: GoogleFonts.poppins(
                                fontSize: 10.tsp,
                                fontWeight: FontWeight.w500,
                                color: _ink.withValues(alpha: 0.45),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
