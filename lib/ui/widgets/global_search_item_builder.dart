import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/ui/widgets/global_search_result_card.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Builds global-search cards: faded glass, watermark icons, no photos.
class GlobalSearchItemBuilder {
  GlobalSearchItemBuilder({
    required this.onTap,
    required this.highlight,
  });

  final void Function(GlobalSearchItem item) onTap;
  final Widget Function(String text, String keyword, {required TextStyle style})
      highlight;

  static String? asNonEmpty(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    if (s.toLowerCase() == 'false' || s.toLowerCase() == 'null') return null;
    return s;
  }

  static String? pickLabel(dynamic field) {
    if (field == null) return null;
    if (field is List && field.length > 1) {
      return asNonEmpty(field[1]);
    }
    return asNonEmpty(field);
  }

  static String formatAmount(dynamic raw) {
    if (raw == null) return '';
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString().replaceAll(',', '')) ?? 0.0;
    if (value == 0) return '';
    return NumberFormat('#,##0.##', 'en').format(value);
  }

  static String formatDate(dynamic raw) {
    final s = asNonEmpty(raw);
    if (s == null) return '';
    try {
      final normalized =
          s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
      final dt = DateTime.tryParse(normalized);
      if (dt == null) return s;
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return s;
    }
  }

  TextStyle titleStyle() => GoogleFonts.poppins(
        fontSize: 15.tsp,
        fontWeight: FontWeight.w700,
        color: GlobalSearchTheme.cardTitle,
      );

  GlobalSearchDetailLine _detail(
    String label,
    String value,
    IconData icon,
    String category,
    int index,
  ) {
    return GlobalSearchDetailLine(
      label: label,
      text: value,
      icon: icon,
      iconColor: GlobalSearchTheme.detailIconColor(category, index: index),
    );
  }

  Widget buildCard(
    GlobalSearchItem item,
    String keyword, {
    bool compact = false,
  }) {
    if (compact) {
      return GlobalSearchGlassCard(
        compact: true,
        category: item.category,
        onTap: () => onTap(item),
        title: highlight(item.title, keyword, style: titleStyle()),
        subtitle: item.subtitle,
      );
    }
    switch (item.category) {
      case 'lpo':
        return _lpo(item, keyword);
      case 'projects':
        return _project(item, keyword);
      case 'petty_cash':
        return _pettyCash(item, keyword);
      case 'my_actions':
        return _myActions(item, keyword);
      case 'documents':
        return _document(item, keyword);
      case 'notes':
        return _note(item, keyword);
      case 'tasks':
        return _task(item, keyword);
      default:
        return _generic(item, keyword);
    }
  }

  Widget _lpo(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('lpo');
    final poName = asNonEmpty(data['name']) ?? item.title;
    final partner = asNonEmpty(data['partner_name']) ??
        pickLabel(data['partner_id']);
    final project = asNonEmpty(data['project']);
    final requestedBy = asNonEmpty(data['requested_by']);
    final manager = asNonEmpty(data['requester_manager']);
    final amount = formatAmount(data['amount_total']);
    final date = formatDate(data['date_order'] ?? data['order_date']);
    final state = asNonEmpty(data['state'] ?? data['status']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (partner != null)
        _detail('Client', partner, Icons.business_rounded, 'lpo', i++),
      if (project != null)
        _detail('Project', project, Icons.apartment_rounded, 'lpo', i++),
      if (requestedBy != null)
        _detail('Requested by', requestedBy, Icons.person_outline_rounded,
            'lpo', i++),
      if (manager != null)
        _detail('Manager', manager, Icons.supervisor_account_outlined, 'lpo',
            i++),
      if (date.isNotEmpty)
        _detail('Date', date, Icons.calendar_today_outlined, 'lpo', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'lpo',
      onTap: () => onTap(item),
      title: highlight(poName, keyword, style: titleStyle()),
      subtitle: 'LPO #${item.id}',
      detailLines: details,
      accentColor: accent,
      trailing: _trailing(
        amount: amount,
        status: state?.toUpperCase(),
        statusColor: GlobalSearchTheme.statusColor(state ?? ''),
      ),
    );
  }

  Widget _project(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('projects');
    final location = asNonEmpty(data['location_id']) ??
        asNonEmpty(data['city']) ??
        asNonEmpty(data['location']);
    final status = asNonEmpty(data['project_status']);
    final woRef = asNonEmpty(data['wo_ref_no']);
    final agreement = asNonEmpty(data['agreement_no']) ??
        asNonEmpty(data['agreement_name']);
    final amount = formatAmount(data['wo_amount'] ?? data['amount_total']);
    final dateStart = formatDate(data['date_start'] ?? data['date']);
    final partner = pickLabel(data['partner_id']) ??
        asNonEmpty(data['partner_name']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (woRef != null)
        _detail('WO ref', woRef, Icons.tag_outlined, 'projects', i++),
      if (agreement != null)
        _detail('Agreement', agreement, Icons.handshake_outlined, 'projects',
            i++),
      if (partner != null)
        _detail('Client', partner, Icons.business_rounded, 'projects', i++),
      if (location != null)
        _detail('Location', location, Icons.location_on_outlined, 'projects',
            i++),
      if (status != null)
        _detail('Status', status, Icons.flag_outlined, 'projects', i++),
      if (dateStart.isNotEmpty)
        _detail('Start', dateStart, Icons.event_outlined, 'projects', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'projects',
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      subtitle: woRef ?? agreement ?? 'Project #${item.id}',
      detailLines: details,
      accentColor: accent,
      trailing: _trailing(
        amount: amount,
        amountColor: GlobalSearchTheme.greenBright,
      ),
    );
  }

  Widget _pettyCash(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('petty_cash');
    final status = asNonEmpty(data['state'] ?? data['status']) ?? 'pending';
    final emp = asNonEmpty(data['emp_name']) ??
        asNonEmpty(data['employee_name']);
    final project = asNonEmpty(data['project']);
    final sheetName = asNonEmpty(data['name']) ?? item.title;
    final amount = formatAmount(
      data['total_amount'] ?? data['amount_total'] ?? data['amount'],
    );
    final date = formatDate(data['date'] ?? data['create_date']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (emp != null)
        _detail('Employee', emp, Icons.badge_outlined, 'petty_cash', i++),
      if (project != null)
        _detail('Project', project, Icons.apartment_rounded, 'petty_cash', i++),
      if (date.isNotEmpty)
        _detail('Date', date, Icons.calendar_today_outlined, 'petty_cash', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'petty_cash',
      onTap: () => onTap(item),
      title: highlight(sheetName, keyword, style: titleStyle()),
      subtitle: 'Expense #${item.id}',
      detailLines: details,
      accentColor: accent,
      trailing: _trailing(
        amount: amount,
        amountColor: GlobalSearchTheme.greenBright,
        status: status.toUpperCase(),
        statusColor: GlobalSearchTheme.statusColor(status),
      ),
    );
  }

  Widget _myActions(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('my_actions');
    final status = asNonEmpty(data['status']) ?? 'pending';
    final employee = asNonEmpty(data['employee_name']);
    final requestType = asNonEmpty(data['request_type']);
    final reference = asNonEmpty(data['reference']);
    final vendor = asNonEmpty(data['vendor']);
    final project = asNonEmpty(data['project']);
    final amount = formatAmount(data['amount_total']);
    final date = formatDate(data['date'] ?? data['last_updated_on']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (employee != null)
        _detail('Employee', employee, Icons.person_outline_rounded,
            'my_actions', i++),
      if (requestType != null)
        _detail('Type', requestType, Icons.category_outlined, 'my_actions', i++),
      if (project != null)
        _detail('Project', project, Icons.apartment_rounded, 'my_actions', i++),
      if (vendor != null)
        _detail('Vendor', vendor, Icons.storefront_outlined, 'my_actions', i++),
      if (reference != null)
        _detail('Reference', reference, Icons.numbers_rounded, 'my_actions',
            i++),
      if (date.isNotEmpty)
        _detail('Date', date, Icons.calendar_today_outlined, 'my_actions', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'my_actions',
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      subtitle: requestType ?? reference ?? 'Action #${item.id}',
      detailLines: details,
      accentColor: accent,
      trailing: _trailing(
        amount: amount,
        amountColor: GlobalSearchTheme.greenBright,
        status: status.toUpperCase(),
        statusColor: GlobalSearchTheme.statusColor(status),
      ),
    );
  }

  Widget _document(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('documents');
    final mime = asNonEmpty(data['mimetype']);
    final size = data['file_size'];

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (mime != null)
        _detail('Type', mime, Icons.insert_drive_file_outlined, 'documents',
            i++),
      if (size != null)
        _detail('Size', GlobalSearchItem.formatFileSize(size),
            Icons.sd_storage_outlined, 'documents', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'documents',
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      subtitle: 'Document #${item.id}',
      detailLines: details,
      accentColor: accent,
    );
  }

  Widget _note(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('notes');
    final user = pickLabel(data['user_id']) ?? asNonEmpty(data['user_name']);
    final memo = asNonEmpty(data['memo']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (user != null)
        _detail('Author', user, Icons.person_outline_rounded, 'notes', i++),
      if (memo != null)
        _detail('Memo', memo, Icons.notes_outlined, 'notes', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'notes',
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      subtitle: 'Note #${item.id}',
      detailLines: details,
      accentColor: accent,
    );
  }

  Widget _task(GlobalSearchItem item, String keyword) {
    final data = item.additionalData ?? {};
    final accent = GlobalSearchTheme.accentFor('tasks');
    final project = pickLabel(data['project_id']) ??
        asNonEmpty(data['project_name']);
    final stage = pickLabel(data['stage_id']) ??
        asNonEmpty(data['stage_name']);

    var i = 0;
    final details = <GlobalSearchDetailLine>[
      if (project != null)
        _detail('Project', project, Icons.apartment_rounded, 'tasks', i++),
      if (stage != null)
        _detail('Stage', stage, Icons.timeline_outlined, 'tasks', i++),
    ];

    return GlobalSearchGlassCard(
      category: 'tasks',
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      subtitle: 'Task #${item.id}',
      detailLines: details,
      accentColor: accent,
    );
  }

  Widget _generic(GlobalSearchItem item, String keyword) {
    final accent = GlobalSearchTheme.accentFor(item.category);
    final details = <GlobalSearchDetailLine>[];
    if (item.subtitle != null && item.subtitle!.isNotEmpty) {
      details.add(_detail(
        'Info',
        item.subtitle!,
        Icons.info_outline_rounded,
        item.category,
        0,
      ));
    }

    return GlobalSearchGlassCard(
      category: item.category,
      onTap: () => onTap(item),
      title: highlight(item.title, keyword, style: titleStyle()),
      detailLines: details,
      accentColor: accent,
    );
  }

  Widget? _trailing({
    String amount = '',
    Color? amountColor,
    String? status,
    Color? statusColor,
  }) {
    if (amount.isEmpty && (status == null || status.isEmpty)) {
      return null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (amount.isNotEmpty)
          GlobalSearchAmountLabel(
            amount: amount,
            color: amountColor ?? GlobalSearchTheme.greenBright,
          ),
        if (status != null && status.isNotEmpty) ...[
          if (amount.isNotEmpty) SizedBox(height: 4.th),
          GlobalSearchStatusPill(
            label: status,
            color: statusColor ?? GlobalSearchTheme.grey,
          ),
        ],
      ],
    );
  }
}
