double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class ProjectFinancialSummary {
  const ProjectFinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.marginPercent,
  });

  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final double marginPercent;

  factory ProjectFinancialSummary.fromJson(Map<String, dynamic>? json) {
    return ProjectFinancialSummary(
      totalIncome: _toDouble(
        json?['total_income'] ?? json?['income_total'] ?? json?['totalIncome'],
      ),
      totalExpense: _toDouble(
        json?['total_expense'] ??
            json?['total_expenses'] ??
            json?['expense_total'] ??
            json?['totalExpense'],
      ),
      netProfit: _toDouble(
        json?['net_profit'] ?? json?['net_profits'] ?? json?['netProfit'],
      ),
      marginPercent: _toDouble(
        json?['margin'] ?? json?['margin_percent'] ?? json?['marginPercent'],
      ),
    );
  }
}

class ProjectFinancialStatementLine {
  const ProjectFinancialStatementLine({
    required this.id,
    required this.name,
    required this.balance,
    required this.level,
    required this.children,
  });

  final String id;
  final String name;
  final double balance;
  final int level;
  final List<ProjectFinancialStatementLine> children;

  bool get hasChildren => children.isNotEmpty;

  factory ProjectFinancialStatementLine.fromJson(Map<String, dynamic> json) {
    final rawChildren = (json['children'] as List?) ??
        (json['lines'] as List?) ??
        (json['items'] as List?) ??
        (json['accounts'] as List?) ??
        const [];
    final id = json['id']?.toString();
    final code = json['code']?.toString();
    final name = json['name']?.toString() ??
        json['label']?.toString() ??
        json['title']?.toString() ??
        json['account_name']?.toString() ??
        json['group_name']?.toString() ??
        'Unnamed line';
    return ProjectFinancialStatementLine(
      id: (id == null || id.isEmpty) ? (code ?? name) : id,
      name: code != null && code.isNotEmpty ? '$code - $name' : name,
      balance: _toDouble(json['balance'] ?? json['amount'] ?? json['total']),
      level: _toInt(json['level'] ?? json['depth']),
      children: rawChildren
          .whereType<Map>()
          .map(
            (e) => ProjectFinancialStatementLine.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ProjectFinancialModel {
  const ProjectFinancialModel({
    required this.summary,
    required this.statement,
  });

  final ProjectFinancialSummary summary;
  final List<ProjectFinancialStatementLine> statement;

  factory ProjectFinancialModel.fromJson(Map<String, dynamic> json) {
    final statementRaw = (json['statement'] as List?) ??
        (json['hierarchy'] as List?) ??
        (json['lines'] as List?) ??
        (json['accounts'] as List?) ??
        const [];
    final summarySource = (json['summary'] as Map?)?.cast<String, dynamic>() ??
        (json['totals'] as Map?)?.cast<String, dynamic>() ??
        (json['kpis'] as Map?)?.cast<String, dynamic>() ??
        json;
    return ProjectFinancialModel(
      summary: ProjectFinancialSummary.fromJson(summarySource),
      statement: statementRaw
          .whereType<Map>()
          .map(
            (e) => ProjectFinancialStatementLine.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}
