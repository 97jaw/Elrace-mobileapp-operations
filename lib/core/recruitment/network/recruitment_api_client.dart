import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/hr_management/network/hr_api_envelope.dart';
import 'package:el_race/core/recruitment/recruitment_mock_repository.dart';
import 'package:el_race/core/recruitment/recruitment_mock_requisitions.dart';

/// Recruitment module HTTP client — Odoo JSON-RPC.
class RecruitmentApiClient {
  RecruitmentApiClient(this._dio, {this.useMock = false});

  final Dio _dio;
  final bool useMock;

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchRequisitions({
    String? keyword,
    int limit = 200,
    bool openPositionsOnly = false,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return HrApiEnvelope(
        success: true,
        data: recruitmentMockRequisitions()
            .map((r) => _requisitionToMap(r))
            .toList(),
      );
    }
    return _postList('/api/recruitment/requisitions', {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'limit': limit,
      if (openPositionsOnly) 'open_positions_only': true,
    });
  }

  Object _idParam(String id) {
    final trimmed = id.trim();
    if (trimmed.startsWith('job:')) return trimmed;
    final parsed = int.tryParse(trimmed);
    return parsed ?? trimmed;
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchRequisitionDetail(
    String id,
  ) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final d = await RecruitmentMockRepository.detailFor(id);
      return HrApiEnvelope(
        success: true,
        data: {
          'requisition': _requisitionToMap(d.requisition),
          'job_description': d.jobDescription,
          'key_responsibilities': d.keyResponsibilities,
          'required_skills': d.requiredSkills,
          'salary_min_aed': d.salaryMinAed,
          'salary_max_aed': d.salaryMaxAed,
          'required_by': d.requiredBy?.toIso8601String(),
          'pipeline': {
            'applied': d.pipeline.applied,
            'screening': d.pipeline.screening,
            'interview': d.pipeline.interview,
            'offer': d.pipeline.offer,
            'hired': d.pipeline.hired,
          },
          'candidates': [],
          'offers': [],
          'activities': [],
        },
      );
    }
    return _postMap('/api/recruitment/requisitions/detail', {'id': _idParam(id)});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchKpis() async {
    if (useMock) {
      return HrApiEnvelope(success: true, data: {'open': 8, 'pipeline': 42, 'offers': 3});
    }
    return _postMap('/api/recruitment/kpis', {});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchDashboard({
    String period = 'month',
  }) async {
    if (useMock) {
      return HrApiEnvelope(
        success: true,
        data: {
          'kpis': {'open': 8, 'pipeline': 42, 'offers': 3},
          'by_status': [],
          'by_department': [],
          'funnel': [],
        },
      );
    }
    return _postMap('/api/recruitment/dashboard', {'period': period});
  }

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchCandidates({
    String? requisitionId,
    String? keyword,
    int limit = 200,
  }) async {
    if (useMock) {
      final list = await RecruitmentMockRepository.allCandidates();
      return HrApiEnvelope(
        success: true,
        data: list.map(_candidateToMap).toList(),
      );
    }
    return _postList('/api/recruitment/candidates', {
      if (requisitionId != null) 'requisition_id': _idParam(requisitionId),
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'limit': limit,
    });
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchCandidateDetail(
    String id,
  ) async {
    if (useMock) {
      final c = await RecruitmentMockRepository.candidateById(id);
      return HrApiEnvelope(success: true, data: _candidateToMap(c));
    }
    return _postMap('/api/recruitment/candidates/detail', {'id': int.parse(id)});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchAssessmentDetail(
    String id,
  ) async {
    if (useMock) {
      final a = await RecruitmentMockRepository.assessmentDetail(id);
      return HrApiEnvelope(
        success: true,
        data: {
          'id': a.id,
          'candidate_id': a.candidateId,
          'candidate_name': a.candidateName,
          'round_name': a.roundName,
          'interview_date': a.interviewDate.toIso8601String(),
          'interviewer': a.interviewer,
          'technical': a.technical,
          'problem_solving': a.problemSolving,
          'communication': a.communication,
          'cultural_fit': a.culturalFit,
          'strengths': a.strengths,
          'concerns': a.concerns,
          'recommendation': a.recommendation,
          'comments': a.comments,
          'is_draft': a.isDraft,
          'interviewer_emp_id': a.interviewerEmpId,
          'current_user_emp_id': a.currentUserEmpId,
        },
      );
    }
    return _postMap('/api/recruitment/assessments/detail', {'id': int.parse(id)});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchOfferDetail(String id) async {
    if (useMock) {
      final o = await RecruitmentMockRepository.offerDetail(id);
      return HrApiEnvelope(
        success: true,
        data: {
          'id': o.id,
          'candidate_name': o.candidateName,
          'position_title': o.positionTitle,
          'reference_number': o.referenceNumber,
          'ui_status': o.uiStatus,
          'sent_at': o.sentAt?.toIso8601String(),
          'expiry_at': o.expiryAt?.toIso8601String(),
          'department': o.department,
          'reporting_manager': o.reportingManager,
          'location': o.location,
          'joining_date': o.joiningDate?.toIso8601String(),
          'employment_type': o.employmentType,
          'salary_breakdown_lines': o.salaryBreakdownLines,
        },
      );
    }
    return _postMap('/api/recruitment/offers/detail', {'id': int.parse(id)});
  }

  Map<String, dynamic> _requisitionToMap(dynamic r) => {
        'id': r.id,
        'reference_number': r.referenceNumber,
        'job_title': r.jobTitle,
        'department': r.department,
        'location': r.location,
        'vacancies': r.vacancies,
        'candidate_count': r.candidateCount,
        'offer_count': r.offerCount,
        'ui_status': r.uiStatus,
        'raised_by': r.raisedBy,
        'opened_at': r.openedAt.toIso8601String(),
        'candidates_in_pipeline': r.candidatesInPipeline,
        'pending_offer_count': r.pendingOfferCount,
      };

  Map<String, dynamic> _candidateToMap(dynamic c) => {
        'id': c.id,
        'requisition_id': c.requisitionId,
        'requisition_ref': c.requisitionRef,
        'job_title': c.jobTitle,
        'full_name': c.fullName,
        'email': c.email,
        'phone': c.phone,
        'stage': c.stage,
        'applied_at': c.appliedAt.toIso8601String(),
        'source': c.source,
        'years_experience': c.yearsExperience,
        'current_company': c.currentCompany,
        'expected_salary': c.expectedSalary,
        'assessments': [],
        'offer_id': c.offerId,
        'notes_lines': c.notesLines,
      };

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> _postList(
    String path,
    Map<String, dynamic> params,
  ) async {
    final res = await _dio.post<dynamic>(
      path,
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      }),
    );
    return _listEnvelope(_decode(res.data));
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> _postMap(
    String path,
    Map<String, dynamic> params,
  ) async {
    final res = await _dio.post<dynamic>(
      path,
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      }),
    );
    return _mapEnvelope(_decode(res.data));
  }

  dynamic _decode(dynamic data) =>
      data is String ? jsonDecode(data) as dynamic : data;

  HrApiEnvelope<List<Map<String, dynamic>>> _listEnvelope(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope(success: false, error: 'Invalid server response');
    }
    final json = Map<String, dynamic>.from(payload);

    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      final errData = err['data'];
      final message = errData is Map
          ? errData['message']?.toString() ??
              err['message']?.toString() ??
              'Odoo server error'
          : err['message']?.toString() ?? 'Odoo server error';
      return HrApiEnvelope(success: false, error: message);
    }

    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope(success: false, error: 'Missing result in response');
    }

    final resultMap = Map<String, dynamic>.from(result);
    if (resultMap['success'] == true) {
      final data = resultMap['data'];
      final list = data is List
          ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      return HrApiEnvelope(
        success: true,
        data: list,
        uiStatus: resultMap['ui_status']?.toString(),
      );
    }

    return HrApiEnvelope(
      success: false,
      error: resultMap['error']?.toString() ??
          resultMap['message']?.toString() ??
          'Request failed',
    );
  }

  HrApiEnvelope<Map<String, dynamic>> _mapEnvelope(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope(success: false, error: 'Invalid response');
    }
    final json = Map<String, dynamic>.from(payload);
    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      return HrApiEnvelope(
        success: false,
        error: err['message']?.toString() ?? 'Server error',
      );
    }
    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope(success: false, error: 'Missing result');
    }
    final resultMap = Map<String, dynamic>.from(result);
    if (resultMap.containsKey('success')) {
      final data = resultMap['data'];
      return HrApiEnvelope(
        success: resultMap['success'] == true,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
        error: resultMap['error']?.toString(),
      );
    }
    return HrApiEnvelope(
      success: false,
      error: resultMap['message']?.toString() ?? 'Request failed',
    );
  }
}
