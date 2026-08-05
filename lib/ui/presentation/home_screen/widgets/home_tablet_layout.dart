import 'dart:math' as math;

import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/presentation/Email Approval/Approval.dart';
import 'package:el_race/ui/presentation/Notification/notification_mute_settings_screen.dart';
import 'package:el_race/ui/presentation/Notification/notification_screen.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/glass_tap_icon.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_section.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_news_card.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/list_view_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/my_actions_section.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_bottom_sheet.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_logout_helper.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/widgets/global_search_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Tablet Home shell — multi-pane layout for tablet widths.
///
/// Layout (landscape):
/// - Header: static logo · smart search · location · actions (no glass background)
/// - Left trail: icon-fit width, height fits content, vertically centered
/// - Side panes 30% (full height to bottom) / Mid 40% (greeting · news fills ·
///   check-in/prayer strip · dock) / Side 30% (full height)
class HomeTabletLayout extends StatefulWidget {
  const HomeTabletLayout({
    super.key,
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  State<HomeTabletLayout> createState() => _HomeTabletLayoutState();
}

class _HomeTabletLayoutState extends State<HomeTabletLayout> with RouteAware {
  @override
  void initState() {
    super.initState();
    AppOrientations.lockTabletHomeLandscape();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppOrientations.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppOrientations.routeObserver.unsubscribe(this);
    // Leaving Home entirely — allow rotation on whatever comes next.
    AppOrientations.allowTabletRotation();
    super.dispose();
  }

  @override
  void didPush() => AppOrientations.lockTabletHomeLandscape();

  @override
  void didPopNext() => AppOrientations.lockTabletHomeLandscape();

  @override
  void didPushNext() => AppOrientations.allowTabletRotation();

  @override
  Widget build(BuildContext context) {
    return HomeSilverBackground(
      child: _TabletLandscapeShell(onRefresh: widget.onRefresh),
    );
  }
}

class _TabletLandscapeShell extends StatelessWidget {
  const _TabletLandscapeShell({required this.onRefresh});

  final Future<void> Function() onRefresh;

  static const double _outerPad = 16;
  static const double _gap = 12;
  /// Icon-fit trail (icon 22 + padding).
  static const double _trailWidth = 48;

  /// Side : Mid : Side  →  30% : 40% : 30%
  static const int _sideFlex = 3;
  static const int _midFlex = 4;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        topInset + _outerPad,
        _outerPad,
        bottomInset + _outerPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header aligns with body columns: logo starts at section 3,
          // right actions end with section 2.
          Row(
            children: [
              const SizedBox(width: _trailWidth + _gap),
              const Expanded(child: _TabletHomeHeader()),
            ],
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TabletSideTrail(),
                const SizedBox(width: _gap),
                Expanded(
                  flex: _sideFlex,
                  child: _TabletWidgetsPane(
                    pane: HomeTabletWidgetsPane.section3,
                    onRefresh: onRefresh,
                  ),
                ),
                const SizedBox(width: _gap),
                const Expanded(
                  flex: _midFlex,
                  child: _TabletNewsPane(),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: _sideFlex,
                  child: _TabletWidgetsPane(
                    pane: HomeTabletWidgetsPane.section2,
                    onRefresh: onRefresh,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header without glass background: logo · search · location · actions.
class _TabletHomeHeader extends StatefulWidget {
  const _TabletHomeHeader();

  @override
  State<_TabletHomeHeader> createState() => _TabletHomeHeaderState();
}

class _TabletHomeHeaderState extends State<_TabletHomeHeader> {
  int _notificationCount = 0;
  int _approvalCount = 0;
  bool _profileOpening = false;
  String _imageBase64 = '';
  String _city = HomeCityHelper.cachedCity;

  @override
  void initState() {
    super.initState();
    _notificationCount = NotificationStorageService.memoryBadgeCount;
    _approvalCount = ApprovalCountService.cachedCountOrZero;
    _loadUserData();
    _loadCounts();
    _loadCity();
    NotificationStorageService.addCountListener(this, () {
      if (mounted) _loadNotificationCount();
    });
    ApprovalCountService.addListener(this, () {
      if (mounted) _loadApprovalCount();
    });
  }

  @override
  void dispose() {
    NotificationStorageService.removeCountListener(this);
    ApprovalCountService.removeListener(this);
    super.dispose();
  }

  Future<void> _loadCity() async {
    final city = await HomeCityHelper.fetchCity();
    if (mounted) setState(() => _city = city);
  }

  Future<void> _loadUserData() async {
    if (!SharedPref.isUserAuthenticated()) return;
    final data = SharedPref.getLoginData();
    if (mounted) {
      setState(() => _imageBase64 = data.result?.data?.image_url ?? '');
    }
  }

  Future<void> _loadCounts() async {
    await Future.wait([_loadNotificationCount(), _loadApprovalCount()]);
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationStorageService.getBadgeCount();
    if (mounted) setState(() => _notificationCount = count);
  }

  Future<void> _loadApprovalCount() async {
    final count = await ApprovalCountService.getTotalApprovalCount();
    if (mounted) setState(() => _approvalCount = count);
  }

  void _openSearch() {
    openGlassSubScreen(
      context,
      routeName: '/global_search',
      shell: GlassSubScreenShell.search,
      child: const GlobalSearchScreen(),
    );
  }

  Future<void> _openApprovals() async {
    await openGlassSubScreen(
      context,
      routeName: '/approvals',
      shell: GlassSubScreenShell.list,
      child: const ApprovalsScreen(),
    );
    await _loadApprovalCount();
  }

  Future<void> _openNotifications() async {
    await openGlassSubScreen(
      context,
      routeName: '/notifications',
      shell: GlassSubScreenShell.list,
      child: const NotificationScreen(),
    );
    await _loadNotificationCount();
  }

  void _openProfile() {
    if (!SharedPref.isUserAuthenticated()) {
      Util.pushPage(const SignInScreen(), context);
      return;
    }
    if (_profileOpening) return;
    setState(() => _profileOpening = true);
    ProfileBottomSheet.show(context).whenComplete(() {
      if (mounted) setState(() => _profileOpening = false);
    });
  }

  Widget _profileImage(String imageData) {
    if (imageData.isEmpty) {
      return Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
    }
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/png/profile_1.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Image.asset(
            'assets/png/elrace_logo.png',
            height: 68,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/png/app-logo.png',
              height: 68,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 16),
          // Smart search — capped width, not Expanded flex:5
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _openSearch,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: HomeGlassTheme.maroon,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Global Search',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HomeGlassTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Right cluster — ends flush with section 2 (same right inset).
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HomeMaroonLocationMarker(size: 14),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  _city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: HomeGlassTheme.maroon,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderIconBadge(
                icon: Icons.assignment_outlined,
                count: _approvalCount,
                onTap: _openApprovals,
              ),
              const SizedBox(width: 6),
              _HeaderIconBadge(
                icon: Icons.notifications_outlined,
                count: _notificationCount,
                onTap: _openNotifications,
              ),
              const SizedBox(width: 8),
              GlassTapIcon(
                onTap: _openProfile,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.8),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A90D9), Color(0xFF2563EB)],
                    ),
                  ),
                  child: _profileOpening
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : ClipOval(child: _profileImage(_imageBase64)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassTapIcon(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(icon, size: 22, color: HomeGlassTheme.maroon),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: HomeGlassTheme.maroon,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Edge-attached left trail — icon-fit width, vertically centered.
class _TabletSideTrail extends StatelessWidget {
  const _TabletSideTrail();

  Future<void> _openChat(BuildContext context) async {
    await openGlassSubScreen(
      context,
      routeName: '/chat_list',
      shell: GlassSubScreenShell.chat,
      child: const ChatShellScreen(),
    );
  }

  void _openContact(BuildContext context) {
    HomeBloc.get(context).add(const ChangeCurrentIndex(index: 0));
  }

  Future<void> _openCamera(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const CameraSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openMuteSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationMuteSettingsScreen(),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ProfileLogoutHelper.confirmAndLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      topRight: Radius.circular(26),
      bottomRight: Radius.circular(26),
    );

    // Vertically center the trail in the body row (full pane height).
    return Center(
      child: SizedBox(
        width: _TabletLandscapeShell._trailWidth,
        child: HomeGlassTheme.glassSurface(
          borderRadius: radius,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TrailIcon(
                tooltip: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => _openChat(context),
              ),
              const SizedBox(height: 14),
              _TrailIcon(
                tooltip: 'Contact',
                icon: Icons.phone_rounded,
                onTap: () => _openContact(context),
              ),
              const SizedBox(height: 14),
              _TrailIcon(
                tooltip: 'Camera',
                icon: Icons.photo_camera_outlined,
                onTap: () => _openCamera(context),
              ),
              const SizedBox(height: 14),
              _TrailIcon(
                tooltip: 'Notification mute settings',
                icon: Icons.notifications_off_outlined,
                onTap: () => _openMuteSettings(context),
              ),
              const SizedBox(height: 14),
              _TrailIcon(
                tooltip: 'Logout',
                icon: Icons.power_settings_new_rounded,
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailIcon extends StatelessWidget {
  const _TrailIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassTapIcon(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: HomeGlassTheme.maroon),
        ),
      ),
    );
  }
}

/// Mid column: glass pane (greeting · news · check-in/prayer strip) with the
/// dock floating separately below — glass background ends before the dock.
class _TabletNewsPane extends StatelessWidget {
  const _TabletNewsPane();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: HomeGlassTheme.glassSurface(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TabletMidGreeting(),
                const SizedBox(height: 10),
                // News starts right after the greeting; misc (check-in/prayer)
                // covers everything from the news end to the glass bottom.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 8.0;
                      final paneW = constraints.maxWidth;
                      final srcW = 360.w;
                      final scale = (paneW / srcW).clamp(0.2, 1.0);
                      // News keeps its natural card aspect; the misc section
                      // absorbs everything below it down to the glass bottom.
                      final newsNaturalH =
                          HomeNewsCard.resolveHeight(context,
                                  tabletLayout: true) *
                              scale;
                      final maxNewsH = math.max(
                        120.0,
                        constraints.maxHeight - gap - 90.0,
                      );
                      final newsH = math.min(newsNaturalH, maxNewsH);
                      return Column(
                        children: [
                          SizedBox(
                            height: newsH,
                            width: paneW,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: FittedBox(
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: srcW,
                                    height: newsH / scale,
                                    child:
                                        const HomeNewsCard(tabletLayout: true),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: gap),
                          Expanded(
                            child: _TabletMiscSection(srcWidth: srcW),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Floating dock — outside the glass pane, same width as mid column.
        const MyActionsSection(
          dockMode: true,
          showTitle: false,
          expandToWidth: true,
        ),
      ],
    );
  }
}

/// Misc section (check-in/prayer) — stretches to cover the area between the
/// news end and the bottom of the mid glass pane, tablet redesign only.
class _TabletMiscSection extends StatelessWidget {
  const _TabletMiscSection({required this.srcWidth});

  final double srcWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / srcWidth).clamp(0.2, 2.0);
        // Source box mirrors the visual box aspect exactly, so BoxFit.fill is
        // a uniform scale — the glass shell covers the full area.
        final srcH = constraints.maxHeight / scale;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: srcWidth,
              height: srcH,
              child: const HomeMidSection(),
            ),
          ),
        );
      },
    );
  }
}

/// Same structure as mobile [HomeGreetingSection] — no faded logo (logo is in header).
class _TabletMidGreeting extends StatelessWidget {
  const _TabletMidGreeting();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName() {
    final login = SharedPref.getLoginData();
    final name = login.result?.data?.name?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_greeting()} ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HomeGlassTheme.maroon,
                ),
              ),
              Text(
                '✦',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HomeGlassTheme.maroon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _firstName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: HomeGlassTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date sits bottom-right of the name row (moved from header).
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  DateFormat('EEEE, d MMM').format(DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: HomeGlassTheme.maroon,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabletWidgetsPane extends StatelessWidget {
  const _TabletWidgetsPane({
    required this.pane,
    required this.onRefresh,
  });

  final HomeTabletWidgetsPane pane;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return HomeGlassTheme.glassSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: RefreshIndicator(
        color: HomeGlassTheme.maroon,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ListViewWidgets(
            hideFeaturedHeader: false,
            tabletPane: pane,
          ),
        ),
      ),
    );
  }
}
