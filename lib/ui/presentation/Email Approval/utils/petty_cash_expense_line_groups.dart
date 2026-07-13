import 'package:flutter/material.dart';

class PettyCashExpenseLineGroup {
  const PettyCashExpenseLineGroup({
    required this.typeLabel,
    required this.totalAmount,
    required this.lines,
  });

  final String typeLabel;
  final double totalAmount;
  final List<Map<String, dynamic>> lines;
}

List<PettyCashExpenseLineGroup> groupPettyCashLinesByType(List<dynamic> rawLines) {
  final buckets = <String, List<Map<String, dynamic>>>{};

  for (final raw in rawLines) {
    if (raw is! Map) continue;
    final line = Map<String, dynamic>.from(raw);
    final label = _pick(line, const [
      'expense_type_label',
      'expense_type',
      'x_expense_type',
      'type',
    ]);
    final key = label.isEmpty ? 'Uncategorized' : label;
    buckets.putIfAbsent(key, () => []).add(line);
  }

  final groups = buckets.entries.map((entry) {
    var total = 0.0;
    for (final line in entry.value) {
      total += _readAmount(line);
    }
    entry.value.sort((a, b) {
      final projectA = _pick(a, const ['project_name', 'project']).toLowerCase();
      final projectB = _pick(b, const ['project_name', 'project']).toLowerCase();
      return projectA.compareTo(projectB);
    });
    return PettyCashExpenseLineGroup(
      typeLabel: entry.key,
      totalAmount: total,
      lines: entry.value,
    );
  }).toList();

  groups.sort((a, b) => a.typeLabel.compareTo(b.typeLabel));
  return groups;
}

double _readAmount(Map<String, dynamic> line) {
  final raw = line['amount'] ?? line['unit_price'] ?? line['subtotal'] ?? 0;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString()) ?? 0;
}

String _pick(Map<String, dynamic> line, List<String> keys) {
  for (final key in keys) {
    final value = line[key];
    if (value == null || value == false) continue;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') continue;
    return text;
  }
  return '';
}

/// Distinct badge colors per petty cash expense type (full-lines popup only).
Color pettyCashExpenseTypeBadgeColor({
  String? expenseTypeCode,
  String? expenseTypeLabel,
}) {
  switch ((expenseTypeCode ?? '').toLowerCase().trim()) {
    case 'hos':
      return const Color(0xFF6B4FAE);
    case 'off':
      return const Color(0xFF2E7D8C);
    case 'fleet':
      return const Color(0xFF1B6B4A);
    case 'repair':
      return const Color(0xFFB45309);
    case 'equi':
      return const Color(0xFF4F6FD6);
    case 'gov':
      return const Color(0xFF7A4B2E);
    case 'fine':
      return const Color(0xFFC0392B);
    case 'vendor':
      return const Color(0xFF5C6BC0);
    default:
      break;
  }

  final label = (expenseTypeLabel ?? '').toLowerCase();
  if (label.contains('hospitality')) return const Color(0xFF6B4FAE);
  if (label.contains('office')) return const Color(0xFF2E7D8C);
  if (label.contains('transport')) return const Color(0xFF1B6B4A);
  if (label.contains('tool') || label.contains('material')) {
    return const Color(0xFFB45309);
  }
  if (label.contains('equipment')) return const Color(0xFF4F6FD6);
  if (label.contains('government')) return const Color(0xFF7A4B2E);
  if (label.contains('fine')) return const Color(0xFFC0392B);
  if (label.contains('vendor')) return const Color(0xFF5C6BC0);
  return const Color(0xFF5F6B7A);
}

String pettyCashExpenseTypeBadgeLabel(Map<String, dynamic> line) {
  return _pick(line, const [
    'expense_type_label',
    'expense_type',
    'x_expense_type',
    'type',
  ]);
}
