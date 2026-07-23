import 'dart:async';
import 'dart:ui';

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/data/vendors_lists_repository.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Vendor bill document list — KPI card drill-down.
class VendorBillsScreen extends StatefulWidget {
  const VendorBillsScreen({super.key, required this.args});

  final VendorBillsArgs args;

  @override
  State<VendorBillsScreen> createState() => _VendorBillsScreenState();
}

class _VendorBillsScreenState extends State<VendorBillsScreen> {
  final _repo = VendorsListsRepository();

  late final VendorBillsScope _scope;
  late final int? _year;
  late final int? _month;
  late final int? _partnerId;
  late final String? _partnerName;

  List<VendorBillItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _scope = _parseScope(args.scope);
    _year = args.year;
    _month = args.month;
    _partnerId = args.partnerId;
    _partnerName = args.partnerName;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  VendorBillsScope _parseScope(String raw) {
    switch (raw) {
      case 'paid':
        return VendorBillsScope.paid;
      case 'outstanding':
        return VendorBillsScope.outstanding;
      case 'overdue':
        return VendorBillsScope.overdue;
      case 'due_soon':
        return VendorBillsScope.dueSoon;
      default:
        return VendorBillsScope.purchases;
    }
  }

  String get _title {
    final partner = _partnerName;
    if (partner != null && partner.isNotEmpty) {
      return '${_scope.title} · $partner';
    }
    final month = _month;
    final year = _year;
    if (month != null && year != null) {
      final label = DateFormat.MMMM().format(DateTime(year, month));
      return '${_scope.title} · $label $year';
    }
    if (year != null &&
        (_scope == VendorBillsScope.purchases ||
            _scope == VendorBillsScope.paid)) {
      return '${_scope.title} · $year';
    }
    return _scope.title;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchBills(
        scope: _scope,
        year: _year,
        month: _month,
        partnerId: _partnerId,
        keyword: _keyword,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load vendor bills.';
      });
    }
  }

  void _onSearch(String value) {
    _keyword = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VendorsTheme.deepLight,
                  VendorsTheme.deepMid,
                  VendorsTheme.deepDark,
                ],
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.55),
                  radius: 0.9,
                  colors: [
                    VendorsTheme.glowBright,
                    VendorsTheme.glowMid,
                    VendorsTheme.glowSoft,
                    VendorsTheme.glowEdge,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClientsListChrome(
                title: _title,
                icon: Icons.receipt_long_rounded,
                onSearchChanged: _onSearch,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: VendorsTheme.iconPaid,
                  onRefresh: _load,
                  child: _loading && _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                          itemCount: _items.isEmpty ? 1 : _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (_items.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Text(
                                  _error ??
                                      (_keyword.isEmpty
                                          ? 'No vendor bills found.'
                                          : 'No matches for “$_keyword”.'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            }
                            return _VendorBillCard(item: _items[index]);
                          },
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorBillCard extends StatelessWidget {
  const _VendorBillCard({required this.item});

  final VendorBillItem item;

  Color get _statusColor {
    switch (item.statusCode) {
      case 'overdue':
        return const Color(0xFFE53E3E);
      case 'due_soon':
        return VendorsTheme.iconPurchases;
      case 'paid':
        return VendorsTheme.iconPaid;
      case 'partial':
        return VendorsTheme.glowBright;
      default:
        return const Color(0xFFF6E05E);
    }
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(0.03),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              VendorsTheme.kpiGradientTop,
              VendorsTheme.kpiGradientBottom,
            ],
          ),
          border: Border.all(
            color: VendorsTheme.electricBorder.withValues(alpha: 0.55),
            width: 0.7,
          ),
          boxShadow: [
            BoxShadow(
              color: VendorsTheme.deepDark.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 12),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClientsPartnerAvatar(
                  imageUrl: item.imageUrl,
                  name: item.partnerName.isNotEmpty
                      ? item.partnerName
                      : item.name,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VendorsTheme.kpiTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: VendorsTheme.kpiMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _statusColor.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetaRow(
              leftLabel: 'Bill date',
              leftValue: _fmtDate(item.invoiceDate),
              rightLabel: 'Due date',
              rightValue: _fmtDate(item.invoiceDateDue),
            ),
            const SizedBox(height: 8),
            _MoneyRow(label: 'Total Amount', value: item.amountTotalFormatted),
            const SizedBox(height: 4),
            _MoneyRow(
              label: 'Amount Paid',
              value: item.amountPaidFormatted,
              valueColor: VendorsTheme.iconPaid,
            ),
            const SizedBox(height: 4),
            _MoneyRow(
              label: 'Amount Due',
              value: item.amountDueFormatted,
              valueColor: item.statusCode == 'overdue'
                  ? const Color(0xFFE53E3E)
                  : VendorsTheme.iconPurchases,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetaCell(label: leftLabel, value: leftValue)),
        const SizedBox(width: 10),
        Expanded(child: _MetaCell(label: rightLabel, value: rightValue)),
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: VendorsTheme.kpiMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: VendorsTheme.kpiTitle,
          ),
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.valueColor = VendorsTheme.kpiTitle,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: VendorsTheme.kpiMuted,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
