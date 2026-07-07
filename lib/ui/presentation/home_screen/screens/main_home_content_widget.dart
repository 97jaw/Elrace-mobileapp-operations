import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/ui/presentation/home_screen/provider/slider_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_floating_comms_bar.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_app_bar.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_greeting_section.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_news_card.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_widgets_panel.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/mid_section_scroll_lock.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/my_actions_section.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class MainHomeContentWidget extends StatefulWidget {
  const MainHomeContentWidget({super.key});

  @override
  State<MainHomeContentWidget> createState() => _MainHomeContentWidgetState();
}

class _MainHomeContentWidgetState extends State<MainHomeContentWidget> {
  final ValueNotifier<double> _expandProgress = ValueNotifier(0);
  double _panelAnchorTop = 0;
  final ValueNotifier<bool> _midStripScrollLock = ValueNotifier(false);
  final GlobalKey _headerZoneKey = GlobalKey();

  @override
  void dispose() {
    _expandProgress.dispose();
    _midStripScrollLock.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SliderProvider>().fetchAnnouncementsForBanner();
      HomeCityHelper.fetchCity(force: true).then((_) {
        if (mounted) setState(() {});
      });
      _measureHeaderAndInit();
    });
  }

  void _measureHeaderAndInit() {
    final box =
        _headerZoneKey.currentContext?.findRenderObject() as RenderBox?;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final measured = box != null && box.hasSize
        ? box.size.height
        : screenHeight * 0.52;
    if ((measured - _panelAnchorTop).abs() < 1 && _panelAnchorTop > 0) return;
    setState(() => _panelAnchorTop = measured);
  }

  Future<void> _onRefresh() async {
    await DefaultCacheManager().emptyCache();
    if (!mounted) return;
    await Util.fetchHomeScreenData(context);
    await context.read<SliderProvider>().refresh();
    await AttendanceStatusSyncService.refreshFromServer(
      reason: 'pull_to_refresh',
    );
    await HomeCityHelper.fetchCity(force: true);
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureHeaderAndInit();
      });
    }
  }

  void _onProgressChanged(double progress) {
    if ((progress - _expandProgress.value).abs() < 0.001) return;
    _expandProgress.value = progress;
    if (progress <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureHeaderAndInit();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return MidSectionScrollLock(
      lock: _midStripScrollLock,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: HomeSilverBackground(
              child: SizedBox.expand(),
            ),
          ),
          RefreshIndicator(
            color: HomeGlassTheme.maroon,
            backgroundColor: Colors.transparent,
            onRefresh: _onRefresh,
            child: ColoredBox(
              color: Colors.transparent,
              child: ValueListenableBuilder<bool>(
                valueListenable: _midStripScrollLock,
                builder: (context, midStripLocked, child) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _expandProgress,
                    builder: (context, t, child) {
                      return SingleChildScrollView(
                        physics: midStripLocked || t > 0.02
                            ? const NeverScrollableScrollPhysics()
                            : const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                        padding: EdgeInsets.zero,
                        child: child,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: _expandProgress,
                          builder: (context, t, _) {
                            final homeOpacity = (1 - t).clamp(0.0, 1.0);
                            final homeSlideUp = -28.h * t;
                            final externalBarOpacity =
                                (1 - (t / 0.78)).clamp(0.0, 1.0);
                            final hideExternalAppBar = t >= 0.78;
                            return _SilverHeaderZone(
                              headerKey: _headerZoneKey,
                              expandProgress: t,
                              homeOpacity: homeOpacity,
                              homeSlideUp: homeSlideUp,
                              hideExternalAppBar: hideExternalAppBar,
                              externalBarOpacity: externalBarOpacity,
                            );
                          },
                        ),
                        SizedBox(
                          height: _panelAnchorTop > 0
                              ? HomeDraggableWidgetsPanel.collapsedHeightFor(
                                  context,
                                  screenHeight,
                                  _panelAnchorTop,
                                )
                              : HomeDraggableWidgetsPanel.peekContentHeight(
                                  context,
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (_panelAnchorTop > 0)
            HomeDraggableWidgetsPanel(
              screenHeight: screenHeight,
              panelAnchorTop: _panelAnchorTop,
              onProgressChanged: _onProgressChanged,
            ),
          ValueListenableBuilder<double>(
            valueListenable: _expandProgress,
            builder: (context, t, _) {
              return HomeFloatingCommsBar(expandProgress: t);
            },
          ),
        ],
      ),
    );
  }
}

class _SilverHeaderZone extends StatelessWidget {
  const _SilverHeaderZone({
    required this.headerKey,
    required this.expandProgress,
    required this.homeOpacity,
    required this.homeSlideUp,
    required this.hideExternalAppBar,
    required this.externalBarOpacity,
  });

  final GlobalKey headerKey;
  final double expandProgress;
  final double homeOpacity;
  final double homeSlideUp;
  final bool hideExternalAppBar;
  final double externalBarOpacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: headerKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideExternalAppBar)
          Opacity(
            opacity: externalBarOpacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 6.h),
                HomeGlassAppBar(expandProgress: expandProgress),
              ],
            ),
          )
        else
          SizedBox(height: MediaQuery.paddingOf(context).top),
        Opacity(
          opacity: homeOpacity,
          child: Transform.translate(
            offset: Offset(0, homeSlideUp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HomeGreetingSection(),
                const HomeNewsBlock(),
                const MyActionsSection(
                  dense: true,
                  showTitle: false,
                ),
                SizedBox(height: 7.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
