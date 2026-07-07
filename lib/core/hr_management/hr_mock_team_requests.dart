import 'package:el_race/core/hr_management/hr_mock_requests.dart';

/// Team queue mock — M1 / M4 (SRD §4.1). Includes employee list headers.
List<Map<String, dynamic>> hrMockTeamRequestsJson() {
  final names = [
    ('Aisha Al-Mansoori', 'Senior Engineer · R&D', 'EMP-2401', 'R&D'),
    ('Omar Hassan', 'Project Lead · Delivery', 'EMP-2402', 'Delivery'),
    ('Priya Nair', 'Analyst · Finance', 'EMP-2403', 'Finance'),
    ('James Lee', 'Technician · Operations', 'EMP-2404', 'Operations'),
    ('Sara Ibrahim', 'HR Officer · HR', 'EMP-2405', 'HR'),
    ('Mohammed Ali', 'Developer · R&D', 'EMP-2406', 'R&D'),
    ('Fatima Khan', 'Consultant · Delivery', 'EMP-2407', 'Delivery'),
    ('Luca Rossi', 'Designer · Marketing', 'EMP-2408', 'Marketing'),
  ];

  final bases = hrMockMyRequestsJson();
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < bases.length && i < names.length; i++) {
    final b = Map<String, dynamic>.from(bases[i]);
    final n = names[i];
    b['employee_name'] = n.$1;
    b['employee_role_line'] = n.$2;
    b['employee_number'] = n.$3;
    b['department'] = n.$4;
    b['id'] = 'team_${b['id']}';
    out.add(b);
  }
  return out;
}

/// Larger pool for M4 search / pagination (mock).
List<Map<String, dynamic>> hrMockTeamArchiveJson() {
  final team = hrMockTeamRequestsJson();
  final extra = <Map<String, dynamic>>[];
  for (var y = 0; y < 3; y++) {
    for (var i = 0; i < team.length; i++) {
      final m = Map<String, dynamic>.from(team[i]);
      m['id'] = 'arch_${y}_$i';
      m['reference'] = '${m['reference']}-A$y';
      m['sequence'] = (m['sequence'] as int? ?? 0) - (y + 1) * 10;
      extra.add(m);
    }
  }
  return [...team, ...extra];
}
