import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:el_race/core/timesheet/providers/labor_transfer_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_person_avatar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const _pageSize = 20;

class LtNewRequestScreen extends ConsumerStatefulWidget {
  const LtNewRequestScreen({super.key});

  @override
  ConsumerState<LtNewRequestScreen> createState() => _LtNewRequestScreenState();
}

class _LtNewRequestScreenState extends ConsumerState<LtNewRequestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _noteController = TextEditingController();
  final _selectedLaborIds = <int>{};

  /// Single target foreman only — selecting another replaces this.
  LaborTransferPerson? _target;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<bool> _hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _submit() async {
    final target = _target;
    if (_selectedLaborIds.isEmpty || target == null || _submitting) return;

    final online = await _hasNetwork();
    if (!mounted) return;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network required to create a labor transfer'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit transfer?'),
        content: Text(
          'Transfer ${_selectedLaborIds.length} '
          'labor${_selectedLaborIds.length == 1 ? '' : 's'}'
          ' to ${target.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final created = await api.create(
        laborIds: _selectedLaborIds.toList(growable: false),
        targetForemanId: target.id,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${created.name} submitted')),
      );
      Navigator.of(context).pushReplacementNamed(
        TimesheetRouteNames.laborTransferDetail,
        arguments: created.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TimesheetOdooException
                ? e.message
                : 'Could not submit transfer',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _selectedLaborIds.isNotEmpty && _target != null && !_submitting;
    final selectedLabel = _target == null
        ? 'Selected: None'
        : 'Selected: ${_target!.name}';

    return TmScaffold(
      glassTitle: 'New Transfer',
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              tabs: const [
                Tab(text: 'Labors'),
                Tab(text: 'Transfer Foreman'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LaborsTab(
                  selectedIds: _selectedLaborIds,
                  onToggle: (labor) {
                    if (!labor.isSelectable) return;
                    setState(() {
                      if (_selectedLaborIds.contains(labor.id)) {
                        _selectedLaborIds.remove(labor.id);
                      } else {
                        _selectedLaborIds.add(labor.id);
                      }
                    });
                  },
                ),
                _ForemenTab(
                  selected: _target,
                  selectedLabel: selectedLabel,
                  onSelect: (foreman) {
                    setState(() {
                      // Single select: replace previous.
                      _target = foreman;
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TimesheetModuleLayout.screenPaddingH,
              8,
              TimesheetModuleLayout.screenPaddingH,
              8,
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                isDense: true,
                filled: true,
                fillColor: TimesheetModuleColors.glassSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusSm,
                  ),
                  borderSide: const BorderSide(
                    color: TimesheetModuleColors.glassBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusSm,
                  ),
                  borderSide: const BorderSide(
                    color: TimesheetModuleColors.glassBorder,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TimesheetModuleLayout.screenPaddingH,
              0,
              TimesheetModuleLayout.screenPaddingH,
              12,
            ),
            child: TmPrimaryButton(
              label: _submitting ? 'Submitting…' : 'Submit Transfer',
              warm: true,
              icon: PhosphorIcons.paperPlaneTilt(),
              onPressed: canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaborsTab extends ConsumerStatefulWidget {
  const _LaborsTab({
    required this.selectedIds,
    required this.onToggle,
  });

  final Set<int> selectedIds;
  final ValueChanged<LaborTransferLaborOption> onToggle;

  @override
  ConsumerState<_LaborsTab> createState() => _LaborsTabState();
}

class _LaborsTabState extends ConsumerState<_LaborsTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<LaborTransferLaborOption> _rows = const [];
  String _query = '';
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
      final page = await api.fetchLabors(
        search: _query,
        limit: _pageSize,
        offset: 0,
      );
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
        _error =
            e is TimesheetOdooException ? e.message : 'Could not load labors';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final page = await api.fetchLabors(
        search: _query,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TimesheetModuleLayout.screenPaddingH,
            8,
            TimesheetModuleLayout.screenPaddingH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.selectedIds.length} selected',
                style: const TextStyle(
                  color: TimesheetModuleColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TmSearchField(
                hintText: 'Search name or emp id',
                onDebouncedChanged: (q) {
                  _query = q;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
        child: TimesheetLoadingState(style: TimesheetLoadingStyle.list),
      );
    }
    if (_error != null) {
      return TimesheetErrorState(message: _error!, onRetry: _reload);
    }
    if (_rows.isEmpty) {
      return const TimesheetEmptyState(message: 'No labors in your city');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        8,
        TimesheetModuleLayout.screenPaddingH,
        16,
      ),
      itemCount: _rows.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _rows.length) {
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
        final labor = _rows[index];
        final selected = widget.selectedIds.contains(labor.id);
        final disabled = !labor.isSelectable;
        String? reason;
        if (labor.inMyTeam) reason = 'Already in your team';
        if (labor.inPendingTransfer) reason = 'Pending transfer';

        return Opacity(
          opacity: disabled ? 0.45 : 1,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !disabled,
            onTap: disabled ? null : () => widget.onToggle(labor),
            leading: LtPersonAvatar(
              name: labor.name,
              photoUrl: labor.photo,
              size: 40,
            ),
            title: Text(
              labor.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: TimesheetModuleColors.ink,
              ),
            ),
            subtitle: Text(
              [
                if (labor.empId.isNotEmpty) labor.empId,
                if (labor.currentForeman != null)
                  'Foreman: ${labor.currentForeman!.name}',
                if (reason != null) reason,
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                color: TimesheetModuleColors.warmMuted,
              ),
            ),
            trailing: Checkbox(
              value: selected,
              onChanged: disabled ? null : (_) => widget.onToggle(labor),
              activeColor: TimesheetModuleColors.accent,
            ),
          ),
        );
      },
    );
  }
}

class _ForemenTab extends ConsumerStatefulWidget {
  const _ForemenTab({
    required this.selected,
    required this.selectedLabel,
    required this.onSelect,
  });

  final LaborTransferPerson? selected;
  final String selectedLabel;
  final ValueChanged<LaborTransferPerson> onSelect;

  @override
  ConsumerState<_ForemenTab> createState() => _ForemenTabState();
}

class _ForemenTabState extends ConsumerState<_ForemenTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<LaborTransferPerson> _rows = const [];
  String _query = '';
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
      final page = await api.fetchForemen(
        search: _query,
        limit: _pageSize,
        offset: 0,
      );
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
            : 'Could not load foremen';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final page = await api.fetchForemen(
        search: _query,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TimesheetModuleLayout.screenPaddingH,
            8,
            TimesheetModuleLayout.screenPaddingH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selectedLabel,
                style: const TextStyle(
                  color: TimesheetModuleColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TmSearchField(
                hintText: 'Search foreman',
                onDebouncedChanged: (q) {
                  _query = q;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
        child: TimesheetLoadingState(style: TimesheetLoadingStyle.list),
      );
    }
    if (_error != null) {
      return TimesheetErrorState(message: _error!, onRetry: _reload);
    }
    if (_rows.isEmpty) {
      return const TimesheetEmptyState(message: 'No foremen found');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        8,
        TimesheetModuleLayout.screenPaddingH,
        16,
      ),
      itemCount: _rows.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _rows.length) {
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
        final f = _rows[index];
        final selected = widget.selected?.id == f.id;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => widget.onSelect(f),
          leading: LtPersonAvatar(name: f.name, photoUrl: f.photo, size: 40),
          title: Text(
            f.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: TimesheetModuleColors.ink,
            ),
          ),
          subtitle: Text(
            [
              if (f.empId != null && f.empId!.isNotEmpty) f.empId!,
              if (f.cityName != null) f.cityName!,
              if (f.sameCity == true) 'Same city',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 12,
              color: TimesheetModuleColors.warmMuted,
            ),
          ),
          trailing: Icon(
            selected
                ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill)
                : PhosphorIcons.circle(),
            color: selected
                ? TimesheetModuleColors.accent
                : TimesheetModuleColors.warmMuted,
          ),
        );
      },
    );
  }
}
