import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_assistant_body.dart';
import 'package:flutter/material.dart';

/// Purchase hub embedded AI tab — reuses shared Elrace AI body.
class PurchaseManagementAiView extends StatelessWidget {
  const PurchaseManagementAiView({super.key, this.bottomPadding = 24});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ElraceAiAssistantBody(
      title: 'Purchase AI',
      subtitle:
          'Ask about spend trends, pending RFQs, draft invoices, and '
          'material request bottlenecks.',
      suggestions: const [
        'Summarize open LPOs this month',
        'Which vendors have draft invoices?',
        'Highlight urgent material requests',
      ],
      bottomPadding: bottomPadding,
    );
  }
}
