import 'dart:async';

import 'package:el_race/core/notifications/notification_config_service.dart';
import 'package:el_race/core/notifications/notification_inbox_repository.dart';
import 'package:el_race/core/notifications/notification_payload.dart';
import 'package:el_race/core/notifications/notification_router.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/Notification/notification_category_theme.dart';
import 'package:flutter/material.dart';

class NotificationInboxV2Screen extends StatefulWidget {
  const NotificationInboxV2Screen({super.key});

  @override
  State<NotificationInboxV2Screen> createState() =>
      _NotificationInboxV2ScreenState();
}

class _NotificationInboxV2ScreenState extends State<NotificationInboxV2Screen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<NotificationInboxRow> _rows = [];
  List<NotificationInboxCategory> _categories = [];
  String? _category;
  DateTimeRange? _range;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _open();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await _reload();
    try {
      await NotificationInboxRepository.markAllRead();
      await NotificationInboxRepository.refreshBadge();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rows = _rows
          .map((row) => NotificationInboxRow({...row.data, 'is_read': true}))
          .toList();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final categories = await NotificationInboxRepository.categories();
      final rows = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _rows = rows;
        _hasMore = rows.length >= 50;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notifications.';
      });
    }
  }

  Future<List<NotificationInboxRow>> _fetch(int offset) {
    final window = _window();
    return NotificationInboxRepository.list(
      offset: offset,
      q: _search.text,
      category: _category,
      dateFrom: window.$1,
      dateTo: window.$2,
    );
  }

  (DateTime, DateTime) _window() {
    final days = NotificationConfigService.current.retentionDays;
    final now = DateTime.now();
    final earliest = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    final from = _range?.start ?? earliest;
    final to = _range?.end ?? now;
    return (from.isBefore(earliest) ? earliest : from, to);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 240) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final rows = await _fetch(_rows.length);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...rows];
        _hasMore = rows.length >= 50;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickRange() async {
    final days = NotificationConfigService.current.retentionDays;
    final now = DateTime.now();
    final earliest = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    await _reload();
  }

  Future<void> _hide(NotificationInboxRow row) async {
    setState(() => _rows = _rows.where((item) => item.id != row.id).toList());
    try {
      await NotificationInboxRepository.hide(row.id);
    } catch (_) {
      if (mounted) _reload();
    }
  }

  Future<void> _clearAll() async {
    setState(() => _rows = []);
    try {
      await NotificationInboxRepository.hideAll();
      await NotificationInboxRepository.refreshBadge();
    } catch (_) {
      if (mounted) _reload();
    }
  }

  Future<void> _openRow(NotificationInboxRow row) async {
    final data = row.data;
    final action = '${data['action'] ?? ''}'.trim();
    final payload = action.isEmpty
        ? NotificationPayload.fromData(data)
        : NotificationPayload(
            raw: data,
            type: '${data['type'] ?? ''}',
            category: '${data['category'] ?? ''}',
            action: action,
            model: '${data['model'] ?? ''}',
            resId: '${data['res_id'] ?? ''}',
            screen: '${data['screen'] ?? ''}',
            params: data['params'] is Map
                ? Map<String, dynamic>.from(data['params'] as Map)
                : const {},
          );
    await NotificationRouter.open(payload);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        HomeNavigation.handleSystemBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8ECF2),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2248),
          foregroundColor: Colors.white,
          title: const Text('Notifications'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => HomeNavigation.handleSystemBack(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Date range',
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
            ),
            TextButton(
              onPressed: _rows.isEmpty ? null : _clearAll,
              child: const Text('Clear All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) {
                        setState(() => _category = null);
                        _reload();
                      },
                    ),
                  ),
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.name),
                        selected: _category == category.code,
                        onSelected: (_) {
                          setState(() => _category = category.code);
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _open, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No notifications'));
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _rows.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _rows.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final row = _rows[index];
        final visual = NotificationCategoryTheme.forKey(row.category);
        return Dismissible(
          key: ValueKey(row.id.isEmpty ? index : row.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _hide(row),
          background: Container(
            color: const Color(0xFFBA1719),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: ListTile(
            tileColor: Colors.white,
            leading: Icon(visual.icon, color: visual.color),
            title: Text(row.title),
            subtitle: Text(row.body),
            onTap: () => _openRow(row),
          ),
        );
      },
    );
  }
}
