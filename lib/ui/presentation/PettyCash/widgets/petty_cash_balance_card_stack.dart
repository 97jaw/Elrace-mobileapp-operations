import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:el_race/ui/presentation/PettyCash/utils/petty_cash_holder_utils.dart';
import 'package:el_race/ui/presentation/PettyCash/widgets/petty_cash_hero_card_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stacked balance cards — hero card has a physical pill cut-out; button sits in it.
class PettyCashBalanceCardStack extends StatelessWidget {
  const PettyCashBalanceCardStack({
    super.key,
    required this.balance,
    required this.holderName,
    this.batchLabel,
    required this.draftAmount,
    required this.notPaidAmount,
    required this.onAddExpense,
  });

  final double balance;
  final String holderName;
  final String? batchLabel;
  final double draftAmount;
  final double notPaidAmount;
  final VoidCallback onAddExpense;

  static String _maskedBatch(String? batchLabel) {
    final digits = (batchLabel ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return '**** ${digits.substring(digits.length - 4)}';
    }
    return '**** 0000';
  }

  @override
  Widget build(BuildContext context) {
    final batch = batchLabel?.trim().isNotEmpty == true
        ? batchLabel!
        : 'Petty Cash';
    final cardRadius = 26.tr;
    final buttonW = 136.tw;
    final buttonH = 44.th;
    final notchGap = 8.tw;
    final cardH = 208.th;

    return LayoutBuilder(
      builder: (context, constraints) {
        final clipper = CardWithButtonNotchClipper(
          cardRadius: cardRadius,
          buttonWidth: buttonW,
          buttonHeight: buttonH,
          notchPadding: notchGap,
        );

        return SizedBox(
          height: cardH + 30.th,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Back card
              Positioned(
                top: 0,
                left: 32.tw,
                right: 32.tw,
                child: Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    height: 132.th,
                    decoration: BoxDecoration(
                      gradient: PettyCashTheme.backCardGradient,
                      borderRadius: BorderRadius.circular(22.tr),
                      border: Border.all(color: PettyCashTheme.glassBorder),
                    ),
                    padding: EdgeInsets.fromLTRB(20.tw, 14.th, 20.tw, 8.th),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Text(
                        _maskedBatch(batchLabel),
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w600,
                          color: PettyCashTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Hero card + in-cutout button
              Positioned(
                top: 26.th,
                left: 16.tw,
                right: 16.tw,
                height: cardH,
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final cardSize = Size(
                      cardConstraints.maxWidth,
                      cardH,
                    );
                    final buttonPos = clipper.buttonOffset(cardSize);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PettyCashHeroCardShell(
                          clipper: clipper,
                          borderColor: PettyCashTheme.white.withValues(alpha: 0.42),
                          borderWidth: 1.1,
                          child: Container(
                            height: cardH,
                            decoration: const BoxDecoration(
                              gradient: PettyCashTheme.heroCardGradient,
                            ),
                            padding: EdgeInsets.fromLTRB(
                              20.tw,
                              18.th,
                              20.tw,
                              clipper.notchHeight + 4.th,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: PettyCashTheme.white
                                          .withValues(alpha: 0.88),
                                      size: 22.tsp,
                                    ),
                                    const Spacer(),
                                    Text(
                                      batch.length > 16
                                          ? '${batch.substring(0, 16)}…'
                                          : batch,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.tsp,
                                        fontWeight: FontWeight.w600,
                                        color: PettyCashTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.th),
                                Text(
                                  'Balance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.tsp,
                                    fontWeight: FontWeight.w500,
                                    color: PettyCashTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  PettyCashHolderUtils.formatAed(balance),
                                  style: GoogleFonts.poppins(
                                    fontSize: 28.tsp,
                                    fontWeight: FontWeight.w700,
                                    color: PettyCashTheme.white,
                                    height: 1.05,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: clipper.notchWidth * 0.12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Name',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10.tsp,
                                                color:
                                                    PettyCashTheme.textMuted,
                                              ),
                                            ),
                                            Text(
                                              holderName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.tsp,
                                                fontWeight: FontWeight.w600,
                                                color: PettyCashTheme.white,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Draft',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.tsp,
                                            color: PettyCashTheme.textMuted,
                                          ),
                                        ),
                                        Text(
                                          PettyCashHolderUtils.formatAmount(
                                            draftAmount,
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.tsp,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                PettyCashTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: buttonPos.dx,
                          top: buttonPos.dy,
                          child: _AddExpensePill(
                            width: buttonW,
                            height: buttonH,
                            onTap: onAddExpense,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddExpensePill extends StatelessWidget {
  const _AddExpensePill({
    required this.onTap,
    required this.width,
    required this.height,
  });

  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettyCashTheme.black,
      elevation: 0,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: width,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24.tw,
                height: 24.tw,
                decoration: const BoxDecoration(
                  color: PettyCashTheme.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: 15.tsp,
                  color: PettyCashTheme.black,
                ),
              ),
              SizedBox(width: 7.tw),
              Flexible(
                child: Text(
                  'Add expense',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w600,
                    color: PettyCashTheme.white,
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
