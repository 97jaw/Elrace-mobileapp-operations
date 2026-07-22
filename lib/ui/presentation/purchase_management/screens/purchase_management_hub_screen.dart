import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/purchase/purchase_access.dart';
import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_lpo_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_mr_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_rfq_hub_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/utils/purchase_number_format.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_compact_hub_card.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_dev_role_toggle_bar.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/draft_invoice_list_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_invoice_detail_sheet.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseManagementHubScreen extends ConsumerWidget {
  const PurchaseManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(purchaseAccessProvider);
    final testRole = ref.watch(purchaseDevRoleOverrideProvider);
    final overviewAsync = ref.watch(purchaseOverviewProvider);

    ref.watch(recentInvoicesPreviewProvider);

    // Prefer live /purchase/overview authorization so management users are not
    // stuck behind a stale login cache of purchase_scope=none.
    return overviewAsync.when(
      loading: () => const PurchaseBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
          ),
        ),
      ),
      error: (e, _) => PurchaseBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text(
              e.toString(),
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.tsp),
            ),
          ),
        ),
      ),
      data: (overview) {
        final backendAuthorized = overview.isAuthorized && overview.scope != 'none';
        if (!access.hasAnyAccess && !backendAuthorized) {
          return const _UnauthorizedView();
        }

        final effectiveAccess = access.hasAnyAccess
            ? access
            : PurchaseAccess(
                isPurchaseRep: false,
                isPurchaseManager: true,
                isCostControlOrManagement: overview.scope == 'all',
                isDocController: false,
                scope: overview.scope.isNotEmpty ? overview.scope : 'all',
              );

        return PurchaseBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                PurchaseManagementGlassHeader(
                  title: translate('home.purchase_management'),
                  showBack: true,
                  onBack: () => Navigator.pop(context),
                ),
                const PurchaseDevRoleToggleBar(),
                if (effectiveAccess.scopeLabel.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        effectiveAccess.scopeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w500,
                          color: PurchaseTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _HubBody(
                    overview: overview,
                    access: effectiveAccess,
                    testRole: testRole,
                    compactLayout: effectiveAccess.isPurchaseManager ||
                        effectiveAccess.isCostControlOrManagement,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({
    required this.overview,
    required this.access,
    required this.testRole,
    required this.compactLayout,
  });

  final PurchaseOverview overview;
  final PurchaseAccess access;
  final PurchaseDevTestRole? testRole;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = overview.cards;
    return RefreshIndicator(
      color: PurchaseTheme.accentBlue,
      onRefresh: () async {
        ref.invalidate(recentInvoicesPreviewProvider);
        final repo = ref.read(purchaseRepositoryProvider);
        final role = ref.read(purchaseDevRoleOverrideProvider);
        await repo.fetchOverview(testRole: role, refresh: true);
        ref.invalidate(purchaseOverviewProvider);
        await ref.read(purchaseOverviewProvider.future);
        await ref.read(recentInvoicesPreviewProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 24.th),
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
                SizedBox(width: 10.tw),
                Expanded(
                  child: PurchaseCompactHubCard(
                    title: 'Material Req.',
                    primaryValue: formatPurchaseCompact(cards.pendingMrs),
                    valueColor: const Color(0xFF7C3AED),
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBackground: const Color(0xFFEDE9FE),
                    badge: 'PENDING',
                    trendLabel: cards.pendingMrs > 0 ? 'Action' : 'Clear',
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
            SizedBox(height: 10.th),
            PurchaseCompactLpoStrip(
              totalCount: cards.lpos,
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
            SizedBox(height: 12.th),
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
                PurchaseHeroMetric(
                  label: 'Total',
                  value: formatPurchaseCompact(
                    cards.lposOpen + cards.lposClosed > 0
                        ? cards.lposOpen + cards.lposClosed
                        : cards.lpos,
                  ),
                ),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseLpoHubScreen(testRole: testRole),
                ),
              ),
            ),
            SizedBox(height: 12.th),
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
          SizedBox(height: compactLayout ? 12.th : 20.th),
          _RecentInvoicesSection(testRole: testRole),
        ],
      ),
    );
  }
}

class _RecentInvoicesSection extends ConsumerWidget {
  const _RecentInvoicesSection({required this.testRole});

  final PurchaseDevTestRole? testRole;

  void _openFullList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftInvoiceListScreen(testRole: testRole),
      ),
    );
  }

  void _openDetail(BuildContext context, DraftInvoiceItem item) {
    showPurchaseInvoiceDetailSheet(
      context,
      invoiceId: item.id,
      preview: item,
    );
  }

  Widget _titleRow(BuildContext context, {required bool showMore}) {
    return Row(
      children: [
        Text(
          'Recent Invoices',
          style: GoogleFonts.poppins(
            fontSize: 15.tsp,
            fontWeight: FontWeight.w700,
            color: PurchaseTheme.textPrimary,
          ),
        ),
        const Spacer(),
        if (showMore)
          TextButton(
            onPressed: () => _openFullList(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Show more',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w600,
                color: PurchaseTheme.accentDeep,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(recentInvoicesPreviewProvider);

    return previewAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(context, showMore: false),
          SizedBox(height: 8.th),
          Container(
            height: 100.th,
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
        if (preview.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              context,
              showMore: preview.totalCount > preview.items.length,
            ),
            SizedBox(height: 8.th),
            Container(
              decoration: PurchaseTheme.glassPanel(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in preview.items)
                    PurchaseDraftInvoiceRow(
                      item: item,
                      compact: true,
                      onTap: () => _openDetail(context, item),
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
                    fontSize: 16.tsp,
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
