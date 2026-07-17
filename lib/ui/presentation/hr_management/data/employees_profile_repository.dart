import 'dart:convert';

import 'package:el_race/ui/presentation/hr_management/data/employee_profile_models.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/di.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:http/http.dart' as http;

class EmployeesProfileRepository {
  EmployeesProfileRepository({UserRepo? userRepo})
      : _userRepo = userRepo ?? sl.get<UserRepo>();

  final UserRepo _userRepo;

  Future<EmployeeProfileDetail> fetchProfile(int employeeId) async {
    return _get(
      UrlUtil.employeeProfileApi,
      employeeId,
      EmployeeProfileDetail.fromJson,
    );
  }

  Future<EmployeeContractDetail> fetchContract(int employeeId) async {
    return _get(
      UrlUtil.employeeProfileContractApi,
      employeeId,
      EmployeeContractDetail.fromJson,
    );
  }

  Future<EmployeeDocumentsDetail> fetchDocuments(int employeeId) async {
    return _get(
      UrlUtil.employeeProfileDocumentsApi,
      employeeId,
      EmployeeDocumentsDetail.fromJson,
    );
  }

  Future<EmployeeFleetDetail> fetchFleet(int employeeId) async {
    return _get(
      UrlUtil.employeeProfileFleetApi,
      employeeId,
      EmployeeFleetDetail.fromJson,
    );
  }

  Future<T> _get<T>(
    String path,
    int employeeId,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final loginResponse = await _userRepo.getLoginResponse();
    final token = loginResponse?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final url = Uri.parse('${UrlUtil.baseUrl}$path').replace(
      queryParameters: {'employee_id': '$employeeId'},
    );

    final request = http.Request('GET', url)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({'employee_id': employeeId});

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid response');
    }
    final map = Map<String, dynamic>.from(decoded);
    final result = map['result'];
    if (result is Map && result['status'] == 'error') {
      throw Exception('${result['message'] ?? 'Unable to load data'}');
    }
    return parse(map);
  }
}
