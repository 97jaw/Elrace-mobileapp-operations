import 'package:flutter/material.dart';

/// Module 5 — day_status visual tokens (TASKS §4). Backend owns status; mobile maps display only.
abstract final class DayStatusTokens {
  static const Color present = Color(0xFF2E7D5B);
  static const Color late = Color(0xFFC77700);
  static const Color earlyDeparture = Color(0xFFC77700);
  static const Color absent = Color(0xFF8B2635);
  static const Color onLeave = Color(0xFF1F3A5F);
  static const Color jobMission = Color(0xFF1F3A5F);
  static const Color offDay = Color(0xFF6B7280);
  static const Color holiday = Color(0xFF6B7280);
  static const Color unknown = Color(0xFF6B7280);

  /// Normalize API `day_status` (or legacy status strings) for lookup.
  static String normalize(String? raw) {
    return (raw ?? '')
        .trim()
        .toUpperCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  static Color colorForBackendStatus(String? raw) {
    final k = normalize(raw);
    if (k.contains('PRESENT')) return present;
    if (k.contains('LATE')) return late;
    if (k.contains('EARLY') && k.contains('DEPART')) return earlyDeparture;
    if (k.contains('ABSENT')) return absent;
    if (k.contains('LEAVE') || k == 'ON LEAVE') return onLeave;
    if (k.contains('MISSION') || k.contains('JOB MISSION')) return jobMission;
    if (k.contains('OFF') && k.contains('DAY')) return offDay;
    if (k.contains('HOLIDAY')) return holiday;
    return unknown;
  }

  static IconData iconForBackendStatus(String? raw) {
    final k = normalize(raw);
    if (k.contains('PRESENT')) return Icons.circle;
    if (k.contains('LATE')) return Icons.schedule;
    if (k.contains('EARLY') && k.contains('DEPART')) {
      return Icons.timer_outlined;
    }
    if (k.contains('ABSENT')) return Icons.close;
    if (k.contains('LEAVE') || k == 'ON LEAVE') return Icons.star_outline;
    if (k.contains('MISSION')) return Icons.flight_takeoff;
    if (k.contains('OFF') && k.contains('DAY')) return Icons.crop_square;
    if (k.contains('HOLIDAY')) return Icons.event;
    return Icons.help_outline;
  }

  static String labelForBackendStatus(String? raw) {
    final k = normalize(raw);
    if (k.isEmpty) return '—';
    if (k.contains('PRESENT')) return 'Present';
    if (k.contains('LATE')) return 'Late';
    if (k.contains('EARLY') && k.contains('DEPART')) return 'Early departure';
    if (k.contains('ABSENT')) return 'Absent';
    if (k.contains('LEAVE')) return 'On leave';
    if (k.contains('MISSION')) return 'Job mission';
    if (k.contains('OFF') && k.contains('DAY')) return 'Off day';
    if (k.contains('HOLIDAY')) return 'Holiday';
    return (raw ?? '').trim();
  }
}
