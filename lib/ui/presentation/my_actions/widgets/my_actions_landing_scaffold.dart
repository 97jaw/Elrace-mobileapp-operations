import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_action_list_tile.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_all_sheet.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_glass_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyActionsLandingScaffold extends StatelessWidget {
  const MyActionsLandingScaffold({
    super.key,
    required this.module,
    required this.items,
    required this.loading,
    this.error,
    required this.onRefresh,
    required this.onRetry,
    required this.onItemTap,
    required this.filter,
    required this.onFilterChanged,
    required this.onShowAll,
    this.subtitleBuilder,
    this.underPlanning = false,
    this.planningMessage =
        'This section is under planning.\nFull features coming soon.',
  });

  final MyActionsModule module;
  final List<MyActionItem> items;
  final bool loading;
  final Object? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(MyActionItem item) onItemTap;
  final MyActionFilter filter;
  final ValueChanged<MyActionFilter> onFilterChanged;
  final VoidCallback onShowAll;
  final String? Function(MyActionItem item)? subtitleBuilder;
  final bool underPlanning;
  final String planningMessage;

  MyActionsModuleTheme get theme => MyActionsModuleTheme.of(module);

  int _count(MyActionFilter f) =>
      items.where((i) => MyActionsModuleTheme.matchesFilter(i.status, f)).length;

  List<MyActionItem> get _filtered => items
      .where((i) => MyActionsModuleTheme.matchesFilter(i.status, filter))
      .toList();

  String get _slogan {
    if (underPlanning) return 'Under planning';
    return MyActionsModuleTheme.slogan(
      pending: _count(MyActionFilter.pending),
      total: items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MyActionsModuleTheme.lightOnGradient,
      child: Scaffold(
        backgroundColor: MyActionsModuleTheme.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: theme.gradient)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MyActionsGlassHeader(),
                Expanded(
                  child: loading
                      ? Center(
                          child: CircularProgressIndicator(color: theme.primary),
                        )
                      : error != null && items.isEmpty && !underPlanning
                          ? _ErrorBody(theme: theme, onRetry: onRetry)
                          : RefreshIndicator(
                              color: theme.primary,
                              onRefresh: onRefresh,
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: [
                                  SliverToBoxAdapter(child: _HeroSection()),
                                  SliverToBoxAdapter(child: _BodySection()),
                                  SliverToBoxAdapter(child: SizedBox(height: 32.h)),
                                ],
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

  Widget _HeroSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                theme.iconAsset,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(theme.title, style: theme.heroTitle),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(_slogan, style: theme.heroSlogan),
          if (!underPlanning) ...[
            SizedBox(height: 22.h),
            _QuickActionsRow(
              theme: theme,
              active: filter,
              onSelected: onFilterChanged,
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    theme: theme,
                    label: 'Pending',
                    value: '${_count(MyActionFilter.pending)}',
                    icon: Icons.hourglass_top_rounded,
                    tint: MyActionsModuleTheme.pending,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    theme: theme,
                    label: 'Approved',
                    value: '${_count(MyActionFilter.approved)}',
                    icon: Icons.check_circle_outline_rounded,
                    tint: MyActionsModuleTheme.approved,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _BodySection() {
    if (underPlanning) {
      return Transform.translate(
        offset: Offset(0, -12.h),
        child: Container(
          decoration: BoxDecoration(
            color: MyActionsModuleTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 40.h, 24.w, 48.h),
            child: Column(
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 56.sp,
                  color: theme.primary.withValues(alpha: 0.75),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Under planning',
                  style: theme.sectionTitle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  planningMessage,
                  textAlign: TextAlign.center,
                  style: theme.cardSubtitle.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final recent = _filtered.take(4).toList();

    return Transform.translate(
      offset: Offset(0, -12.h),
      child: Container(
        decoration: BoxDecoration(
          color: MyActionsModuleTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          boxShadow: [
            BoxShadow(
              color: theme.deep.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Recent', style: theme.sectionTitle),
                  const Spacer(),
                  TextButton(
                    onPressed: onShowAll,
                    child: Text(
                      'Show all',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              if (recent.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48.sp,
                          color: MyActionsModuleTheme.textMuted,
                        ),
                        SizedBox(height: 10.h),
                        Text('No requests in this view', style: theme.cardSubtitle),
                      ],
                    ),
                  ),
                )
              else
                ...recent.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: MyActionListTile(
                      item: item,
                      theme: theme,
                      subtitle: subtitleBuilder?.call(item),
                      onTap: () => onItemTap(item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.theme,
    required this.active,
    required this.onSelected,
  });

  final MyActionsModuleTheme theme;
  final MyActionFilter active;
  final ValueChanged<MyActionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAction(
          theme: theme,
          icon: Icons.layers_rounded,
          label: 'All',
          selected: active == MyActionFilter.all,
          onTap: () => onSelected(MyActionFilter.all),
        ),
        SizedBox(width: 8.w),
        _QuickAction(
          theme: theme,
          icon: Icons.schedule_rounded,
          label: 'Pending',
          selected: active == MyActionFilter.pending,
          onTap: () => onSelected(MyActionFilter.pending),
        ),
        SizedBox(width: 8.w),
        _QuickAction(
          theme: theme,
          icon: Icons.check_rounded,
          label: 'Approved',
          selected: active == MyActionFilter.approved,
          onTap: () => onSelected(MyActionFilter.approved),
        ),
        SizedBox(width: 8.w),
        _QuickAction(
          theme: theme,
          icon: Icons.close_rounded,
          label: 'Rejected',
          selected: active == MyActionFilter.rejected,
          onTap: () => onSelected(MyActionFilter.rejected),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final MyActionsModuleTheme theme;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 13.h),
            decoration: BoxDecoration(
              color: selected ? theme.primary : MyActionsModuleTheme.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected ? theme.primary : MyActionsModuleTheme.white,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.14 : 0.1),
                  blurRadius: selected ? 10 : 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 21.sp,
                  color: selected
                      ? MyActionsModuleTheme.white
                      : theme.primary,
                ),
                SizedBox(height: 5.h),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? MyActionsModuleTheme.white
                        : MyActionsModuleTheme.textDark,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.theme,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final MyActionsModuleTheme theme;
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: theme.statCard(),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: MyActionsModuleTheme.textDark,
                  ),
                ),
                Text(label, style: theme.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.theme, required this.onRetry});

  final MyActionsModuleTheme theme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load requests', style: theme.heroSlogan),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(color: MyActionsModuleTheme.white),
            ),
          ),
        ],
      ),
    );
  }
}

void showMyActionsAllSheet({
  required BuildContext context,
  required MyActionsModule module,
  required MyActionFilter filter,
  required void Function(MyActionItem item) onItemTap,
  String? Function(MyActionItem item)? subtitleBuilder,
}) {
  final theme = MyActionsModuleTheme.of(module);
  final type = MyActionsModuleTheme.apiTypeFor(module);
  if (type == null) return;

  MyActionsAllSheet.show(
    context,
    theme: theme,
    actionsType: type,
    initialFilter: filter,
    onItemTap: onItemTap,
    subtitleBuilder: subtitleBuilder,
  );
}
