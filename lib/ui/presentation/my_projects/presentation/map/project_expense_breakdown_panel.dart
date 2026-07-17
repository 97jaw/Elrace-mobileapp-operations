import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_breakdown_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_expense_summary_panel.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kMgNavy = Color(0xFF1E2365);
const Color _kSgTint = Color(0x66E8EEF5);

class ProjectExpenseBreakdownPanel extends StatelessWidget {
  const ProjectExpenseBreakdownPanel({
    super.key,
    required this.result,
  });

  final ProjectExpenseBreakdownResult result;

  Future<void> _openExport(BuildContext context) async {
    final url = result.exportUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export URL is not available.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid export URL.')),
      );
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open export. Sign in to ERP in your browser if prompted.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = result.breakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreakdownStatsHeader(payload: payload),
        SizedBox(height: 12.th),
        Text(
          'Groups',
          style: GoogleFonts.poppins(
            fontSize: 12.tsp,
            fontWeight: FontWeight.w700,
            color: ProjectsDashboardTheme.white,
          ),
        ),
        SizedBox(height: 8.th),
        if (payload.groups.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                payload.emptyMessage.isNotEmpty
                    ? payload.emptyMessage
                    : 'No expense breakdown data.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: 8.th),
              itemCount: payload.groups.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.th),
              itemBuilder: (context, index) {
                return _MgGroupTile(group: payload.groups[index]);
              },
            ),
          ),
        if (result.exportUrl.trim().isNotEmpty) ...[
          SizedBox(height: 8.th),
          OutlinedButton.icon(
            onPressed: () => _openExport(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: ProjectsDashboardTheme.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              padding: EdgeInsets.symmetric(vertical: 12.th),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.tr),
              ),
            ),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              'Download Excel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _BreakdownStatsHeader extends StatelessWidget {
  const _BreakdownStatsHeader({required this.payload});

  final ProjectExpenseBreakdownPayload payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.tw),
      decoration: analyticsGlassPanel(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Expense breakdown',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w700,
              color: ProjectsDashboardTheme.white,
            ),
          ),
          SizedBox(height: 10.th),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Total',
                  value: payload.totalDisplay,
                  tint: kKpiWoGreen,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _StatChip(
                  label: 'Groups',
                  value: '${payload.groupsCount}',
                  tint: kKpiSpendBlue,
                  icon: Icons.folder_copy_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.th),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Sub groups',
                  value: '${payload.subgroupsCount}',
                  tint: kKpiEstimationPurple,
                  icon: Icons.hub_rounded,
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _StatChip(
                  label: 'Accounts',
                  value: '${payload.accountsCount}',
                  tint: kKpiExpenseRed,
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.tint,
    required this.icon,
  });

  final String label;
  final String value;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
      decoration: kpiFadedFill(tint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17.tsp, color: kpiIconColor(tint)),
          SizedBox(height: 5.th),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.tw, vertical: 2.th),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(6.tr),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9.tsp,
                fontWeight: FontWeight.w700,
                color: ProjectsDashboardTheme.white,
              ),
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w800,
              color: ProjectsDashboardTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MgGroupTile extends StatelessWidget {
  const _MgGroupTile({required this.group});

  final ProjectExpenseBreakdownGroup group;

  void _openGroupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _kMgNavy.withValues(alpha: 0.97),
                    ProjectsDashboardTheme.maroonDark.withValues(alpha: 0.96),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22.tr)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.th),
                  Container(
                    width: 40.tw,
                    height: 4.th,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4.tr),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 8.th),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16.tsp,
                              fontWeight: FontWeight.w800,
                              color: ProjectsDashboardTheme.white,
                            ),
                          ),
                        ),
                        Text(
                          group.totalDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 14.tsp,
                            fontWeight: FontWeight.w700,
                            color: ProjectsDashboardTheme.greyPanel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(14.tw, 0, 14.tw, 20.th),
                      itemCount: group.subgroups.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.th),
                      itemBuilder: (_, sgIndex) {
                        final sg = group.subgroups[sgIndex];
                        return _SubgroupBlock(subgroup: sg);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGroupSheet(context),
        borderRadius: BorderRadius.circular(14.tr),
        child: Ink(
          decoration: BoxDecoration(
            color: _kMgNavy.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14.tr),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 14.th),
            child: Row(
              children: [
                Container(
                  width: 4.tw,
                  height: 32.th,
                  decoration: BoxDecoration(
                    color: ProjectsDashboardTheme.maroonLight,
                    borderRadius: BorderRadius.circular(2.tr),
                  ),
                ),
                SizedBox(width: 12.tw),
                Expanded(
                  child: Text(
                    group.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14.tsp,
                      fontWeight: FontWeight.w700,
                      color: ProjectsDashboardTheme.white,
                    ),
                  ),
                ),
                Text(
                  group.totalDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: ProjectsDashboardTheme.greyPanel,
                  ),
                ),
                SizedBox(width: 6.tw),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
                  size: 22.tsp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubgroupBlock extends StatelessWidget {
  const _SubgroupBlock({required this.subgroup});

  final ProjectExpenseBreakdownSubgroup subgroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSgTint,
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 8.th),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subgroup.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w700,
                      color: ProjectsDashboardTheme.white,
                    ),
                  ),
                ),
                Text(
                  subgroup.totalDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w700,
                    color: ProjectsDashboardTheme.greyPanel,
                  ),
                ),
              ],
            ),
          ),
          for (final account in subgroup.accounts)
            Container(
              margin: EdgeInsets.fromLTRB(10.tw, 0, 10.tw, 8.th),
              padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.tr),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      account.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        color: ProjectsDashboardTheme.white,
                      ),
                    ),
                  ),
                  Text(
                    account.totalDisplay,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w700,
                      color: ProjectsDashboardTheme.white,
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
