import 'dart:async';

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/data/clients_lists_repository.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/clients_vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Outstanding Invoices — document detail list.
class OutstandingInvoicesScreen extends StatefulWidget {
  const OutstandingInvoicesScreen({super.key, this.args});

  final OutstandingInvoicesArgs? args;

  @override
  State<OutstandingInvoicesScreen> createState() =>
      _OutstandingInvoicesScreenState();
}

class _OutstandingInvoicesScreenState extends State<OutstandingInvoicesScreen> {
  final _repo = ClientsListsRepository();

  late final int _year;
  late final int? _month;
  late final int? _partnerId;
  late final String? _partnerName;

  List<OutstandingInvoiceItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _year = args?.year ?? DateTime.now().year;
    _month = args?.month;
    _partnerId = args?.partnerId;
    _partnerName = args?.partnerName;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String get _title {
    final partner = _partnerName;
    if (partner != null && partner.isNotEmpty) {
      return 'Invoices · $partner';
    }
    final month = _month;
    if (month != null) {
      final label = DateFormat.MMMM().format(DateTime(_year, month));
      return 'Invoices · $label $_year';
    }
    return 'Outstanding Invoices';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchOutstandingInvoices(
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
        _error = 'Could not load invoices.';
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
    return ClientsListScaffold(
      chrome: ClientsListChrome(
        title: _title,
        icon: Icons.receipt_long_rounded,
        onSearchChanged: _onSearch,
      ),
      body: RefreshIndicator(
        color: ClientsVendorsTheme.iconAccent,
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (_items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(
                        _error ??
                            (_keyword.isEmpty
                                ? 'No outstanding invoices.'
                                : 'No matches for “$_keyword”.'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }
                  return _InvoiceCard(item: _items[index]);
                },
              ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.item});

  final OutstandingInvoiceItem item;

  Color get _statusColor {
    switch (item.statusCode) {
      case 'overdue':
        return ClientsVendorsTheme.amountDueOverdue;
      case 'due_soon':
        return ClientsVendorsTheme.amountDueOpen;
      case 'partial':
        return ClientsVendorsTheme.amountPaid;
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
              ClientsVendorsTheme.cardGradientTopAlt,
              ClientsVendorsTheme.cardGradientBottomAlt,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
              color: ClientsVendorsTheme.cardGradientBottomAlt
                  .withValues(alpha: 0.45),
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.18),
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
              leftLabel: 'Invoice date',
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
              valueColor: ClientsVendorsTheme.amountPaid,
            ),
            const SizedBox(height: 4),
            _MoneyRow(
              label: 'Amount Due',
              value: item.amountDueFormatted,
              valueColor: item.statusCode == 'overdue'
                  ? ClientsVendorsTheme.amountDueOverdue
                  : ClientsVendorsTheme.amountDueOpen,
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
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
    this.valueColor = Colors.white,
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
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
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
