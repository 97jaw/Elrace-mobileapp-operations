import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterProjectsForAccessibleAgreements', () {
    const agreements = [
      UserProjectModel(
        projectId: 10,
        projectName: 'Abu Dhabi Police',
        totalProjects: 2,
        totalProjectsAmount: 100,
        agreementId: 501,
        agreementName: 'AGR-2024',
        agreementNo: 'A-001',
      ),
    ];

    test('matches v2 numeric partner id via agreement name', () {
      const projects = [
        ProjectEntity(
          projectId: 1,
          partnerId: '11380',
          partnerName: '11380',
          agreementId: 'AGR-2024',
          woRefNo: '',
          name: 'WO-1',
          woAmount: 0,
          projectStatus: 'Open',
          date: '',
          dateStart: '',
        ),
      ];

      final filtered = ProjectsDashboardAggregator
          .filterProjectsForAccessibleAgreements(
        projects: projects,
        agreements: agreements,
      );

      expect(filtered, hasLength(1));
    });

    test('matches v1 partner name string', () {
      const projects = [
        ProjectEntity(
          projectId: 2,
          partnerId: 'Abu Dhabi Police',
          agreementId: 'Other',
          woRefNo: '',
          name: 'WO-2',
          woAmount: 0,
          projectStatus: 'Open',
          date: '',
          dateStart: '',
        ),
      ];

      final filtered = ProjectsDashboardAggregator
          .filterProjectsForAccessibleAgreements(
        projects: projects,
        agreements: agreements,
      );

      expect(filtered, hasLength(1));
    });
  });
}
