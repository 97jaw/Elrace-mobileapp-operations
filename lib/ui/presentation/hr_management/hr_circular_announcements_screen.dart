import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/theme/hr_service_screen_backdrop.dart';
import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_api_service.dart';
import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_model.dart';
import 'package:el_race/ui/presentation/circular_announcement/widgets/circular_announcement_file_viewer.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';

/// HR hub entry — company circulars and announcements (moved from notification screen).
class HrCircularAnnouncementsScreen extends StatefulWidget {
  const HrCircularAnnouncementsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.autoOpenItemId,
    this.autoOpenCategory,
  });

  final int initialTabIndex;
  final int? autoOpenItemId;
  final String? autoOpenCategory;

  @override
  State<HrCircularAnnouncementsScreen> createState() =>
      _HrCircularAnnouncementsScreenState();
}

class _HrCircularAnnouncementsScreenState
    extends State<HrCircularAnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final CircularAnnouncementApiService _apiService =
      CircularAnnouncementApiService();

  bool _isLoading = true;
  String? _error;
  CircularAnnouncementResponse? _data;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.fetchCircularAnnouncements();
      if (!mounted) return;
      setState(() {
        _data = response;
        _isLoading = false;
      });
      if (widget.autoOpenItemId != null && widget.autoOpenCategory != null) {
        _autoOpenItem();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _autoOpenItem() {
    if (_data == null || widget.autoOpenItemId == null) return;

    if (widget.autoOpenCategory?.toLowerCase() == 'announcement') {
      _tabController.animateTo(1);
      final item = _data!.announcements.firstWhere(
        (a) => a.id == widget.autoOpenItemId,
        orElse: () => const CircularAnnouncementItem(
          id: -1,
          title: '',
          description: '',
          category: '',
        ),
      );
      if (item.id != -1 && item.hasFile) {
        Future.delayed(const Duration(milliseconds: 400), () => _openFile(item));
      }
    } else {
      _tabController.animateTo(0);
      final item = _data!.circulars.firstWhere(
        (c) => c.id == widget.autoOpenItemId,
        orElse: () => const CircularAnnouncementItem(
          id: -1,
          title: '',
          description: '',
          category: '',
        ),
      );
      if (item.id != -1 && item.hasFile) {
        Future.delayed(const Duration(milliseconds: 400), () => _openFile(item));
      }
    }
  }

  void _openFile(CircularAnnouncementItem item) {
    if (!item.hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('circular_announcement.no_file_attached')),
          backgroundColor: HrModuleColors.warning,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CircularAnnouncementFileViewer(item: item),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: HrServiceScreenBackdrop.bodyGradient(
          HrServiceScreenKind.requests,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HrModuleGlassHeader(
              title: 'Circulars & Announcements',
              accentTint: HrModuleHeaderTints.circulars,
            ),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final circularCount = _data?.circularCount ?? 0;
    final announcementCount = _data?.announcementCount ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
      child: Container(
        height: 42.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: HrModuleColors.requestsTabTrack,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: HrModuleColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: HrModuleColors.cardShadow,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: HrModuleColors.mutedText,
          labelStyle: HrModuleTypography.caption().copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: HrModuleTypography.caption().copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'Circulars${circularCount > 0 ? ' ($circularCount)' : ''}'),
            Tab(
              text:
                  'Announcements${announcementCount > 0 ? ' ($announcementCount)' : ''}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildList(_data?.circulars ?? const [], isCircular: true),
        _buildList(_data?.announcements ?? const [], isCircular: false),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: HrModuleColors.danger),
            SizedBox(height: 12.h),
            Text(
              translate('common.error_occurred'),
              style: HrModuleTypography.cardTitle(),
            ),
            SizedBox(height: 8.h),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: HrModuleTypography.caption(),
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(translate('common.retry')),
              style: FilledButton.styleFrom(
                backgroundColor: HrModuleColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    List<CircularAnnouncementItem> items, {
    required bool isCircular,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isCircular
              ? translate('circular_announcement.no_circulars')
              : translate('circular_announcement.no_announcements'),
          style: HrModuleTypography.body().copyWith(
            color: HrModuleColors.mutedText,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16.w,
          4.h,
          16.w,
          context.systemBottomInset + 16.h,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) => _buildCard(items[index]),
      ),
    );
  }

  Widget _buildCard(CircularAnnouncementItem item) {
    final dateLabel = _formatDate(item.date);

    return Material(
      color: HrModuleColors.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(14.r),
      shadowColor: HrModuleColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => _openFile(item),
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: HrModuleColors.border.withValues(alpha: 0.55)),
            boxShadow: HrModuleColors.cardShadow,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HrModuleTypography.cardTitle().copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.hasFile)
                      Icon(
                        Icons.attach_file_rounded,
                        size: 18.sp,
                        color: HrModuleColors.secondary,
                      ),
                  ],
                ),
                if (item.displayBody.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    item.displayBody,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HrModuleTypography.body().copyWith(
                      fontSize: 12.sp,
                      color: HrModuleColors.mutedText,
                      height: 1.35,
                    ),
                  ),
                ],
                if (dateLabel.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    dateLabel,
                    style: HrModuleTypography.caption().copyWith(
                      fontSize: 11.sp,
                      color: HrModuleColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
