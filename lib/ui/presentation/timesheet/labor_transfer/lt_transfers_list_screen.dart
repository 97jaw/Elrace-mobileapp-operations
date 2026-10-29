import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:el_race/core/timesheet/providers/labor_transfer_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_direction_chip.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_person_avatar.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_status_chip.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const _pageSize = 20;

class LtTransfersListScreen extends ConsumerStatefulWidget {
  const LtTransfersListScreen({
    super.key,
    this.audience = LtListAudience.foreman,
  });

  final LtListAudience audience;

  @override
  ConsumerState<LtTransfersListScreen> createState() =>
      _LtTransfersListScreenState();
}

class _LtTransfersListScreenState extends ConsumerState<LtTransfersListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  bool _showToApprove = true;
  int _tabLength = 2;

  bool get _isManager => widget.audience == LtListAudience.manager;

  @override
  void initState() {
    super.initState();
    // Manager always has To approve; foreman starts with My requests only until
    // counts confirm they are an approver.
    _showToApprove = _isManager;
    _tabLength = _showToApprove ? 2 : 1;
    _tabs = TabController(length: _tabLength, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(laborTransferCountsProvider);
    });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  void _applyTabConfig(LaborTransferCounts counts) {
    final show = _isManager || counts.isApprover || counts.toApprove > 0;
    final nextLen = show ? 2 : 1;
    if (show == _showToApprove && nextLen == _tabLength && _tabs != null) {
      return;
    }
    final oldIndex = _tabs?.index ?? 0;
    _tabs?.dispose();
    setState(() {
      _showToApprove = show;
      _tabLength = nextLen;
      _tabs = TabController(
        length: _tabLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, _tabLength - 1),
      );
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).pushNamed(TimesheetRouteNames.laborTransferNew);
    if (!mounted) return;
    ref.invalidate(laborTransferCountsProvider);
    setState(() {});
  }

  Future<void> _onListRefreshed() async {
    ref.invalidate(laborTransferCountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LaborTransferCounts>>(
      laborTransferCountsProvider,
      (prev, next) {
        final counts = next.asData?.value;
        if (counts == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyTabConfig(counts);
        });
      },
    );
    final counts = ref.watch(laborTransferCountsProvider).asData?.value ??
        LaborTransferCounts.empty;

    final primaryLabel = _isManager ? 'Requests' : 'My requests';
    final toApproveCount = counts.toApprove;

    return TmScaffold(
      glassTitle: 'Labor transfer',
      padding: EdgeInsets.zero,
      glassTrailing: [
        if (!_isManager)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _openCreate,
              style: TextButton.styleFrom(
                foregroundColor: TimesheetModuleColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.plusCircle(), size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    'Create',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabs,
              labelColor: TimesheetModuleColors.accent,
              unselectedLabelColor: TimesheetModuleColors.warmMuted,
              indicatorColor: TimesheetModuleColors.accent,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: primaryLabel),
                if (_showToApprove)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('To approve'),
                        if (toApproveCount > 0) ...[
                          const SizedBox(width: 6),
                          _CountBadge(count: toApproveCount),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                if (_isManager)
                  _SingleBoxList(
                    box: LaborTransferBox.involved,
                    showDirection: false,
                    onRefreshed: _onListRefreshed,
                  )
                else
                  _MyRequestsList(onRefreshed: _onListRefreshed),
                if (_showToApprove)
                  _SingleBoxList(
                    box: LaborTransferBox.toApprove,
                    showDirection: false,
                    onRefreshed: _onListRefreshed,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        color: TimesheetModuleColors.danger,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Merged mine + incoming, date desc, with Sent / Incoming chips.
class _MyRequestsList extends ConsumerStatefulWidget {
  const _MyRequestsList({required this.onRefreshed});

  final Future<void> Function() onRefreshed;

  @override
  ConsumerState<_MyRequestsList> createState() => _MyRequestsListState();
}

class _MyRequestsListState extends ConsumerState<_MyRequestsList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _byId = <int, LaborTransferRecord>{};
  int _mineOffset = 0;
  int _incomingOffset = 0;
  bool _hasMoreMine = true;
  bool _hasMoreIncoming = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (!_hasMoreMine && !_hasMoreIncoming) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  List<LaborTransferRecord> get _sorted {
    final rows = _byId.values.toList()
      ..sort((a, b) {
        final da = a.requestDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.requestDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
    return rows;
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _byId.clear();
      _mineOffset = 0;
      _incomingOffset = 0;
      _hasMoreMine = true;
      _hasMoreIncoming = true;
    });
    try {
      await _fetchPage();
      await widget.onRefreshed();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is TimesheetOdooException
            ? e.message
            : 'Could not load transfers';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || (!_hasMoreMine && !_hasMoreIncoming)) return;
    setState(() => _loadingMore = true);
    try {
      await _fetchPage();
    } catch (_) {
      // Keep existing rows; user can pull to refresh.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _fetchPage() async {
    final api = ref.read(laborTransferApiProvider);
    final futures = <Future<List<LaborTransferRecord>>>[];
    if (_hasMoreMine) {
      futures.add(
        api.list(
          box: LaborTransferBox.mine,
          limit: _pageSize,
          offset: _mineOffset,
        ),
      );
    } else {
      futures.add(Future.value(const []));
    }
    if (_hasMoreIncoming) {
      futures.add(
        api.list(
          box: LaborTransferBox.incoming,
          limit: _pageSize,
          offset: _incomingOffset,
        ),
      );
    } else {
      futures.add(Future.value(const []));
    }
    final results = await Future.wait(futures);
    final mine = results[0];
    final incoming = results[1];
    if (!mounted) return;
    setState(() {
      for (final row in [...mine, ...incoming]) {
        _byId[row.id] = row;
      }
      if (_hasMoreMine) {
        _mineOffset += mine.length;
        _hasMoreMine = mine.length >= _pageSize;
      }
      if (_hasMoreIncoming) {
        _incomingOffset += incoming.length;
        _hasMoreIncoming = incoming.length >= _pageSize;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _TransferListBody(
      loading: _loading,
      error: _error,
      rows: _sorted,
      loadingMore: _loadingMore,
      showDirection: true,
      scrollController: _scroll,
      onRefresh: _reload,
      onRetry: _reload,
    );
  }
}

class _SingleBoxList extends ConsumerStatefulWidget {
  const _SingleBoxList({
    required this.box,
    required this.showDirection,
    required this.onRefreshed,
  });

  final LaborTransferBox box;
  final bool showDirection;
  final Future<void> Function() onRefreshed;

  @override
  ConsumerState<_SingleBoxList> createState() => _SingleBoxListState();
}

class _SingleBoxListState extends ConsumerState<_SingleBoxList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<LaborTransferRecord> _rows = const [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || !_hasMore) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
      _offset = 0;
      _hasMore = true;
    });
    try {
      final api = ref.read(laborTransferApiProvider);
      final page = await api.list(
        box: widget.box,
        limit: _pageSize,
        offset: 0,
      );
      await widget.onRefreshed();
      if (!mounted) return;
      setState(() {
        _rows = page;
        _offset = page.length;
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is TimesheetOdooException
            ? e.message
            : 'Could not load transfers';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final page = await api.list(
        box: widget.box,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...page];
        _offset += page.length;
        _hasMore = page.length >= _pageSize;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _TransferListBody(
      loading: _loading,
      error: _error,
      rows: _rows,
      loadingMore: _loadingMore,
      showDirection: widget.showDirection,
      scrollController: _scroll,
      onRefresh: _reload,
      onRetry: _reload,
    );
  }
}

class _TransferListBody extends StatelessWidget {
  const _TransferListBody({
    required this.loading,
    required this.error,
    required this.rows,
    required this.loadingMore,
    required this.showDirection,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final List<LaborTransferRecord> rows;
  final bool loadingMore;
  final bool showDirection;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          8,
          TimesheetModuleLayout.screenPaddingH,
          16,
        ),
        child: TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 5,
        ),
      );
    }
    if (error != null) {
      return TimesheetErrorState(message: error!, onRetry: onRetry);
    }
    if (rows.isEmpty) {
      return RefreshIndicator(
        color: TimesheetModuleColors.accent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            TimesheetEmptyState(message: 'No transfers here yet'),
          ],
        ),
      );
    }

    final loginId = TimesheetProjectAccessService.loginEmployeeId();
    return RefreshIndicator(
      color: TimesheetModuleColors.accent,
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          8,
          TimesheetModuleLayout.screenPaddingH,
          24,
        ),
        itemCount: rows.length + (loadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: TimesheetModuleColors.accent,
                  ),
                ),
              ),
            );
          }
          final row = rows[index];
          return _TransferRow(
            record: row,
            showDirection: showDirection,
            direction: _directionFor(row, loginId),
            onTap: () async {
              await Navigator.of(context).pushNamed(
                TimesheetRouteNames.laborTransferDetail,
                arguments: row.id,
              );
              await onRefresh();
            },
          );
        },
      ),
    );
  }

  LtTransferDirection _directionFor(LaborTransferRecord row, int? loginId) {
    if (loginId != null && row.requester?.id == loginId) {
      return LtTransferDirection.sent;
    }
    return LtTransferDirection.incoming;
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.record,
    required this.showDirection,
    required this.direction,
    required this.onTap,
  });

  final LaborTransferRecord record;
  final bool showDirection;
  final LtTransferDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy · HH:mm');
    final target = record.targetForeman;
    final requester = record.requester;
    final countLabel =
        '${record.laborCount} labor${record.laborCount == 1 ? '' : 's'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: TimesheetModuleColors.glassSurface,
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            border: Border.all(color: TimesheetModuleColors.glassBorder),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      countLabel,
                      style: const TextStyle(
                        color: TimesheetModuleColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  LtStatusChip(state: record.state),
                ],
              ),
              const SizedBox(height: 10),
              _PersonLine(
                prefix: 'To:',
                name: target?.name ?? '—',
                photoUrl: target?.photo,
              ),
              const SizedBox(height: 6),
              _PersonLine(
                prefix: 'From:',
                name: requester?.name ?? '—',
                photoUrl: requester?.photo,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.requestDate != null
                          ? fmt.format(record.requestDate!.toLocal())
                          : '—',
                      style: const TextStyle(
                        color: TimesheetModuleColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (showDirection) LtDirectionChip(direction: direction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonLine extends StatelessWidget {
  const _PersonLine({
    required this.prefix,
    required this.name,
    this.photoUrl,
  });

  final String prefix;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            prefix,
            style: const TextStyle(
              color: TimesheetModuleColors.warmMuted,
              fontSize: 13,
            ),
          ),
        ),
        LtPersonAvatar(name: name, photoUrl: photoUrl, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TimesheetModuleColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
