import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full vertical list of agreements (See All from dashboard).
class AgreementsListScreen extends StatelessWidget {
  const AgreementsListScreen({
    super.key,
    required this.agreements,
    required this.onAgreementTap,
  });

  final List<UserProjectModel> agreements;
  final void Function(UserProjectModel agreement) onAgreementTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProjectsGlassShell(
        title: translate('projects_dashboard.agreements'),
        body: agreements.isEmpty
          ? Center(
              child: Text(
                translate('projects_dashboard.no_agreements'),
                style: GoogleFonts.poppins(fontSize: 14.tsp),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 8.th, bottom: 100.th),
              itemCount: agreements.length,
              itemBuilder: (context, index) {
                final project = agreements[index];
                final id = project.projectId;
                final name = project.projectName;
                return GestureDetector(
                  onTap: () => onAgreementTap(project),
                  child: buildProjectCard(
                    id: project.agreementNo ?? '$id',
                    name: name,
                    photoUrl: project.photoUrl ?? '',
                    projectsCount: project.totalProjects,
                    amountAed: project.totalProjectsAmount,
                    cityId: project.cityId ?? '',
                  ),
                );
              },
            ),
      ),
    );
  }
}
