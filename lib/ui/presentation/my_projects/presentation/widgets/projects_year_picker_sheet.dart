import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const int _kYearsPageSize = 12;

/// Sentinel returned when the user picks "All years".
const int kProjectsYearPickerAll = -1;

/// Slide-up year picker for the projects dashboard chart.
class ProjectsYearPickerSheet {
  static Future<int?> show(
    BuildContext context, {
    required List<int> years,
    int? selectedYear,
    String title = 'Select year',
    String allLabel = 'All',
  }) {
    final items = years.isNotEmpty ? years : [DateTime.now().year];
    final selected = selectedYear ?? kProjectsYearPickerAll;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _SheetBody(
        title: title,
        years: items,
        selectedYear: selected,
        allLabel: allLabel,
      ),
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.title,
    required this.years,
    required this.selectedYear,
    required this.allLabel,
  });

  final String title;
  final List<int> years;
  final int selectedYear;
  final String allLabel;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

  int _visibleCount = _kYearsPageSize;
  bool _initialLoading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _scrollController.addListener(_onScroll);
    _entryController.forward();
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _initialLoading = false);
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<int> get _visibleYears {
    if (widget.years.length <= _visibleCount) return widget.years;
    return widget.years.sublist(0, _visibleCount);
  }

  bool get _hasMore => _visibleCount < widget.years.length;

  void _onScroll() {
    if (_initialLoading || _loadingMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + _kYearsPageSize,
        widget.years.length,
      );
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.46;
    final visible = _visibleYears;
    final extraFooter = (_hasMore || _loadingMore) ? 1 : 0;
    final showSwipeHint = _hasMore && !_loadingMore && !_initialLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SlideTransition(
        position: _slideAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.tr)),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: ProjectsDashboardTheme.pickerSheetGradient,
              ),
              child: SizedBox(
                height: sheetHeight,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.tw, 18.th, 12.tw, 8.th),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16.tsp,
                                fontWeight: FontWeight.w700,
                                color: ProjectsDashboardTheme.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: ProjectsDashboardTheme.white,
                              size: 22.tsp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showSwipeHint)
                      Text(
                        'Swipe up for more',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: ProjectsDashboardTheme.greyPanel
                              .withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    Expanded(
                      child: _initialLoading
                          ? ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                16.tw,
                                0,
                                16.tw,
                                bottomInset + 16.th,
                              ),
                              itemCount: 6,
                              separatorBuilder: (_, __) => SizedBox(height: 8.th),
                              itemBuilder: (_, __) => ProjectsShimmerBox(
                                width: double.infinity,
                                height: 48.th,
                                borderRadius: 12.tr,
                              ),
                            )
                          : widget.years.isEmpty
                              ? Center(
                                  child: Text(
                                    '—',
                                    style: GoogleFonts.poppins(
                                      color: ProjectsDashboardTheme.white,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    16.tw,
                                    0,
                                    16.tw,
                                    bottomInset + 16.th,
                                  ),
                                  itemCount: visible.length + extraFooter + 1,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: ProjectsDashboardTheme.white
                                        .withValues(alpha: 0.12),
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      final isSelected =
                                          widget.selectedYear == kProjectsYearPickerAll;
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => Navigator.pop(
                                            context,
                                            kProjectsYearPickerAll,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12.tr),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14.tw,
                                              vertical: 14.th,
                                            ),
                                            decoration: ProjectsDashboardTheme
                                                .pickerSheetTileDecoration(
                                              selected: isSelected,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  widget.allLabel,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 15.tsp,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: ProjectsDashboardTheme
                                                        .white,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: ProjectsDashboardTheme
                                                        .white,
                                                    size: 22.tsp,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final yearIndex = index - 1;
                                    if (yearIndex >= visible.length) {
                                      return Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8.th),
                                        child: Center(
                                          child: _loadingMore
                                              ? SizedBox(
                                                  width: 24.tw,
                                                  height: 24.tw,
                                                  child:
                                                      const CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: ProjectsDashboardTheme
                                                        .white,
                                                  ),
                                                )
                                              : TextButton(
                                                  onPressed: _loadMore,
                                                  child: Text(
                                                    'Load more',
                                                    style: GoogleFonts.poppins(
                                                      color: ProjectsDashboardTheme
                                                          .white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      );
                                    }

                                    final year = visible[yearIndex];
                                    final isSelected = year == widget.selectedYear;

                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: Duration(
                                        milliseconds: 220 + (index % 6) * 30,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, t, child) => Opacity(
                                        opacity: t,
                                        child: Transform.translate(
                                          offset: Offset(0, 10 * (1 - t)),
                                          child: child,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () =>
                                              Navigator.pop(context, year),
                                          borderRadius:
                                              BorderRadius.circular(12.tr),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14.tw,
                                              vertical: 14.th,
                                            ),
                                            decoration: ProjectsDashboardTheme
                                                .pickerSheetTileDecoration(
                                              selected: isSelected,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '$year',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 15.tsp,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: ProjectsDashboardTheme
                                                        .white,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: ProjectsDashboardTheme
                                                        .white,
                                                    size: 22.tsp,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
