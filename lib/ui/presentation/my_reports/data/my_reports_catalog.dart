import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:el_race/ui/presentation/my_reports/models/my_report_type.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:flutter/material.dart';

abstract final class MyReportsCatalog {
  static const categories = <MyReportCategory>[
    MyReportCategory(
      type: MyReportCategoryType.hr,
      title: 'HR Report',
      subtitle: 'People, leave, and details',
      icon: Icons.badge_outlined,
      colors: [
        MyReportsTheme.frostBlue,
        MyReportsTheme.skyBlue,
        MyReportsTheme.lightTeal,
      ],
      types: [
        MyReportType(id: 'hr_emp_project', title: 'Employee by Project', subtitle: 'Allocation and utilization'),
        MyReportType(id: 'hr_leave_balance', title: 'Leave Balance', subtitle: 'Remaining leave by employee'),
        MyReportType(id: 'hr_emp_details', title: 'Employee Details', subtitle: 'Profile and assignment summary'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.project,
      title: 'Project Report',
      subtitle: 'Summary and progress insights',
      icon: Icons.apartment_rounded,
      colors: [
        MyReportsTheme.skyBlue,
        MyReportsTheme.lightTeal,
        MyReportsTheme.tealBlue,
      ],
      types: [
        MyReportType(id: 'project_summary', title: 'Project Summary', subtitle: 'Overall portfolio snapshot'),
        MyReportType(id: 'project_progress', title: 'Project Progress', subtitle: 'Milestone and timeline view'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.clientInvoice,
      title: 'Client Invoice Report',
      subtitle: 'Invoices and retention analytics',
      icon: Icons.receipt_long_rounded,
      colors: [
        MyReportsTheme.lightTeal,
        MyReportsTheme.tealBlue,
        MyReportsTheme.steelBlue,
      ],
      types: [
        MyReportType(id: 'invoice_project', title: 'Invoice by Project', subtitle: 'Project-wise invoice status'),
        MyReportType(id: 'invoice_client', title: 'Invoice by Client', subtitle: 'Client-wise invoice status'),
        MyReportType(id: 'invoice_retention', title: 'Retention', subtitle: 'Cohort-like retention matrix'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.purchase,
      title: 'Purchase Report',
      subtitle: 'Suppliers, LPOs, and delays',
      icon: Icons.shopping_cart_outlined,
      colors: [
        MyReportsTheme.tealBlue,
        MyReportsTheme.steelBlue,
        MyReportsTheme.royalBlue,
      ],
      types: [
        MyReportType(id: 'purchase_project', title: 'Purchase by Project', subtitle: 'Spend by project'),
        MyReportType(id: 'purchase_supplier_compare', title: 'Supplier Comparison', subtitle: 'Compare performance and spend'),
        MyReportType(id: 'purchase_vendor', title: 'Vendor Report', subtitle: 'Vendor score and history'),
        MyReportType(id: 'purchase_project_lpos', title: 'Project LPOs', subtitle: 'LPOs grouped by project'),
        MyReportType(id: 'purchase_delayed_lpos', title: 'Delayed LPOs', subtitle: 'Delayed purchase orders'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.timesheet,
      title: 'Timesheet Report',
      subtitle: 'Hours and workforce output',
      icon: Icons.schedule_rounded,
      colors: [
        MyReportsTheme.steelBlue,
        MyReportsTheme.royalBlue,
        MyReportsTheme.deepNavy,
      ],
      types: [
        MyReportType(id: 'timesheet_project', title: 'By Project', subtitle: 'Hours and output by project'),
        MyReportType(id: 'timesheet_employee', title: 'By Employee / Labor', subtitle: 'Labor-level productivity'),
        MyReportType(id: 'timesheet_overtime', title: 'Overtime', subtitle: 'Overtime trends and hotspots'),
        MyReportType(id: 'timesheet_foreman', title: 'Foreman Report', subtitle: 'Foreman-level performance'),
        MyReportType(id: 'timesheet_monthly', title: 'Monthly Summary', subtitle: 'Monthly hours and variance'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.attendance,
      title: 'Attendance Report',
      subtitle: 'Presence, lateness, and trends',
      icon: Icons.fact_check_outlined,
      colors: [
        MyReportsTheme.frostBlue,
        MyReportsTheme.tealBlue,
        MyReportsTheme.royalBlue,
      ],
      types: [
        MyReportType(id: 'attendance_daily', title: 'Daily Attendance', subtitle: 'Day-wise attendance'),
        MyReportType(id: 'attendance_late', title: 'Absence & Late', subtitle: 'Absence and lateness analysis'),
        MyReportType(id: 'attendance_project', title: 'Attendance by Project', subtitle: 'Project-level attendance'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.pettyCash,
      title: 'Petty Cash Report',
      subtitle: 'Cash holder and category spend',
      icon: Icons.account_balance_wallet_outlined,
      colors: [
        MyReportsTheme.skyBlue,
        MyReportsTheme.steelBlue,
        MyReportsTheme.deepNavy,
      ],
      types: [
        MyReportType(id: 'petty_holder', title: 'Holder Report', subtitle: 'Spending by holder'),
        MyReportType(id: 'petty_project', title: 'By Project', subtitle: 'Project petty cash distribution'),
        MyReportType(id: 'petty_category', title: 'By Category', subtitle: 'Category-wise spend'),
      ],
    ),
    MyReportCategory(
      type: MyReportCategoryType.management,
      title: 'Management Reports',
      subtitle: 'Executive snapshots and approvals',
      icon: Icons.insights_outlined,
      colors: [
        MyReportsTheme.royalBlue,
        MyReportsTheme.deepNavy,
        MyReportsTheme.steelBlue,
      ],
      types: [
        MyReportType(id: 'mgmt_dashboard', title: 'Projects Dashboard', subtitle: 'Portfolio executive dashboard'),
        MyReportType(id: 'mgmt_expense_summary', title: 'Expense Summary', subtitle: 'Top cost areas and trends'),
        MyReportType(id: 'mgmt_pending_approvals', title: 'Pending Approvals', subtitle: 'Approvals queue overview'),
        MyReportType(id: 'mgmt_pm_report', title: 'Project Manager Report', subtitle: 'PM-level KPIs and blockers'),
      ],
    ),
  ];

  static MyReportCategory byType(MyReportCategoryType type) {
    return categories.firstWhere((e) => e.type == type);
  }
}
