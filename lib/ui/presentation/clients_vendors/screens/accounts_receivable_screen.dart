import 'dart:async';

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/data/clients_lists_repository.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/clients_vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accounts Receivable — customer summary (who owes us).
class AccountsReceivableScreen extends StatefulWidget {
  const AccountsReceivableScreen({super.key});

  @override
  State<AccountsReceivableScreen> createState() =>
      _AccountsReceivableScreenState();
}

class _AccountsReceivableScreenState extends State<AccountsReceivableScreen> {
  final _repo = ClientsListsRepository();
  final _year = DateTime.now().year;

  List<ArSummaryItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchArSummary(
        year: _year,
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
        _error = 'Could not load receivables.';
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
        title: 'Accounts Receivable',
        icon: Icons.account_balance_wallet_rounded,
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
                                ? 'No outstanding receivables.'
                                : 'No matches for “$_keyword”.'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }
                  final item = _items[index];
                  return _ArCard(
                    item: item,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        ClientsVendorsRouteNames.outstandingInvoices,
                        arguments: OutstandingInvoicesArgs(
                          year: _year,
                          partnerId: item.partnerId,
                          partnerName: item.partnerName,
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _ArCard extends StatelessWidget {
  const _ArCard({required this.item, required this.onTap});

  final ArSummaryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = item.overdueAmount > 0.009;
    return PressableScale(
      onTap: onTap,
      child: Transform(
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
                ClientsVendorsTheme.cardGradientTop,
                ClientsVendorsTheme.cardGradientBottom,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: ClientsVendorsTheme.cardGradientBottom
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
                    name: item.partnerName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.partnerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MoneyRow(
                label: 'Total Outstanding',
                value: item.totalOutstandingFormatted,
                valueColor: overdue
                    ? ClientsVendorsTheme.amountDueOverdue
                    : ClientsVendorsTheme.amountDueOpen,
              ),
              const SizedBox(height: 6),
              _MoneyRow(
                label: 'Overdue',
                value: item.overdueAmountFormatted,
                valueColor: overdue
                    ? ClientsVendorsTheme.amountDueOverdue
                    : Colors.white70,
              ),
              const SizedBox(height: 6),
              _MoneyRow(
                label: 'Current (0–30 days)',
                value: item.current030Formatted,
              ),
              const SizedBox(height: 6),
              _MoneyRow(
                label: 'Total Invoiced (YTD)',
                value: item.totalInvoicedYtdFormatted,
              ),
            ],
          ),
        ),
      ),
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
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white70,
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
