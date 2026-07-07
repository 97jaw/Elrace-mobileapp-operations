import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_app_bar.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_panel_scroll_physics.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/hr_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/list_view_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Expandable widgets panel — one linked list (peek + expanded share the same
/// cards). Dragging resizes the panel and fades home content in sync.
class HomeDraggableWidgetsPanel extends StatefulWidget {
  const HomeDraggableWidgetsPanel({
    super.key,
    required this.screenHeight,
    required this.panelAnchorTop,
    this.onExtentChanged,
    this.onProgressChanged,
  });

  final double screenHeight;
  final double panelAnchorTop;
  final ValueChanged<double>? onExtentChanged;
  final ValueChanged<double>? onProgressChanged;

  /// Minimum content block (handle + compact header + cards).
  static double peekContentHeight(BuildContext context) {
    return 4.h + 4.h + 4.h + 28.h + 2.h + 140.h + 8.h;
  }

  /// Collapsed panel fills from [anchorTop] to above the bottom safe area.
  static double collapsedHeightFor(
    BuildContext context,
    double screenHeight,
    double anchorTop,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (anchorTop <= 0) return peekContentHeight(context);
    return (screenHeight - anchorTop - bottomInset)
        .clamp(peekContentHeight(context), screenHeight);
  }

  static double appBarBlockHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 6.h + 52.h;
  }

  static double minExtentFraction(BuildContext context, double screenHeight) {
    if (screenHeight <= 0) return 0.22;
    final peek = peekContentHeight(context);
    return (peek / screenHeight).clamp(0.12, 0.45);
  }

  static double fullExtentFraction(BuildContext context, double screenHeight) =>
      1.0;

  @override
  State<HomeDraggableWidgetsPanel> createState() =>
      _HomeDraggableWidgetsPanelState();
}

class _HomeDraggableWidgetsPanelState extends State<HomeDraggableWidgetsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final VoidCallback _expandListener;
  final ScrollController _scrollController = ScrollController();

  static const _expandDuration = Duration(milliseconds: 160);
  static const _collapseDuration = Duration(milliseconds: 140);
  static const _fullExpandThreshold = 0.98;
  static const _mergedThreshold = 0.82;
  static const _scrollEnableAt = 0.88;
  static const _scrollDisableBelow = 0.80;

  bool _scrollModeLatched = false;
  bool _scrollCollapseDragActive = false;
  double _lastReportedProgress = 0;
  double? _dragSessionStartT;

  double get _collapsedPx => HomeDraggableWidgetsPanel.collapsedHeightFor(
        context,
        widget.screenHeight,
        widget.panelAnchorTop,
      );

  double get _t => _expandController.value;

  bool get _scrollEnabled =>
      _scrollCollapseDragActive ||
      (_scrollModeLatched && _t >= _scrollDisableBelow) ||
      (!_scrollModeLatched && _t >= _scrollEnableAt);

  bool get _atScrollTop =>
      !_scrollController.hasClients || _scrollController.offset <= 0.5;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: _expandDuration,
      reverseDuration: _collapseDuration,
    );
    _expandListener = _onExpandTick;
    _expandController.addListener(_expandListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onExpandTick());
  }

  void _syncScrollModeLatch(double progress) {
    if (!_scrollModeLatched && progress >= _scrollEnableAt) {
      _scrollModeLatched = true;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else if (_scrollModeLatched &&
        !_scrollCollapseDragActive &&
        progress <= _scrollDisableBelow) {
      _scrollModeLatched = false;
    }
  }

  void _onExpandTick() {
    if (!mounted) return;
    final progress = _expandController.value;
    _syncScrollModeLatch(progress);

    final minF = HomeDraggableWidgetsPanel.minExtentFraction(
      context,
      widget.screenHeight,
    );
    final maxF = HomeDraggableWidgetsPanel.fullExtentFraction(
      context,
      widget.screenHeight,
    );
    widget.onExtentChanged?.call(minF + (maxF - minF) * progress);

    if ((progress - _lastReportedProgress).abs() >= 0.0015 ||
        progress == 0 ||
        progress == 1) {
      _lastReportedProgress = progress;
      widget.onProgressChanged?.call(progress);
    }
  }

  void _snapTo(double target) {
    _expandController.animateTo(
      target,
      duration: target > _t ? _expandDuration : _collapseDuration,
      curve: target > _t ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  void _expand() => _snapTo(1.0);

  void _collapse() {
    if (_t <= 0) return;
    if (_scrollController.hasClients && _scrollController.offset > 1) {
      _scrollController.jumpTo(0);
    }
    _snapTo(0.0);
  }

  void _toggle() {
    if (_t > 0.5) {
      _collapse();
    } else {
      _expand();
    }
  }

  void _applyDragDelta(double dy, {bool fromScroll = false}) {
    final range = widget.screenHeight - _collapsedPx;
    if (range <= 0) return;
    if (fromScroll) {
      _scrollCollapseDragActive = true;
    }
    // Slightly higher sensitivity so expand/collapse tracks the finger faster.
    _expandController.value =
        (_t - (dy * 1.38) / range).clamp(0.0, 1.0);
  }

  void _onDragStart(DragStartDetails details) {
    _dragSessionStartT = _t;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_scrollEnabled && !_atScrollTop && details.delta.dy < 0) {
      return;
    }
    if (_scrollModeLatched && _atScrollTop && details.delta.dy > 0) {
      _scrollCollapseDragActive = true;
    }
    _applyDragDelta(details.delta.dy);
  }

  void _resolveSnap({double? velocity}) {
    _scrollCollapseDragActive = false;
    _syncScrollModeLatch(_t);
    _lastReportedProgress = -1;
    _onExpandTick();

    final startT = _dragSessionStartT ?? _t;
    _dragSessionStartT = null;

    if (velocity != null) {
      if (velocity < -280) {
        _expand();
        return;
      }
      if (velocity > 280) {
        _collapse();
        return;
      }
    }

    // Peek: any upward pull expands fully — never rest half-open from home.
    if (startT < 0.15) {
      if (_t > 0.02) {
        _expand();
      } else {
        _collapse();
      }
      return;
    }

    // Expanded collapse: commit to collapsed unless still nearly full.
    if (startT > 0.85) {
      if (_t < 0.94) {
        _collapse();
      } else {
        _expand();
      }
      return;
    }

    // Mid-travel: always finish to an end state (never stick in the middle).
    if (_t >= 0.5) {
      _expand();
    } else {
      _collapse();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _resolveSnap(velocity: details.primaryVelocity);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final wasCollapsing = _scrollCollapseDragActive;
      final partial = _t > 0.02 && _t < 0.98;
      if (wasCollapsing || (partial && _atScrollTop)) {
        _resolveSnap(velocity: notification.dragDetails?.primaryVelocity);
      }
    }
    return false;
  }

  @override
  void dispose() {
    _expandController.removeListener(_expandListener);
    _expandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildListContent({
    required double t,
    required double headerHandoff,
    required Widget listChild,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: _LinkedWidgetList(
        expandProgress: t,
        headerHandoff: headerHandoff,
        listChild: listChild,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final anchorTop = widget.panelAnchorTop;
    final statusTop = MediaQuery.paddingOf(context).top;
    final collapsedH = _collapsedPx;

    return AnimatedBuilder(
      animation: _expandController,
      builder: (context, listChild) {
        final t = _t;
        final top = anchorTop * (1 - t);
        final height = collapsedH + (widget.screenHeight - collapsedH) * t;
        final fullyExpanded = t >= _fullExpandThreshold;
        final merged = t >= _mergedThreshold;
        final mergedOpacity =
            ((t - _mergedThreshold) / (1 - _mergedThreshold)).clamp(0.0, 1.0);

        final topRadius = merged ? 0.0 : 28.r * (1 - t * 0.85);
        final panelRadius =
            BorderRadius.vertical(top: Radius.circular(topRadius));

        final headerHandoff = ((t - 0.78) / 0.20).clamp(0.0, 1.0);
        final panelHeaderOpacity = (1 - headerHandoff).clamp(0.0, 1.0);
        final compactHeader = headerHandoff < 0.15;

        final listContent = _buildListContent(
          t: t,
          headerHandoff: headerHandoff,
          listChild: listChild ?? const ListViewWidgets(hideFeaturedHeader: true),
        );

        // Peek: no inner scroll — entire section drags to expand.
        // Expanded: list scrolls with bounce; top overscroll collapses panel.
        final Widget panelBody;
        if (_scrollEnabled) {
          panelBody = NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: HomePanelScrollPhysics(
                onCollapseDrag: (dy) => _applyDragDelta(dy, fromScroll: true),
                parent: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
              ),
              padding: EdgeInsets.only(bottom: bottomInset + 110.h),
              child: Align(
                alignment: Alignment.topCenter,
                child: listContent,
              ),
            ),
          );
        } else {
          panelBody = LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                behavior: HitTestBehavior.opaque,
                child: ClipRect(
                  child: SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      maxWidth: constraints.maxWidth,
                      child: listContent,
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: HomeGlassTheme.widgetsPanelShell(
            borderRadius: panelRadius,
            merged: merged,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (merged)
                  Opacity(
                    opacity: mergedOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: statusTop + 4.h),
                        const HomeGlassAppBar(mergedMode: true),
                      ],
                    ),
                  ),
                _WidgetsPanelHeader(
                  fullyExpanded: fullyExpanded,
                  panelHeaderOpacity: panelHeaderOpacity,
                  compactHeader: compactHeader,
                  onHeaderTap: _toggle,
                  onDragStart: _onDragStart,
                  onDragUpdate: _onDragUpdate,
                  onDragEnd: _onDragEnd,
                ),
                Expanded(child: panelBody),
              ],
            ),
          ),
        );
      },
      child: const ListViewWidgets(hideFeaturedHeader: true),
    );
  }
}

/// One widget list; HR header crossfades from panel chrome into the scroll body.
class _LinkedWidgetList extends StatelessWidget {
  const _LinkedWidgetList({
    required this.expandProgress,
    required this.headerHandoff,
    required this.listChild,
  });

  final double expandProgress;
  final double headerHandoff;
  final Widget listChild;

  @override
  Widget build(BuildContext context) {
    final veilStrength = (1 - ((expandProgress - 0.05) / 0.7)).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (headerHandoff > 0.01)
              Opacity(
                opacity: headerHandoff,
                child: Transform.translate(
                  offset: Offset(0, -14.h * (1 - headerHandoff)),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: const HrCategorySectionHeader(),
                  ),
                ),
              ),
            listChild,
          ],
        ),
        if (veilStrength > 0.02)
          Positioned(
            left: -16.w,
            right: -16.w,
            top: 150.h,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HomeGlassTheme.silverLeft
                          .withValues(alpha: 0.72 * veilStrength),
                      HomeGlassTheme.silverLeft
                          .withValues(alpha: 0.2 * veilStrength),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WidgetsPanelHeader extends StatelessWidget {
  const _WidgetsPanelHeader({
    required this.fullyExpanded,
    required this.panelHeaderOpacity,
    required this.compactHeader,
    required this.onHeaderTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool fullyExpanded;
  final double panelHeaderOpacity;
  final bool compactHeader;
  final VoidCallback onHeaderTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      onTap: onHeaderTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: fullyExpanded ? 4.h : 4.h),
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (!fullyExpanded && panelHeaderOpacity > 0.01)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 2.h),
              child: Opacity(
                opacity: panelHeaderOpacity,
                child: Transform.translate(
                  offset: Offset(0, -10.h * (1 - panelHeaderOpacity)),
                  child: HrCategorySectionHeader(compact: compactHeader),
                ),
              ),
            )
          else if (fullyExpanded)
            SizedBox(height: 6.h),
        ],
      ),
    );
  }
}

/// Static body kept for compatibility.
class HomeWidgetsPanelBody extends StatelessWidget {
  const HomeWidgetsPanelBody({
    super.key,
    this.onViewAll,
  });

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return HomeDraggableWidgetsPanel(
      screenHeight: screenHeight,
      panelAnchorTop: screenHeight * 0.55,
    );
  }
}
