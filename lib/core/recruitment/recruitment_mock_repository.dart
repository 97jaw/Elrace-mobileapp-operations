import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/recruitment/recruitment_mock_requisitions.dart';

/// Central mock store for Module 2 — // TODO(backend): replace with API.
abstract final class RecruitmentMockRepository {
  static const _namePool = <(String, String)>[
    ('Sarah Ahmed', 'sarah.ahmed@example.com'),
    ('Omar Khalid', 'omar.k@example.com'),
    ('Priya Nair', 'priya.nair@example.com'),
    ('James Chen', 'james.chen@example.com'),
    ('Fatima Al-Sayed', 'fatima.s@example.com'),
    ('Luca Romano', 'luca.r@example.com'),
    ('Aisha Bello', 'aisha.b@example.com'),
    ('Tomás Ruiz', 'tomas.r@example.com'),
    ('Elena Vogt', 'elena.v@example.com'),
    ('Marcus Webb', 'marcus.w@example.com'),
    ('Nour Hassan', 'nour.h@example.com'),
    ('Chris Park', 'chris.p@example.com'),
    ('Yuki Tanaka', 'yuki.t@example.com'),
    ('Amira Saleh', 'amira.s@example.com'),
  ];


  static Requisition _req(String id) {
    return recruitmentMockRequisitions().firstWhere(
      (e) => e.id == id,
      orElse: () => throw ArgumentError('Unknown requisition $id'),
    );
  }

  static RecruitmentPipelineCounts _countPipeline(List<RecruitmentCandidate> c) {
    var a = 0, s = 0, i = 0, o = 0, h = 0;
    for (final x in c) {
      switch (x.stage) {
        case 'APPLIED':
          a++;
        case 'SCREENING':
          s++;
        case 'INTERVIEW':
          i++;
        case 'OFFER':
          o++;
        case 'HIRED':
          h++;
        default:
          break;
      }
    }
    return RecruitmentPipelineCounts(
      applied: a,
      screening: s,
      interview: i,
      offer: o,
      hired: h,
    );
  }

  /// Stage sequence for first [n] candidates (rest REJECTED/WITHDRAWN if needed).
  static List<String> _stagePattern(int n) {
    const base = <String>[
      'APPLIED',
      'APPLIED',
      'SCREENING',
      'SCREENING',
      'INTERVIEW',
      'INTERVIEW',
      'OFFER',
      'HIRED',
      'REJECTED',
      'WITHDRAWN',
      'APPLIED',
      'SCREENING',
    ];
    if (n <= base.length) return base.take(n).toList();
    return List.generate(n, (i) => base[i % base.length]);
  }

  static List<RecruitmentCandidate> _candidatesFor(Requisition r) {
    final n = r.candidateCount.clamp(1, 14);
    final stages = _stagePattern(n);
    final out = <RecruitmentCandidate>[];
    for (var i = 0; i < n; i++) {
      final seed = _namePool[i % _namePool.length];
      final id = '${r.id}-c-$i';
      final stage = stages[i];
      final hasAssessments =
          stage == 'INTERVIEW' || stage == 'OFFER' || stage == 'HIRED';
      final assessments = <RecruitmentAssessmentSummary>[];
      double? avg;
      if (hasAssessments) {
        assessments.add(
          RecruitmentAssessmentSummary(
            id: '$id-a1',
            roundName: 'Technical',
            date: r.openedAt.add(Duration(days: 3 + i)),
            interviewer: 'Alex Morgan',
            overallScore: 4.0 + (i % 3) * 0.25,
            recommendation: i.isEven ? 'Hire' : 'Strong Hire',
            isDraft: false,
          ),
        );
        if (stage == 'OFFER' || stage == 'HIRED') {
          assessments.add(
            RecruitmentAssessmentSummary(
              id: '$id-a2',
              roundName: 'HR',
              date: r.openedAt.add(Duration(days: 8 + i)),
              interviewer: 'Samira Khan',
              overallScore: 3.8,
              recommendation: 'Hire',
              isDraft: false,
            ),
          );
        }
        avg = assessments.map((e) => e.overallScore).reduce((a, b) => a + b) /
            assessments.length;
      }
      String? offerId;
      if (stage == 'OFFER' || stage == 'HIRED') {
        offerId = '${r.id}-o-$i';
      }
      out.add(
        RecruitmentCandidate(
          id: id,
          requisitionId: r.id,
          requisitionRef: r.referenceNumber,
          jobTitle: r.jobTitle,
          fullName: seed.$1,
          email: seed.$2,
          phone: '+971 50 ${1000000 + i * 12345}',
          stage: stage,
          appliedAt: r.openedAt.add(Duration(days: i)),
          avgScore: avg,
          source: i % 3 == 0 ? 'LinkedIn' : (i % 3 == 1 ? 'Referral' : 'Careers site'),
          yearsExperience: 2 + (i % 8),
          currentCompany: 'Company ${i % 4}',
          expectedSalary: 'AED ${(15000 + i * 1000)}',
          noticePeriod: i.isEven ? '30 days' : '60 days',
          assessments: assessments,
          offerId: offerId,
          notesLines: [
            '${r.openedAt.add(Duration(days: 1 + i)).toIso8601String().split('T').first}: HR noted profile review.',
          ],
        ),
      );
    }
    return out;
  }

  static List<RecruitmentOfferListRow> _offerRows(Requisition r, List<RecruitmentCandidate> c) {
    final rows = <RecruitmentOfferListRow>[];
    for (final x in c) {
      if (x.offerId != null) {
        rows.add(
          RecruitmentOfferListRow(
            id: x.offerId!,
            candidateId: x.id,
            candidateName: x.fullName,
            uiStatus: x.stage == 'HIRED' ? 'ACCEPTED' : 'SENT',
            sentAt: r.openedAt.add(const Duration(days: 20)),
          ),
        );
      }
    }
    return rows;
  }

  static List<RecruitmentActivityEntry> _activities(Requisition r, List<RecruitmentCandidate> c) {
    return [
      RecruitmentActivityEntry(
        at: r.openedAt,
        message: 'Requisition opened — ${r.referenceNumber}',
      ),
      RecruitmentActivityEntry(
        at: r.openedAt.add(const Duration(days: 1)),
        message: 'Posted to internal careers',
      ),
      ...c.take(4).map(
            (x) => RecruitmentActivityEntry(
              at: x.appliedAt,
              message: 'Candidate applied — ${x.fullName}',
            ),
          ),
    ];
  }

  static RequisitionDetailModel detailFor(String requisitionId) {
    final r = _req(requisitionId);
    final candidates = _candidatesFor(r);
    final pipeline = _countPipeline(candidates);
    final offers = _offerRows(r, candidates);
    return RequisitionDetailModel(
      requisition: r,
      jobDescription:
          '${r.jobTitle} — We are growing the ${r.department} team in ${r.location}. '
          'You will collaborate across squads, ship quality software, and mentor peers. '
          'Minimum 50 characters required for Phase 1 description text per SRD.',
      keyResponsibilities:
          '• Deliver features end-to-end\n• Participate in code review\n• Improve reliability',
      requiredSkills: const ['Flutter', 'Dart', 'REST', 'Git'],
      salaryMinAed: 18000,
      salaryMaxAed: 28000,
      requiredBy: DateTime(2026, 8, 30),
      pipeline: pipeline,
      candidates: candidates,
      offers: offers,
      activities: _activities(r, candidates),
    );
  }

  static List<RecruitmentCandidate> allCandidates() {
    final all = <RecruitmentCandidate>[];
    for (final r in recruitmentMockRequisitions()) {
      all.addAll(_candidatesFor(r));
    }
    return all;
  }

  static RecruitmentCandidate candidateById(String id) {
    for (final r in recruitmentMockRequisitions()) {
      for (final c in _candidatesFor(r)) {
        if (c.id == id) return c;
      }
    }
    throw ArgumentError('Unknown candidate $id');
  }

  static RecruitmentAssessmentDetail assessmentDetail(String assessmentId) {
    for (final r in recruitmentMockRequisitions()) {
      for (final c in _candidatesFor(r)) {
        for (final a in c.assessments) {
          if (a.id == assessmentId) {
            return RecruitmentAssessmentDetail(
              id: a.id,
              candidateId: c.id,
              candidateName: c.fullName,
              roundName: a.roundName,
              interviewDate: a.date,
              interviewer: a.interviewer,
              technical: 4,
              problemSolving: 5,
              communication: 4,
              culturalFit: 4,
              strengths: 'Solid system design, clear communication under pressure.',
              concerns: 'Limited exposure to our legacy stack — trainable.',
              recommendation: a.recommendation,
              comments: 'Would fit well with the mobile pod.',
              isDraft: a.isDraft,
              interviewerEmpId: 'EMP-1001',
              currentUserEmpId: 'EMP-1001',
            );
          }
        }
      }
    }
    throw ArgumentError('Unknown assessment $assessmentId');
  }

  static RecruitmentOfferDetail offerDetail(String offerId) {
    for (final r in recruitmentMockRequisitions()) {
      for (final c in _candidatesFor(r)) {
        if (c.offerId == offerId) {
          return RecruitmentOfferDetail(
            id: offerId,
            candidateName: c.fullName,
            positionTitle: r.jobTitle,
            referenceNumber: 'OFF/${r.referenceNumber.split('/').last}',
            uiStatus: c.stage == 'HIRED' ? 'ACCEPTED' : 'SENT',
            sentAt: r.openedAt.add(const Duration(days: 20)),
            expiryAt: r.openedAt.add(const Duration(days: 50)),
            department: r.department,
            reportingManager: r.raisedBy,
            location: r.location,
            joiningDate: DateTime(2026, 7, 1),
            employmentType: 'Full-time',
            salaryBreakdownLines: [
              'Base: AED 22,000 / month',
              'Allowances: AED 2,000',
              'Bonus: performance-based',
            ],
          );
        }
      }
    }
    throw ArgumentError('Unknown offer $offerId');
  }
}
