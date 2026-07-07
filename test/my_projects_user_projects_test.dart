import 'dart:convert';

import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ProjectRemoteDataSource.fetchClientsList', () {
    test('returns parsed response on success', () async {
      final mockClient = MockClient((request) async {
        // Detailed logging for mock request
        print('=== MOCK REQUEST ===');
        print('URL: ${request.url}');
        print('Method: ${request.method}');
        print('Headers: ${request.headers}');
        print('Body: ${request.body}');
        print('Body Length: ${request.body.length}');
        print('====================');

        expect(
            request.url.toString(), 'https://erp.elrace.com/api/clients/list');
        expect(request.method, 'GET');

        final mockResponse = http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': {
              'status': 'success',
              'message': 'Clients fetched successfully.',
              'data': [
                {
                  'id': 11380,
                  'name': 'Abu Dhabi Police',
                  'total_projects': 558,
                  'total_projects_amount': 1431401691.12,
                  'photo_url':
                      'https://erp.elrace.compublic/partner/image/11380',
                }
              ],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        print('=== MOCK RESPONSE ===');
        print('Status Code: 200');
        print('Body: ${mockResponse.body}');
        print('====================');

        return mockResponse;
      });

      final dataSource = ProjectRemoteDataSource(
        client: mockClient,
        getToken: () => 'mock_token',
      );

      final result = await dataSource.fetchClientsList();

      expect(result.success, isTrue);
      expect(result.projects, hasLength(1));
      expect(result.projects.first.projectId, 11380);
      expect(result.projects.first.projectName, 'Abu Dhabi Police');
      expect(result.projects.first.totalProjects, 558);
      expect(result.projects.first.totalProjectsAmount, 1431401691.12);
    });

    test('throws an exception on non-200 status', () async {
      final mockClient = MockClient((request) async {
        print('=== MOCK ERROR REQUEST ===');
        print('URL: ${request.url}');
        print('Method: ${request.method}');
        print('Headers: ${request.headers}');
        print('Body: ${request.body}');
        print('===========================');

        return http.Response('error', 500);
      });

      final dataSource = ProjectRemoteDataSource(
        client: mockClient,
        getToken: () => 'mock_token',
      );

      expect(() => dataSource.fetchClientsList(), throwsA(isA<Exception>()));
    });
  });
}
