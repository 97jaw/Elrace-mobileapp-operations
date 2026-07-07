class ProjectExpenseBreakdownPill {
  const ProjectExpenseBreakdownPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  factory ProjectExpenseBreakdownPill.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseBreakdownPill(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class ProjectExpenseBreakdownAccount {
  const ProjectExpenseBreakdownAccount({
    required this.name,
    required this.total,
    required this.totalDisplay,
  });

  final String name;
  final double total;
  final String totalDisplay;

  factory ProjectExpenseBreakdownAccount.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseBreakdownAccount(
      name: json['name']?.toString() ?? '',
      total: _parseAmount(json['total']),
      totalDisplay: json['total_display']?.toString() ?? '',
    );
  }
}

class ProjectExpenseBreakdownSubgroup {
  const ProjectExpenseBreakdownSubgroup({
    required this.name,
    required this.total,
    required this.totalDisplay,
    required this.accounts,
  });

  final String name;
  final double total;
  final String totalDisplay;
  final List<ProjectExpenseBreakdownAccount> accounts;

  factory ProjectExpenseBreakdownSubgroup.fromJson(Map<String, dynamic> json) {
    final accountsRaw = json['accounts'] as List? ?? const [];
    return ProjectExpenseBreakdownSubgroup(
      name: json['name']?.toString() ?? '',
      total: _parseAmount(json['total']),
      totalDisplay: json['total_display']?.toString() ?? '',
      accounts: accountsRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseBreakdownAccount.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
    );
  }
}

class ProjectExpenseBreakdownGroup {
  const ProjectExpenseBreakdownGroup({
    required this.name,
    required this.total,
    required this.totalDisplay,
    required this.subgroups,
  });

  final String name;
  final double total;
  final String totalDisplay;
  final List<ProjectExpenseBreakdownSubgroup> subgroups;

  factory ProjectExpenseBreakdownGroup.fromJson(Map<String, dynamic> json) {
    final subRaw = json['subgroups'] as List? ?? const [];
    return ProjectExpenseBreakdownGroup(
      name: json['name']?.toString() ?? '',
      total: _parseAmount(json['total']),
      totalDisplay: json['total_display']?.toString() ?? '',
      subgroups: subRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseBreakdownSubgroup.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
    );
  }
}

/// ERP expense breakdown wizard `summary_json` structure.
class ProjectExpenseBreakdownPayload {
  const ProjectExpenseBreakdownPayload({
    required this.title,
    required this.eyebrow,
    required this.totalDisplay,
    required this.groupsCount,
    required this.subgroupsCount,
    required this.accountsCount,
    required this.pills,
    required this.groups,
    required this.emptyMessage,
  });

  final String title;
  final String eyebrow;
  final String totalDisplay;
  final int groupsCount;
  final int subgroupsCount;
  final int accountsCount;
  final List<ProjectExpenseBreakdownPill> pills;
  final List<ProjectExpenseBreakdownGroup> groups;
  final String emptyMessage;

  factory ProjectExpenseBreakdownPayload.fromJson(Map<String, dynamic> json) {
    final pillsRaw = json['pills'] as List? ?? const [];
    final groupsRaw = json['groups'] as List? ?? const [];
    return ProjectExpenseBreakdownPayload(
      title: json['title']?.toString() ?? '',
      eyebrow: json['eyebrow']?.toString() ?? 'Expense Breakdown',
      totalDisplay: json['total_display']?.toString() ?? '',
      groupsCount: _asInt(json['groups_count']),
      subgroupsCount: _asInt(json['subgroups_count']),
      accountsCount: _asInt(json['accounts_count']),
      pills: pillsRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseBreakdownPill.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
      groups: groupsRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseBreakdownGroup.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
      emptyMessage: json['empty_message']?.toString() ?? '',
    );
  }
}

class ProjectExpenseBreakdownResult {
  const ProjectExpenseBreakdownResult({
    required this.breakdown,
    required this.exportUrl,
    this.wizardId,
  });

  final ProjectExpenseBreakdownPayload breakdown;
  final String exportUrl;
  final int? wizardId;

  factory ProjectExpenseBreakdownResult.fromJson(Map<String, dynamic> json) {
    final breakdownMap = json['breakdown'] is Map
        ? Map<String, dynamic>.from(json['breakdown'] as Map)
        : <String, dynamic>{};
    return ProjectExpenseBreakdownResult(
      breakdown: ProjectExpenseBreakdownPayload.fromJson(breakdownMap),
      exportUrl: json['export_url']?.toString() ?? '',
      wizardId: json['wizard_id'] is int
          ? json['wizard_id'] as int
          : int.tryParse(json['wizard_id']?.toString() ?? ''),
    );
  }
}

double _parseAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
