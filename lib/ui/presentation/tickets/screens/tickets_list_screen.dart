import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_widgets.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_sober_card.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/tickets/screens/ticket_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _TicketListFilter { all, open, inProgress, closed }

class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({
    super.key,
    this.embedded = false,
    this.highPriorityOnly = false,
  });

  static const routeName = '/productivity_tickets';

  /// When true, render body only (hub owns shell + bottom bar).
  final bool embedded;

  /// When true, start filtered to high-priority tickets.
  final bool highPriorityOnly;

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  static const _pageSize = 10;
  _TicketListFilter _filter = _TicketListFilter.all;
  bool _highPriorityOnly = false;
  bool _searchVisible = false;
  String _query = '';
  int _visibleCount = _pageSize;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _highPriorityOnly = widget.highPriorityOnly;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketFirebaseProvider>().loadTickets();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  List<TicketModel> _filtered(List<TicketModel> all) {
    Iterable<TicketModel> items = all;
    switch (_filter) {
      case _TicketListFilter.all:
        break;
      case _TicketListFilter.open:
        items = items.where((t) => t.status == TicketStatus.open);
        break;
      case _TicketListFilter.inProgress:
        items = items.where((t) => t.status == TicketStatus.inProgress);
        break;
      case _TicketListFilter.closed:
        items = items.where((t) => t.status.isTerminal);
        break;
    }
    if (_highPriorityOnly) {
      items = items.where((t) => t.priority == TicketPriority.high);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((t) {
        return t.title.toLowerCase().contains(q) ||
            (t.description ?? '').toLowerCase().contains(q) ||
            (t.assigneeName ?? '').toLowerCase().contains(q);
      });
    }
    return items.toList();
  }

  Color _statusBg(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return ProductivityLightTheme.statusPendingBg;
      case TicketStatus.inProgress:
        return ProductivityLightTheme.statusActiveBg;
      case TicketStatus.resolved:
        return ProductivityLightTheme.statusCompletedBg;
      case TicketStatus.closed:
        return ProductivityLightTheme.statusOverdueBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<TicketFirebaseProvider>(
        builder: (context, provider, _) {
          final filtered = _filtered(provider.tickets);
          final visible = filtered.take(_visibleCount).toList();
          final hasMore = visible.length < filtered.length;

          if (provider.isLoading && provider.tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: provider.loadTickets,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final entry in [
                                  (_TicketListFilter.all, 'All'),
                                  (_TicketListFilter.open, 'Open'),
                                  (_TicketListFilter.inProgress, 'In progress'),
                                  (_TicketListFilter.closed, 'Closed'),
                                ]) ...[
                                  _chip(
                                    entry.$2,
                                    _filter == entry.$1,
                                    () => setState(() {
                                      _filter = entry.$1;
                                      _visibleCount = _pageSize;
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                _chip(
                                  'High',
                                  _highPriorityOnly,
                                  () => setState(() {
                                    _highPriorityOnly = !_highPriorityOnly;
                                    _visibleCount = _pageSize;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _searchVisible = !_searchVisible;
                            if (!_searchVisible) {
                              _searchController.clear();
                              _query = '';
                            }
                          }),
                          icon: Icon(
                            _searchVisible
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_searchVisible)
                  SliverToBoxAdapter(
                    child: ProductivityLightSearchField(
                      controller: _searchController,
                      hintText: 'Search tickets…',
                      onChanged: (q) => setState(() {
                        _query = q;
                        _visibleCount = _pageSize;
                      }),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
                    child: Text(
                      '${filtered.length} ticket${filtered.length == 1 ? '' : 's'}',
                      style: ProductivityLightTheme.cardMeta,
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No tickets',
                        style: ProductivityLightTheme.cardSubtitle
                            .copyWith(fontSize: 16),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ticket = visible[index];
                        return ProductivitySoberCard(
                          title: ticket.title,
                          statusLabel: ticket.status.label,
                          statusBackground: _statusBg(ticket.status),
                          subtitle: [
                            if (ticket.assigneeName?.isNotEmpty == true)
                              ticket.assigneeName!
                            else
                              'Unassigned',
                            if (ticket.parentTaskTitle?.isNotEmpty == true)
                              '· ${ticket.parentTaskTitle}',
                          ].join(' '),
                          dateText:
                              DateFormat('MMM d').format(ticket.updatedAt),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TicketDetailsScreen(
                                  ticketId: ticket.firebaseId!,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                if (hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
    );

    if (widget.embedded) return body;

    return ProductivityLightShell(
      showBack: true,
      title: 'Tickets',
      body: body,
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ProductivityLightTheme.ink
                : ProductivityLightTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? ProductivityLightTheme.ink
                  : ProductivityLightTheme.border,
            ),
          ),
          child: Text(
            label,
            style: ProductivityLightTheme.cardSubtitle.copyWith(
              color: selected ? Colors.white : ProductivityLightTheme.ink,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
