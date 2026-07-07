import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_assistant_body.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:flutter/material.dart';

/// Full-screen Elrace AI assistant (Projects, modules, etc.).
class ElraceAiAssistantScreen extends StatelessWidget {
  const ElraceAiAssistantScreen({
    super.key,
    required this.title,
    this.subtitle =
        'Ask about projects, purchase, HR, documents, and timesheets.',
    this.suggestions = const [],
  });

  final String title;
  final String subtitle;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + 16;

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
              child: ElraceAiAssistantBody(
                title: title,
                subtitle: subtitle,
                suggestions: suggestions,
                bottomPadding: bottomPad,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset for My Projects toolbar AI.
class ProjectsAiAssistantScreen extends StatelessWidget {
  const ProjectsAiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElraceAiAssistantScreen(
      title: 'Projects AI',
      subtitle:
          'Ask about portfolio progress, deadlines, documents, and site reports.',
      suggestions: [
        'Summarize in-progress projects',
        'Which projects are behind schedule?',
        'Draft a weekly progress summary',
      ],
    );
  }
}
