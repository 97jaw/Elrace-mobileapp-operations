import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:el_race/ui/presentation/News%20Banner/news_detail_screen_api.dart';
import 'package:el_race/ui/presentation/News%20Banner/news_screen.dart';
import 'package:el_race/ui/presentation/home_screen/provider/slider_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_section.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/mid_section_scroll_lock.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// News card + check-in/prayer strip — strip centered on card bottom edge.
class HomeNewsBlock extends StatefulWidget {
  const HomeNewsBlock({super.key, this.tabletLayout = false});

  /// Tablet mid pane: tighter insets, taller news + mid strip.
  final bool tabletLayout;

  static const horizontalInset = 16.0;
  static const stripHorizontalInset = 8.0;

  /// Scales with screen height but stays within readable bounds.
  static double _responsiveH(double design, {required double min, required double max}) {
    return design.clamp(min, max);
  }

  static double stripHeight(
    BuildContext context, {
    MidSectionMode mode = MidSectionMode.dual,
  }) =>
      HomeMidSection.expandedHeight(context, mode);

  /// Portion that sits on top of the news card (visual overlap).
  static double stripOverlap(
    BuildContext context, {
    MidSectionMode mode = MidSectionMode.dual,
  }) =>
      stripHeight(context, mode: mode) * 0.25;

  /// Clear space between mid strip bottom and My Actions top.
  static double stripGapToActions(BuildContext context) =>
      _responsiveH(8.uh, min: 6, max: 12);

  /// Room for the strip drop-shadow so it does not bleed onto My Actions.
  static double stripShadowBleed(BuildContext context) =>
      _responsiveH(6.uh, min: 4, max: 10);

  /// Column height for the strip slot (hang below card + gap, minus overlap).
  static double stripSlotHeight(
    BuildContext context, {
    MidSectionMode mode = MidSectionMode.dual,
  }) {
    final h = stripHeight(context, mode: mode);
    final overlap = stripOverlap(context, mode: mode);
    final belowCard = h - overlap;
    return belowCard +
        stripGapToActions(context) +
        stripShadowBleed(context);
  }

  @override
  State<HomeNewsBlock> createState() => _HomeNewsBlockState();
}

class _HomeNewsBlockState extends State<HomeNewsBlock> {
  MidSectionMode _midMode = MidSectionMode.dual;

  @override
  Widget build(BuildContext context) {
    final overlap =
        HomeNewsBlock.stripOverlap(context, mode: _midMode);
    final slotHeight =
        HomeNewsBlock.stripSlotHeight(context, mode: _midMode);
    final stripH =
        HomeNewsBlock.stripHeight(context, mode: _midMode);
    final newsCardH = _HomeNewsCardState.cardHeight(
      context,
      tabletLayout: widget.tabletLayout,
    );
    final hInset = widget.tabletLayout ? 8.0 : HomeNewsBlock.horizontalInset.w;
    final stripInset =
        widget.tabletLayout ? 4.0 : HomeNewsBlock.stripHorizontalInset.w;
    final tabletStripBoost = widget.tabletLayout ? 28.0 : 0.0;
    final tabletStripHBoost = widget.tabletLayout ? 16.0 : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hInset,
        widget.tabletLayout ? 6.0 : 10.uh,
        hInset,
        0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HomeNewsCard(
                midMode: _midMode,
                tabletLayout: widget.tabletLayout,
              ),
              SizedBox(height: slotHeight + tabletStripBoost),
            ],
          ),
          Positioned(
            top: newsCardH - overlap,
            left: stripInset,
            right: stripInset,
            height: stripH + tabletStripHBoost,
            child: _MidSectionScrollWrapper(
              child: HomeMidSection(
                onModeChanged: (mode) {
                  if (_midMode == mode) return;
                  setState(() => _midMode = mode);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeNewsCard extends StatefulWidget {
  const HomeNewsCard({
    super.key,
    this.midMode = MidSectionMode.dual,
    this.tabletLayout = false,
  });

  final MidSectionMode midMode;
  final bool tabletLayout;

  static double resolveHeight(
    BuildContext context, {
    bool tabletLayout = false,
  }) =>
      _HomeNewsCardState.cardHeight(context, tabletLayout: tabletLayout);

  @override
  State<HomeNewsCard> createState() => _HomeNewsCardState();
}

class _HomeNewsCardState extends State<HomeNewsCard> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  static const _fallbackImages = [
    'assets/jpeg/slide_1_c.jpg',
    'assets/jpeg/slide_2_c.jpg',
    'assets/jpeg/slide_3_c.jpg',
    'assets/jpeg/slide_4_c.jpg',
  ];

  static const _fallbackHeadlines = [
    'Closing ceremony marks handover of Um Kolthoom School',
    'Successfully delivered on schedule, the project highlights efficiency',
    'Stakeholders have praised the project for its efficiency',
    'A closing ceremony was held to commemorate the achievement',
  ];

  static const _cardBorderColor = Color(0xFFE6EAF0);
  static const _cardDesignHeight = 272.0;

  static double cardHeight(
    BuildContext context, {
    bool tabletLayout = false,
  }) {
    if (tabletLayout) {
      // Uniform tablet scale: both axes follow scaleWidth, so the card keeps
      // the exact phone aspect (272/360) — no landscape compensation needed.
      return _cardDesignHeight.uh;
    }
    final base = _cardDesignHeight.h;
    final ratio = ScreenUtil().scaleWidth / ScreenUtil().scaleHeight;
    var h = base;
    if (ratio > 1.05) {
      h = base * ratio.clamp(1.0, 1.65);
    }
    return h;
  }

  /// Sits above the mid strip overlap on the news card (phone). On tablet
  /// the strip is below the card — no overlap to clear, keep a clean inset.
  double _newsControlsBottom(BuildContext context) {
    if (widget.tabletLayout) return 14.uh;
    return HomeNewsBlock.stripOverlap(context) + 10.uh;
  }

  @override
  Widget build(BuildContext context) {
    final slider = context.watch<SliderProvider>();
    final count =
        slider.titles.isEmpty ? _fallbackHeadlines.length : slider.titles.length;
    final cardH = cardHeight(context, tabletLayout: widget.tabletLayout);
    return SizedBox(
      height: cardH,
      child: slider.isLoading
          ? _cardShell(
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : CarouselSlider.builder(
              carouselController: _carouselController,
              itemCount: count,
              options: CarouselOptions(
                height: cardH,
                viewportFraction: 1,
                enableInfiniteScroll: count > 1,
                autoPlay: count > 1,
                autoPlayInterval: const Duration(seconds: 6),
                // Strip overlaps the card — disable swipe so taps reach the mid section.
                scrollPhysics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i, _) => slider.setCurrentIndex(i),
              ),
              itemBuilder: (context, itemIndex, _) {
                final imageUrl = _imageAt(slider, itemIndex);
                final isNetwork =
                    imageUrl.startsWith('http') && slider.hasApiData;

                return _cardShell(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isNetwork)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Image.asset(
                              _fallbackImages[
                                  itemIndex % _fallbackImages.length],
                              fit: BoxFit.cover,
                            ),
                            errorWidget: (_, __, ___) => Image.asset(
                              _fallbackImages[
                                  itemIndex % _fallbackImages.length],
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Image.asset(imageUrl, fit: BoxFit.cover),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.72),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14.uh,
                          left: 14.w,
                          child: _projectUpdatePill(),
                        ),
                        Positioned(
                          top: 14.uh,
                          right: 14.w,
                          child: _counterPill(
                            slider.currentIndex + 1,
                            count,
                          ),
                        ),
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: _newsControlsBottom(context),
                          child: _bottomContent(
                            headline: _headlineAt(slider, itemIndex),
                            dateLabel: _dateLabelAt(itemIndex),
                            dotCount: count,
                            activeIndex: slider.currentIndex,
                            onRead: () => _openNewsDetail(context, itemIndex),
                            onSeeMore: () =>
                                Util.pushPage(const NewsScreen(), context),
                            onDotTap: (index) {
                              _carouselController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
              },
            ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.ur),
        border: Border.all(color: _cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19.ur),
        child: child,
      ),
    );
  }

  Widget _projectUpdatePill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.uh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            'PROJECT UPDATE',
            style: GoogleFonts.poppins(
              fontSize: 9.usp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterPill(int current, int total) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.uh),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$current / $total',
        style: GoogleFonts.poppins(
          fontSize: 11.usp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _bottomContent({
    required String headline,
    required String dateLabel,
    required int dotCount,
    required int activeIndex,
    required VoidCallback onRead,
    required VoidCallback onSeeMore,
    required ValueChanged<int> onDotTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 16.usp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.25,
          ),
        ),
        SizedBox(height: 8.uh),
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 11.usp, color: Colors.white70),
            SizedBox(width: 4.w),
            Text(
              dateLabel,
              style: GoogleFonts.poppins(
                fontSize: 11.usp,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(width: 12.w),
            Icon(Icons.schedule, size: 11.usp, color: Colors.white70),
            SizedBox(width: 4.w),
            Text(
              '4 min read',
              style: GoogleFonts.poppins(
                fontSize: 11.usp,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.uh),
        _newsControls(
          dotCount: dotCount,
          activeIndex: activeIndex,
          onRead: onRead,
          onSeeMore: onSeeMore,
          onDotTap: onDotTap,
        ),
      ],
    );
  }

  Widget _newsControls({
    required int dotCount,
    required int activeIndex,
    required VoidCallback onRead,
    required VoidCallback onSeeMore,
    required ValueChanged<int> onDotTap,
  }) {
    return SizedBox(
      height: 32.uh,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(dotCount.clamp(1, 6), (i) {
                final active = i == activeIndex;
                return GestureDetector(
                  onTap: () => onDotTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: active ? 18.w : 6.w,
                    height: 6.uh,
                    margin: EdgeInsets.only(right: 5.w),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
          _newsActionButton(
            onTap: onRead,
            child: Text(
              'Read',
              style: GoogleFonts.poppins(
                fontSize: 11.usp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          _newsActionButton(
            onTap: onSeeMore,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 16.usp,
            ),
          ),
        ],
      ),
    );
  }

  /// Glass circle/pill — only explicit news actions use this (not the whole card).
  Widget _newsActionButton({
    required VoidCallback onTap,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32.uh,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 12.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }

  String _imageAt(SliderProvider slider, int index) {
    if (slider.sliderImages.isEmpty) {
      return _fallbackImages[index % _fallbackImages.length];
    }
    return slider.sliderImages[index % slider.sliderImages.length];
  }

  String _headlineAt(SliderProvider slider, int index) {
    if (slider.titles.isEmpty) {
      return _fallbackHeadlines[index % _fallbackHeadlines.length];
    }
    return slider.titles[index % slider.titles.length];
  }

  String _dateLabelAt(int index) {
    return DateFormat('d MMM yyyy').format(
      DateTime.now().subtract(Duration(days: index)),
    );
  }

  void _openNewsDetail(BuildContext context, int index) {
    final slider = context.read<SliderProvider>();
    final item = slider.announcementAt(index);
    Util.pushPage(
      NewsDetailScreenAPI(newsItem: item),
      context,
    );
  }
}

/// Pauses parent scroll while interacting with the mid strip.
class _MidSectionScrollWrapper extends StatelessWidget {
  const _MidSectionScrollWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = MidSectionScrollLock.read(context);
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => lock?.value = true,
      onPointerUp: (_) => lock?.value = false,
      onPointerCancel: (_) => lock?.value = false,
      child: child,
    );
  }
}
