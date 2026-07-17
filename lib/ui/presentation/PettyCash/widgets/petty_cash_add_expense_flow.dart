import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/PettyCash/petty_cash_draft_summary_screen.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pick expense category then open draft screen (optionally auto-open add form).
abstract final class PettyCashAddExpenseFlow {
  static Future<void> showTypePicker(
    BuildContext context, {
    bool openAddForm = false,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddExpenseTypeSheet(),
    );
    if (!context.mounted || choice == null) return;

    if (choice == 'fleet') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDraftSummaryScreen(
            title: 'Transportation',
            expenseType: 'fleet',
            titleIcon: Icons.local_gas_station_outlined,
            autoOpenAddExpense: openAddForm,
          ),
        ),
      );
    } else if (choice == 'others') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDraftSummaryScreen(
            title: 'Miscellaneous',
            expenseType: 'others',
            titleIcon: Icons.receipt_long_rounded,
            autoOpenAddExpense: openAddForm,
          ),
        ),
      );
    }
  }

  static Future<void> openTransportation(
    BuildContext context, {
    bool openAddForm = false,
  }) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDraftSummaryScreen(
            title: 'Transportation',
            expenseType: 'fleet',
            titleIcon: Icons.local_gas_station_outlined,
            autoOpenAddExpense: openAddForm,
          ),
        ),
      );

  static Future<void> openMiscellaneous(
    BuildContext context, {
    bool openAddForm = false,
  }) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDraftSummaryScreen(
            title: 'Miscellaneous',
            expenseType: 'others',
            titleIcon: Icons.receipt_long_rounded,
            autoOpenAddExpense: openAddForm,
          ),
        ),
      );
}

class _AddExpenseTypeSheet extends StatelessWidget {
  const _AddExpenseTypeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 24.th),
      padding: EdgeInsets.fromLTRB(20.tw, 20.th, 20.tw, 16.th),
      decoration: PettyCashTheme.glassPanel(radius: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add expense',
            style: GoogleFonts.poppins(
              fontSize: 18.tsp,
              fontWeight: FontWeight.w700,
              color: PettyCashTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6.th),
          Text(
            'Choose the expense category',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: PettyCashTheme.textSecondary,
            ),
          ),
          SizedBox(height: 20.th),
          _TypeTile(
            icon: Icons.local_gas_station_outlined,
            label: 'Transportation',
            subtitle: 'Fuel, fleet & travel',
            onTap: () => Navigator.pop(context, 'fleet'),
          ),
          SizedBox(height: 10.th),
          _TypeTile(
            icon: Icons.receipt_long_rounded,
            label: 'Miscellaneous',
            subtitle: 'Equipment, supplies & other',
            onTap: () => Navigator.pop(context, 'others'),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettyCashTheme.glassFill,
      borderRadius: BorderRadius.circular(16.tr),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 14.th),
          child: Row(
            children: [
              Container(
                width: 44.tw,
                height: 44.tw,
                decoration: BoxDecoration(
                  color: PettyCashTheme.iconCircleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: PettyCashTheme.glassBorder),
                ),
                child: Icon(icon, color: PettyCashTheme.mint),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15.tsp,
                        fontWeight: FontWeight.w700,
                        color: PettyCashTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        color: PettyCashTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: PettyCashTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
