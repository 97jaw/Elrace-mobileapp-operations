import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

typedef PurchaseListItemBuilder = Widget Function(BuildContext context, int index);

class PurchaseHubListScaffold extends StatelessWidget {
  const PurchaseHubListScaffold({
    super.key,
    required this.title,
    required this.searchController,
    required this.itemCount,
    required this.itemBuilder,
    this.segmentLabels,
    this.selectedSegment = 0,
    this.onSegmentChanged,
    this.filterValues,
    this.filterLabels,
    this.selectedFilter = '',
    this.onFilterChanged,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.onRefresh,
    this.scrollController,
    this.searchHint = 'Search…',
    this.lockFilters = false,
  });

  final String title;
  final TextEditingController searchController;
  final int itemCount;
  final PurchaseListItemBuilder itemBuilder;
  final List<String>? segmentLabels;
  final int selectedSegment;
  final ValueChanged<int>? onSegmentChanged;
  final List<String>? filterValues;
  final List<String>? filterLabels;
  final String selectedFilter;
  final ValueChanged<String>? onFilterChanged;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;
  final String searchHint;
  final bool lockFilters;

  @override
  Widget build(BuildContext context) {
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            PurchaseManagementGlassHeader(
              title: title,
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  if (segmentLabels != null && segmentLabels!.isNotEmpty)
                    _SegmentControl(
                      labels: segmentLabels!,
                      selected: selectedSegment,
                      onChanged: onSegmentChanged,
                    ),
                  PurchaseSearchBar(
                    controller: searchController,
                    hint: searchHint,
                  ),
                  if (!lockFilters &&
                      filterValues != null &&
                      filterLabels != null &&
                      onFilterChanged != null)
                    PurchaseFilterChips(
                      filters: filterValues!,
                      labels: filterLabels!,
                      selected: selectedFilter,
                      onSelect: onFilterChanged!,
                    ),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
      );
    }
    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.sp),
        ),
      );
    }
    if (itemCount == 0) {
      return Center(
        child: Text(
          translate('home.purchase.no_records'),
          style: GoogleFonts.poppins(
            color: PurchaseTheme.textMuted,
            fontSize: 14.sp,
          ),
        ),
      );
    }

    final list = ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: itemCount + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == itemCount) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
            ),
          );
        }
        return itemBuilder(context, index);
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(
      color: PurchaseTheme.accentBlue,
      onRefresh: onRefresh!,
      child: list,
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({
    required this.labels,
    required this.selected,
    this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 4.h),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: PurchaseTheme.glassPanel(radius: 14.r),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: onChanged == null ? null : () => onChanged!(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: selected == i
                          ? PurchaseTheme.accentBlue.withValues(alpha: 0.88)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5.sp,
                        fontWeight:
                            selected == i ? FontWeight.w600 : FontWeight.w400,
                        color: selected == i
                            ? Colors.white
                            : PurchaseTheme.textSecondary,
                      ),
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

/// Glass list row wrapper used across hub drill-down screens.
class PurchaseGlassListCard extends StatelessWidget {
  const PurchaseGlassListCard({
    super.key,
    required this.child,
    this.onTap,
    this.urgent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: urgent
            ? PurchaseTheme.glassCard(radius: 14.r).copyWith(
                border: Border.all(
                  color: PurchaseTheme.urgentOrange.withValues(alpha: 0.45),
                ),
              )
            : PurchaseTheme.glassCard(radius: 14.r),
        padding: EdgeInsets.all(14.w),
        child: child,
      ),
    );
  }
}
