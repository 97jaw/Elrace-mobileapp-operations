double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class ProjectExpenseTopItem {
  const ProjectExpenseTopItem({
    required this.rank,
    required this.name,
    required this.percent,
  });

  final int rank;
  final String name;
  final double percent;

  factory ProjectExpenseTopItem.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseTopItem(
      rank: _asInt(json['rank']),
      name: json['name']?.toString() ?? '',
      percent: _asDouble(json['percent']),
    );
  }
}

class ProjectExpenseSummaryLine {
  const ProjectExpenseSummaryLine({
    required this.key,
    required this.label,
    required this.amount,
  });

  final String key;
  final String label;
  final double amount;

  factory ProjectExpenseSummaryLine.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseSummaryLine(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      amount: _asDouble(json['amount']),
    );
  }
}

/// ERP `project.expense` Summary tab payload from `/api/project/expense/summary`.
class ProjectExpenseSummaryModel {
  const ProjectExpenseSummaryModel({
    required this.projectId,
    required this.projectName,
    required this.agreementName,
    required this.agreementNo,
    required this.currency,
    required this.totalWoAmount,
    required this.estimationAmount,
    required this.totalExpenses,
    required this.spendPercentOfWo,
    required this.topExpenses,
    required this.expenseLines,
  });

  final int projectId;
  final String projectName;
  final String agreementName;
  final String agreementNo;
  final String currency;
  final double totalWoAmount;
  final double estimationAmount;
  final double totalExpenses;
  final double spendPercentOfWo;
  final List<ProjectExpenseTopItem> topExpenses;
  final List<ProjectExpenseSummaryLine> expenseLines;

  factory ProjectExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    final topRaw = json['top_expenses'] as List? ?? const [];
    final linesRaw = json['expense_lines'] as List? ?? const [];
    return ProjectExpenseSummaryModel(
      projectId: _asInt(json['project_id']),
      projectName: json['project_name']?.toString() ?? '',
      agreementName: json['agreement_name']?.toString() ?? '',
      agreementNo: json['agreement_no']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'AED',
      totalWoAmount: _asDouble(json['total_wo_amount']),
      estimationAmount: _asDouble(json['estimation_amount']),
      totalExpenses: _asDouble(json['total_expenses']),
      spendPercentOfWo: _asDouble(json['spend_percent_of_wo']),
      topExpenses: topRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseTopItem.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
      expenseLines: linesRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseSummaryLine.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
    );
  }
}
