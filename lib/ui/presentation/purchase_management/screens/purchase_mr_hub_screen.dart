import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/mr_detail_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hub_list_scaffold.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseMrHubScreen extends StatefulWidget {
  const PurchaseMrHubScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  State<PurchaseMrHubScreen> createState() => _PurchaseMrHubScreenState();
}

class _PurchaseMrHubScreenState extends State<PurchaseMrHubScreen> {
  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  static const _filters = ['PENDING_MRS', ''];
  static const _filterLabels = ['Pending', 'All'];

  List<MrItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  String _statusFilter = 'PENDING_MRS';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final text = _searchController.text.trim();
      if (text == _keyword) return;
      setState(() => _keyword = text);
      _fetchItems();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (_hasMore && !_isLoadingMore && !_isLoading) _loadMore();
    }
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.fetchRequisitions(
        page: 1,
        keyword: _keyword,
        status: _statusFilter,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repo.fetchRequisitions(
        page: _currentPage + 1,
        keyword: _keyword,
        status: _statusFilter,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _currentPage++;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PurchaseHubListScaffold(
      title: 'Material Requests',
      searchController: _searchController,
      filterValues: _filters,
      filterLabels: _filterLabels,
      selectedFilter: _statusFilter,
      onFilterChanged: (f) {
        if (f == _statusFilter) return;
        setState(() => _statusFilter = f);
        _fetchItems();
      },
      itemCount: _items.length,
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      error: _error,
      scrollController: _scrollController,
      onRefresh: _fetchItems,
      itemBuilder: (context, index) {
        final item = _items[index];
        final status = mrStatusFromApi(item.state);
        return PurchaseGlassListCard(
          urgent: item.isUrgent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MrDetailScreen(mrId: item.id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w700,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (item.isUrgent)
                    Container(
                      margin: EdgeInsets.only(right: 8.tw),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.tw,
                        vertical: 3.th,
                      ),
                      decoration: BoxDecoration(
                        gradient: PurchaseTheme.urgentAccentGradient,
                        borderRadius: BorderRadius.circular(8.tr),
                      ),
                      child: Text(
                        'URGENT',
                        style: GoogleFonts.poppins(
                          fontSize: 9.tsp,
                          fontWeight: FontWeight.w700,
                          color: PurchaseTheme.pendingBadge,
                        ),
                      ),
                    ),
                  PurchaseStatusChip(
                    label: status.label,
                    color: status.color,
                  ),
                ],
              ),
              if (item.requester.isNotEmpty) ...[
                SizedBox(height: 8.th),
                Row(
                  children: [
                    PurchaseAvatar(
                      name: item.requester,
                      photoUrl: item.requesterPhoto,
                      radius: 14,
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: Text(
                        item.requester,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5.tsp,
                          color: PurchaseTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.projectManager.isNotEmpty) ...[
                SizedBox(height: 6.th),
                Row(
                  children: [
                    PurchaseAvatar(
                      name: item.projectManager,
                      photoUrl: item.projectManagerPhoto,
                      radius: 14,
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: Text(
                        'PM: ${item.projectManager}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: PurchaseTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.department.isNotEmpty) ...[
                SizedBox(height: 4.th),
                Text(
                  item.department,
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    color: PurchaseTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
