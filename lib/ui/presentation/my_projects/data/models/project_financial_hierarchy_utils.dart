import 'package:el_race/ui/presentation/my_projects/data/models/project_financial_model.dart';

/// Resolves income/expense branches and flattens hierarchy lines for list UIs.
class ProjectFinancialHierarchyUtils {
  ProjectFinancialHierarchyUtils._();

  static const Set<String> _incomeKeywords = {
    'income',
    'revenue',
    'turnover',
    'sales',
    'billing',
    'credit',
    'إيراد',
  };

  static const Set<String> _expenseKeywords = {
    'expense',
    'expenses',
    'cost',
    'costs',
    'cogs',
    'overhead',
    'charge',
    'payroll',
    'مصروف',
  };

  static double sumBranch(ProjectFinancialStatementLine line) {
    if (line.children.isEmpty) return line.balance;
    return line.children.fold<double>(
      line.balance == 0 ? 0 : line.balance,
      (a, c) => a + sumBranch(c),
    );
  }

  /// Depth-first: first node whose name matches any keyword.
  static ProjectFinancialStatementLine? findBranchDeep(
    List<ProjectFinancialStatementLine> roots,
    Set<String> keywords,
  ) {
    for (final r in roots) {
      final hit = _findInTree(r, keywords);
      if (hit != null) return hit;
    }
    return null;
  }

  static ProjectFinancialStatementLine? _findInTree(
    ProjectFinancialStatementLine node,
    Set<String> keywords,
  ) {
    if (_nameMatchesAny(node.name, keywords)) return node;
    for (final c in node.children) {
      final hit = _findInTree(c, keywords);
      if (hit != null) return hit;
    }
    return null;
  }

  static bool _nameMatchesAny(String name, Set<String> keywords) {
    final n = name.toLowerCase();
    for (final k in keywords) {
      if (n.contains(k)) return true;
    }
    return false;
  }

  static ProjectFinancialStatementLine? findIncomeRoot(
    List<ProjectFinancialStatementLine> roots,
  ) {
    final hit = findBranchDeep(roots, _incomeKeywords);
    if (hit != null) return hit;
    return _fallbackSplitChild(roots, preferLargerBalance: true);
  }

  static ProjectFinancialStatementLine? findExpenseRoot(
    List<ProjectFinancialStatementLine> roots,
  ) {
    final hit = findBranchDeep(roots, _expenseKeywords);
    if (hit != null) return hit;
    return _fallbackSplitChild(roots, preferLargerBalance: false);
  }

  /// When structure is a single wrapper with two main P&L groups.
  /// Uses sibling order for 2 children (common: income first, expense second).
  static ProjectFinancialStatementLine? _fallbackSplitChild(
    List<ProjectFinancialStatementLine> roots, {
    required bool preferLargerBalance,
  }) {
    if (roots.isEmpty) return null;
    if (roots.length == 1 && roots.first.children.length >= 2) {
      final ch = roots.first.children;
      return preferLargerBalance ? ch.first : ch[1];
    }
    if (roots.length >= 2) {
      final sorted = List<ProjectFinancialStatementLine>.from(roots)
        ..sort((a, b) => sumBranch(b).abs().compareTo(sumBranch(a).abs()));
      if (preferLargerBalance) return sorted.first;
      return sorted.length >= 2 ? sorted[1] : sorted.first;
    }
    return roots.first;
  }

  /// Shallow match (legacy): first root whose name contains [keyword].
  static ProjectFinancialStatementLine? findPrimaryLineShallow(
    List<ProjectFinancialStatementLine> rows,
    String keyword,
  ) {
    final lowered = keyword.toLowerCase();
    for (final row in rows) {
      if (row.name.toLowerCase().contains(lowered)) return row;
    }
    return null;
  }

  /// Prefer leaf accounts; otherwise every descendant group/line under [root]
  /// (so nested children show even when the API omits true leaves).
  static List<ProjectFinancialStatementLine> collectRecordLines(
    ProjectFinancialStatementLine root,
  ) {
    final leaves = _leafLinesSorted(root);
    if (leaves.isNotEmpty) return leaves;

    final flat = <ProjectFinancialStatementLine>[];
    void walk(ProjectFinancialStatementLine n) {
      for (final c in n.children) {
        if (c.balance.abs() > 1e-9 || c.hasChildren) {
          flat.add(c);
        }
        walk(c);
      }
    }

    walk(root);
    flat.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    if (flat.isNotEmpty) return flat;

    final kids = root.children.where((c) {
      return c.balance.abs() > 1e-9 || c.children.isNotEmpty;
    }).toList();
    if (kids.isEmpty) {
      return root.balance.abs() > 1e-9 ? <ProjectFinancialStatementLine>[root] : const [];
    }
    kids.sort((a, b) => sumBranch(b).abs().compareTo(sumBranch(a).abs()));
    return kids;
  }

  /// Depth under [root] for indentation (0 = direct child of root).
  static int depthOfLine(
    ProjectFinancialStatementLine root,
    ProjectFinancialStatementLine target,
  ) {
    int? dfs(ProjectFinancialStatementLine n, int d) {
      if (n.id == target.id) return d;
      for (final c in n.children) {
        final r = dfs(c, d + 1);
        if (r != null) return r;
      }
      return null;
    }

    for (final c in root.children) {
      final r = dfs(c, 0);
      if (r != null) return r;
    }
    return 0;
  }

  static List<ProjectFinancialStatementLine> _leafLinesSorted(
    ProjectFinancialStatementLine root,
  ) {
    final out = <ProjectFinancialStatementLine>[];
    void walk(ProjectFinancialStatementLine n) {
      if (!n.hasChildren) {
        if (n.balance.abs() > 1e-9) out.add(n);
      } else {
        for (final c in n.children) {
          walk(c);
        }
      }
    }

    walk(root);
    out.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    return out;
  }
}
