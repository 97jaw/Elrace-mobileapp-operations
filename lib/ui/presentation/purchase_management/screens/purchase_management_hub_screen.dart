import 'package:el_race/core/purchase/purchase_access.dart';
import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/draft_invoice_list_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_lpo_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_mr_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_rfq_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/utils/purchase_number_format.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_compact_hub_card.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_dev_role_toggle_bar.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hero_card.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hub_view_switch.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_management_ai_view.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_management_analytics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

class PurchaseManagementHubScreen extends ConsumerStatefulWidget {
  const PurchaseManagementHubScreen({super.key});

  @override
  ConsumerState<PurchaseManagementHubScreen> createState() =>
      _PurchaseManagementHubScreenState();
}

class _PurchaseManagementHubScreenState
    extends ConsumerState<PurchaseManagementHubScreen> {
  PurchaseHubViewMode _viewMode = PurchaseHubViewMode.hub;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(purchaseAccessProvider);
    final testRole = ref.watch(purchaseDevRoleOverrideProvider);
    final overviewAsync = ref.watch(purchaseOverviewProvider);
    final isManagement = access.isCostControlOrManagement;

    if (access.canSeeDraftInvoices) {
      ref.watch(draftInvoicesPreviewProvider);
    }

    if (!access.hasAnyAccess) {
      return const _UnauthorizedView();
    }

    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
              children: [
                PurchaseManagementGlassHeader(
                  title: translate('home.purchase_management'),
                  showBack: true,
                  onBack: () => Navigator.pop(context),
                ),
                const PurchaseDevRoleToggleBar(),
                if (access.scopeLabel.isNotEmpty &&
                    _viewMode == PurchaseHubViewMode.hub)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        access.scopeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: PurchaseTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _buildBody(
                    access: access,
                    testRole: testRole,
                    overviewAsync: overviewAsync,
                    isManagement: isManagement,
                  ),
                ),
              ],
            ),
            if (isManagement)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PurchaseHubFloatingViewBar(
                  mode: _viewMode,
                  onHubTap: () =>
                      setState(() => _viewMode = PurchaseHubViewMode.hub),
                  onAnalyticsTap: () => setState(
                      () => _viewMode = PurchaseHubViewMode.analytics),
                  onAiTap: () =>
                      setState(() => _viewMode = PurchaseHubViewMode.ai),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required PurchaseAccess access,
    required PurchaseDevTestRole? testRole,
    required AsyncValue<PurchaseOverview> overviewAsync,
    required bool isManagement,
  }) {
    final bottomPad = isManagement
        ? PurchaseHubViewBarLayout.scrollBottomPadding(context)
        : 24.h;

    if (_viewMode == PurchaseHubViewMode.ai && isManagement) {
      return PurchaseManagementAiView(bottomPadding: bottomPad);
    }

    if (_viewMode == PurchaseHubViewMode.analytics && isManagement) {
      return PurchaseManagementAnalyticsView(bottomPadding: bottomPad);
    }

    return overviewAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
      ),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.sp),
        ),
      ),
      data: (overview) => _HubBody(
        overview: overview,
        access: access,
        testRole: testRole,
        compactLayout: _useCompactLayout(access),
        bottomPadding: bottomPad,
      ),
    );
  }

  bool _useCompactLayout(PurchaseAccess access) =>
      access.isPurchaseManager || access.isCostControlOrManagement;
}

class _HubBody extends ConsumerWidget {
  const _HubBody({
    required this.overview,
    required this.access,
    required this.testRole,
    required this.compactLayout,
    required this.bottomPadding,
  });

  final PurchaseOverview overview;
  final PurchaseAccess access;
  final PurchaseDevTestRole? testRole;
  final bool compactLayout;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = overview.cards;
    return RefreshIndicator(
      color: PurchaseTheme.accentBlue,
      onRefresh: () async {
        ref.invalidate(draftInvoicesPreviewProvider);
        final repo = ref.read(purchaseRepositoryProvider);
        final testRole = ref.read(purchaseDevRoleOverrideProvider);
        await repo.fetchOverview(testRole: testRole, refresh: true);
        await repo.fetchDraftInvoicesPreview(
          testRole: testRole,
          refresh: true,
        );
        ref.invalidate(purchaseOverviewProvider);
        await ref.read(purchaseOverviewProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, bottomPadding),
        children: [
          if (compactLayout) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Expanded(
                    child: PurchaseCompactHubCard(
                      title: 'RFQs',
                      primaryValue: formatPurchaseCompact(cards.waitingRfqs),
                      valueColor: PurchaseTheme.accentDeep,
                      icon: Icons.request_quote_outlined,
                      iconColor: const Color(0xFF0D9488),
                      iconBackground: const Color(0xFFCCFBF1),
                      badge: cards.rfqQuotationsReceived > 0
                          ? 'QUOTES'
                          : 'WAITING',
                      trendLabel: cards.rfqQuotationsReceived > 0
                          ? '${formatPurchaseCompact(cards.rfqQuotationsReceived)} recv'
                          : '${formatPurchaseCompact(cards.totalRfqs)} total',
                      trendPositive: cards.rfqQuotationsReceived > 0,
                      subtitle: 'Waiting validation',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PurchaseRfqHubScreen(testRole: testRole),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: PurchaseCompactHubCard(
                      title: 'Material Req.',
                      primaryValue: formatPurchaseCompact(cards.pendingMrs),
                      valueColor: const Color(0xFF7C3AED),
                      icon: Icons.assignment_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBackground: const Color(0xFFEDE9FE),
                      badge: 'PENDING',
                      trendLabel:
                          cards.pendingMrs > 0 ? 'Action' : 'Clear',
                      trendPositive: cards.pendingMrs == 0,
                      subtitle: 'Awaiting approval',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PurchaseMrHubScreen(testRole: testRole),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: 10.h),
            PurchaseCompactLpoStrip(
              openCount: cards.lposOpen,
              closedCount: cards.lposClosed,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseLpoHubScreen(testRole: testRole),
                ),
              ),
            ),
          ] else ...[
            PurchaseHeroCard(
              title: 'RFQs',
              subtitle: 'Waiting validation & quotations',
              metrics: [
                PurchaseHeroMetric(
                  label: 'Waiting',
                  value: formatPurchaseCompact(cards.waitingRfqs),
                ),
                PurchaseHeroMetric(
                  label: 'Total',
                  value: formatPurchaseCompact(cards.totalRfqs),
                ),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseRfqHubScreen(testRole: testRole),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            PurchaseHeroCard(
              title: 'LPOs',
              subtitle: 'Confirmed purchase orders',
              metrics: [
                PurchaseHeroMetric(
                  label: 'Open',
                  value: formatPurchaseCompact(cards.lposOpen),
                ),
                PurchaseHeroMetric(
                  label: 'Closed',
                  value: formatPurchaseCompact(cards.lposClosed),
                ),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseLpoHubScreen(testRole: testRole),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            PurchaseHeroCard(
              title: 'Material Requests',
              subtitle: 'Pending approval',
              gradient: PurchaseTheme.mrHeroGradient,
              borderColor: PurchaseTheme.mrBorderColor,
              icon: Icons.assignment_outlined,
              metrics: [
                PurchaseHeroMetric(
                  label: 'Pending',
                  value: formatPurchaseCompact(cards.pendingMrs),
                ),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseMrHubScreen(testRole: testRole),
                ),
              ),
            ),
          ],
          if (access.canSeeDraftInvoices) ...[
            SizedBox(height: compactLayout ? 12.h : 20.h),
            _DraftInvoicesSection(testRole: testRole),
          ],
        ],
      ),
    );
  }
}

class _DraftInvoicesSection extends ConsumerWidget {
  const _DraftInvoicesSection({required this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(draftInvoicesPreviewProvider);

    return previewAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Draft Purchase Invoices',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: PurchaseTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 100.h,
            decoration: PurchaseTheme.glassPanel(),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              color: PurchaseTheme.accentBlue,
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (preview) {
        if (preview.items.isEmpty && preview.totalCount == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Draft Purchase Invoices',
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.textPrimary,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    gradient: PurchaseTheme.urgentAccentGradient,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: PurchaseTheme.pendingBadge.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.poppins(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: PurchaseTheme.pendingBadge,
                    ),
                  ),
                ),
                const Spacer(),
                if (preview.totalCount > 0)
                  Text(
                    formatPurchaseCompact(preview.totalCount),
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: PurchaseTheme.accentDeep,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: PurchaseTheme.glassPanel(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < preview.items.length; i++)
                    PurchaseDraftInvoiceRow(
                      item: preview.items[i],
                      compact: true,
                    ),
                  if (preview.totalCount > 0)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DraftInvoiceListScreen(testRole: testRole),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Text(
                            'Show all ${formatPurchaseCompact(preview.totalCount)} drafts',
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: PurchaseTheme.accentDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UnauthorizedView extends StatelessWidget {
  const _UnauthorizedView();

  @override
  Widget build(BuildContext context) {
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            PurchaseManagementGlassHeader(
              title: 'Purchase Management',
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  translate('home.purchase.not_authorized'),
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    color: PurchaseTheme.textSecondary,
                    fontWeight: FontWeight.w500,
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
