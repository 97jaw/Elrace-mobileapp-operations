import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_list_builder.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectManagerFilterItem', () {
    test('parses Odoo many2one project_manager tuple', () {
      final item = ProjectManagerFilterItem.fromJson({
        'id': 0,
        'name': 'No Manager',
        'project_manager': [42, 'Ahmed Ali'],
        'project_count': 3,
      });

      expect(item.id, 42);
      expect(item.name, 'Ahmed Ali');
      expect(item.projectCount, 3);
    });

    test('parses partner_name for group_by client', () {
      final item = ProjectManagerFilterItem.fromJson({
        'id': 11380,
        'partner_name': 'Abu Dhabi Police',
        'project_count': 12,
      });
      expect(item.id, 11380);
      expect(item.name, 'Abu Dhabi Police');
    });

    test('parses partner_id many2one for client label', () {
      final item = ProjectManagerFilterItem.fromJson({
        'partner_id': [11380, 'Abu Dhabi Police'],
        'project_count': 3,
      });
      expect(item.id, 11380);
      expect(item.name, 'Abu Dhabi Police');
    });
  });

  group('ProjectsGroupListBuilder', () {
    test('groups by project_manager_id not No Manager', () {
      final projects = [
        ProjectModel.fromJson({
          'project_id': 1,
          'partner_id': '10',
          'agreement_id': '20',
          'wo_ref_no': 'WO-1',
          'name': 'Project A',
          'wo_amount': 100,
          'project_status': 'open',
          'date': '2025-01-01',
          'date_start': '2025-01-01',
          'project_manager': [42, 'Ahmed Ali'],
        }),
        ProjectModel.fromJson({
          'project_id': 2,
          'partner_id': '11',
          'agreement_id': '21',
          'wo_ref_no': 'WO-2',
          'name': 'Project B',
          'wo_amount': 200,
          'project_status': 'open',
          'date': '2025-02-01',
          'date_start': '2025-02-01',
          'project_manager_id': 42,
          'project_manager_name': 'Ahmed Ali',
        }),
      ];

      final groups = ProjectsGroupListBuilder.fromProjects(
        projects,
        ProjectsGroupByMode.projectManager,
      );

      expect(groups, hasLength(1));
      expect(groups.first.id, 42);
      expect(groups.first.name, 'Ahmed Ali');
      expect(groups.first.projectCount, 2);
    });

    test('groups by manager name when id missing and fallback enabled', () {
      final projects = [
        ProjectModel.fromJson({
          'project_id': 3,
          'partner_id': '10',
          'agreement_id': '20',
          'wo_ref_no': 'WO-3',
          'name': 'Project C',
          'wo_amount': 50,
          'project_status': 'open',
          'date': '2025-03-01',
          'date_start': '2025-03-01',
          'project_manager_name': 'Sara Khan',
        }),
      ];

      final groups = ProjectsGroupListBuilder.fromProjects(
        projects,
        ProjectsGroupByMode.projectManager,
        allowNameFallback: true,
      );

      expect(groups, hasLength(1));
      expect(groups.first.name, 'Sara Khan');
      expect(groups.first.projectCount, 1);
    });

    test('groups by client using partner_name not partner id', () {
      final projects = [
        ProjectModel.fromJson({
          'project_id': 10,
          'partner_id': 55,
          'partner_name': 'Abu Dhabi Police',
          'agreement_id': '20',
          'wo_ref_no': 'WO-1',
          'name': 'Project A',
          'wo_amount': 100,
          'project_status': 'open',
          'date': '2025-01-01',
          'date_start': '2025-01-01',
        }),
        ProjectModel.fromJson({
          'id': 9,
          'partner_id': [55, 'Abu Dhabi Police'],
          'agreement_id': '21',
          'wo_ref_no': 'WO-2',
          'name': 'Project B',
          'wo_amount': 200,
          'project_status': 'open',
          'date': '2025-02-01',
          'date_start': '2025-02-01',
        }),
      ];

      final groups = ProjectsGroupListBuilder.fromProjects(
        projects,
        ProjectsGroupByMode.client,
      );

      expect(groups, hasLength(1));
      expect(groups.first.id, 55);
      expect(groups.first.name, 'Abu Dhabi Police');
      expect(groups.first.projectCount, 2);
    });

    test('does not use bare partner_id integer as client name', () {
      final projects = [
        ProjectModel.fromJson({
          'project_id': 1,
          'partner_id': 99,
          'agreement_id': '1',
          'wo_ref_no': 'WO-1',
          'name': 'P',
          'wo_amount': 1,
          'project_status': 'open',
          'date': '2025-01-01',
          'date_start': '2025-01-01',
        }),
      ];

      final groups = ProjectsGroupListBuilder.fromProjects(
        projects,
        ProjectsGroupByMode.client,
      );

      expect(groups, hasLength(1));
      expect(groups.first.id, 99);
      expect(groups.first.name, isNot('99'));
    });
  });

  group('ProjectsGroupHubFilters', () {
    test('toApiParams maps project_status_compute and wo fields', () {
      const filters = ProjectsGroupHubFilters(
        year: 2025,
        month: 3,
        projectStatusCompute: 'in_progress',
        woRefNo: 'WO-99',
        woTypeNoOffice: 'active',
        searchName: 'tower',
      );

      final params = filters.toApiParams();
      expect(params['year'], 2025);
      expect(params['month'], 3);
      expect(params['project_status_compute'], 'in_progress');
      expect(params['wo_ref_no'], 'WO-99');
      expect(params['wo_type_no_office'], 'active');
      expect(params['name'], 'tower');
      expect(params['search_name'], 'tower');
    });

    test('equality compares all filter fields', () {
      const a = ProjectsGroupHubFilters(
        year: 2025,
        projectStatusCompute: 'in_progress',
      );
      const b = ProjectsGroupHubFilters(
        year: 2025,
        projectStatusCompute: 'in_progress',
      );
      const c = ProjectsGroupHubFilters(year: 2024);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('LoadProjectsByFiltersEvent hubFilters', () {
    test('carries hub filters for v2 partner projects', () {
      const hubFilters = ProjectsGroupHubFilters(
        projectStatusCompute: 'in_progress',
        woRefNo: 'WO-1',
      );
      final event = LoadProjectsByFiltersEvent(
        projectManagerId: 42,
        hubFilters: hubFilters,
      );

      expect(event.hubFilters, hubFilters);
      expect(event.hubFilters!.toApiParams()['project_status_compute'],
          'in_progress');
    });
  });

  group('ProjectModel partner / id parsing', () {
    test('reads project id from id when project_id missing', () {
      final p = ProjectModel.fromJson({
        'id': 77,
        'partner_id': 5,
        'partner_name': 'Client Co',
        'agreement_id': 1,
        'wo_ref_no': 'WO',
        'name': 'N',
        'wo_amount': 1,
        'project_status': 'open',
        'date': '2025-01-02',
        'date_start': '2025-01-02',
      });
      expect(p.projectId, 77);
      expect(p.partnerName, 'Client Co');
    });

    test('sorts agreement projects by id desc', () {
      final a = ProjectModel.fromJson({
        'id': 1,
        'partner_id': 5,
        'agreement_id': 1,
        'wo_ref_no': 'WO-1',
        'name': 'Old',
        'wo_amount': 1,
        'project_status': 'open',
        'date': '2024-01-01',
        'date_start': '2024-01-01',
      });
      final b = ProjectModel.fromJson({
        'id': 50,
        'partner_id': 5,
        'agreement_id': 1,
        'wo_ref_no': 'WO-50',
        'name': 'New',
        'wo_amount': 1,
        'project_status': 'open',
        'date': '2025-01-01',
        'date_start': '2025-01-01',
      });
      final sorted = ProjectsListOrdering.sortModelsDesc([a, b]);
      expect(sorted.first.projectId, 50);
      expect(sorted.last.projectId, 1);
    });
  });
}
