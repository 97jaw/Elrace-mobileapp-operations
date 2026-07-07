import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_coming_soon_plate.dart';
import 'package:flutter/material.dart';

/// Stats tab placeholder — analytics dashboard coming soon.
class PurchaseManagementAnalyticsView extends StatelessWidget {
  const PurchaseManagementAnalyticsView({super.key, this.bottomPadding = 24});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return PurchaseComingSoonPlate(
      bottomPadding: bottomPadding,
      title: 'Purchase Analytics',
      message:
          'Spend trends, RFQ/LPO breakdowns, and department insights '
          'will appear here. We are building this dashboard for you.',
      illustration: const PurchaseAnalyticsVectorIllustration(),
    );
  }
}
