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

class ProjectExpenseDashboardCategory {
  const ProjectExpenseDashboardCategory({
    required this.name,
    required this.amount,
    required this.percent,
  });

  final String name;
  final double amount;
  final double percent;

  factory ProjectExpenseDashboardCategory.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseDashboardCategory(
      name: json['name']?.toString() ?? 'Unknown',
      amount: _asDouble(json['amount']),
      percent: _asDouble(json['percent']),
    );
  }
}

class ProjectExpenseDashboardAccount {
  const ProjectExpenseDashboardAccount({
    required this.rank,
    required this.code,
    required this.name,
    required this.amount,
    required this.status,
  });

  final int rank;
  final String code;
  final String name;
  final double amount;
  final String status;

  factory ProjectExpenseDashboardAccount.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseDashboardAccount(
      rank: _asInt(json['rank']),
      code: json['code']?.toString() ?? '-',
      name: json['name']?.toString() ?? 'Unnamed Account',
      amount: _asDouble(json['amount']),
      status: json['status']?.toString() ?? 'normal',
    );
  }
}

class ProjectExpenseDashboardAlert {
  const ProjectExpenseDashboardAlert({
    required this.title,
    required this.description,
    required this.priority,
    required this.actionText,
  });

  final String title;
  final String description;
  final String priority;
  final String actionText;

  factory ProjectExpenseDashboardAlert.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseDashboardAlert(
      title: json['title']?.toString() ?? 'Alert',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'normal',
      actionText: json['action_text']?.toString() ?? '',
    );
  }
}

class ProjectExpenseDashboardTrend {
  const ProjectExpenseDashboardTrend({
    required this.week,
    required this.amount,
  });

  final String week;
  final double amount;

  factory ProjectExpenseDashboardTrend.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseDashboardTrend(
      week: json['week']?.toString() ?? '-',
      amount: _asDouble(json['amount']),
    );
  }
}

class ProjectExpenseDashboardTotals {
  const ProjectExpenseDashboardTotals({
    required this.budget,
    required this.totalCost,
    required this.exceedAmount,
    required this.exceedPercent,
    required this.weeklyAverage,
    required this.lpo,
    required this.pettyCash,
    required this.invoice,
    required this.labor,
    required this.staff,
    required this.commitment,
  });

  final double budget;
  final double totalCost;
  final double exceedAmount;
  final double exceedPercent;
  final double weeklyAverage;
  final double lpo;
  final double pettyCash;
  final double invoice;
  final double labor;
  final double staff;
  final double commitment;

  factory ProjectExpenseDashboardTotals.fromJson(Map<String, dynamic>? json) {
    return ProjectExpenseDashboardTotals(
      budget: _asDouble(json?['budget'] ?? json?['total_budget']),
      totalCost: _asDouble(json?['total_cost'] ?? json?['cost_total']),
      exceedAmount: _asDouble(
        json?['exceed_amount'] ?? json?['over_budget_amount'],
      ),
      exceedPercent: _asDouble(
        json?['exceed_percent'] ??
            json?['exceed_percentage'] ??
            json?['over_budget_percent'],
      ),
      weeklyAverage: _asDouble(json?['weekly_average'] ?? json?['avg_weekly']),
      lpo: _asDouble(json?['lpo']),
      pettyCash: _asDouble(json?['petty_cash']),
      invoice: _asDouble(json?['invoice']),
      labor: _asDouble(json?['labor']),
      staff: _asDouble(json?['staff']),
      commitment: _asDouble(json?['commitment']),
    );
  }
}

class ProjectExpenseDistributionItem {
  const ProjectExpenseDistributionItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  factory ProjectExpenseDistributionItem.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseDistributionItem(
      label: json['label']?.toString() ?? 'Other',
      amount: _asDouble(json['amount']),
    );
  }
}

class ProjectExpenseDistributionGroup {
  const ProjectExpenseDistributionGroup({
    required this.name,
    required this.items,
  });

  final String name;
  final List<ProjectExpenseDistributionItem> items;

  double get totalAmount =>
      items.fold<double>(0, (sum, e) => sum + e.amount.abs());

  factory ProjectExpenseDistributionGroup.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    return ProjectExpenseDistributionGroup(
      name: json['name']?.toString() ?? 'Other',
      items: itemsRaw
          .whereType<Map>()
          .map((e) => ProjectExpenseDistributionItem.fromJson(
                e.cast<String, dynamic>(),
              ))
          .toList(growable: false),
    );
  }
}

class ProjectExpenseDashboardModel {
  const ProjectExpenseDashboardModel({
    required this.health,
    required this.totals,
    required this.costDistribution,
    required this.categories,
    required this.topAccounts,
    required this.weeklyTrend,
    required this.alerts,
  });

  final String health;
  final ProjectExpenseDashboardTotals totals;
  final List<ProjectExpenseDistributionGroup> costDistribution;
  final List<ProjectExpenseDashboardCategory> categories;
  final List<ProjectExpenseDashboardAccount> topAccounts;
  final List<ProjectExpenseDashboardTrend> weeklyTrend;
  final List<ProjectExpenseDashboardAlert> alerts;

  factory ProjectExpenseDashboardModel.fromJson(Map<String, dynamic> json) {
    final kpisSource = (json['kpis'] as Map?)?.cast<String, dynamic>() ?? {};
    final costTotalsSource =
        (json['cost_totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final totalsSource = <String, dynamic>{
      ...(json['totals'] as Map?)?.cast<String, dynamic>() ?? {},
      ...(json['summary'] as Map?)?.cast<String, dynamic>() ?? {},
      ...kpisSource,
      ...costTotalsSource,
    };
    final categoriesRaw = (json['categories'] as List?) ??
        (json['category_contribution'] as List?) ??
        (json['contributions'] as List?) ??
        const [];
    final accountsRaw = (json['top_accounts'] as List?) ??
        (json['accounts'] as List?) ??
        (json['account_lines'] as List?) ??
        const [];
    final trendRaw = (json['weekly_trend'] as List?) ??
        (json['trend'] as List?) ??
        (json['weekly'] as List?) ??
        const [];
    final alertsRaw = (json['alerts'] as List?) ??
        (json['risks'] as List?) ??
        (json['warnings'] as List?) ??
        const [];
    final costDistributionRaw = (json['cost_distribution'] as List?) ?? const [];

    return ProjectExpenseDashboardModel(
      health: json['health']?.toString() ?? json['status']?.toString() ?? 'normal',
      totals: ProjectExpenseDashboardTotals.fromJson(totalsSource),
      costDistribution: costDistributionRaw
          .whereType<Map>()
          .map(
            (e) => ProjectExpenseDistributionGroup.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      categories: categoriesRaw
          .whereType<Map>()
          .map(
            (e) => ProjectExpenseDashboardCategory.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      topAccounts: accountsRaw
          .whereType<Map>()
          .map(
            (e) => ProjectExpenseDashboardAccount.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      weeklyTrend: trendRaw
          .whereType<Map>()
          .map(
            (e) => ProjectExpenseDashboardTrend.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      alerts: alertsRaw
          .whereType<Map>()
          .map(
            (e) => ProjectExpenseDashboardAlert.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}
