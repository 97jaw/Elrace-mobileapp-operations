import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/mr_detail_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hub_list_scaffold.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// Material Requisition list — infinite scroll, debounced search, status filter.
class MrListScreen extends StatefulWidget {
  const MrListScreen({
    super.key,
    this.testRole,
    this.initialStatusFilter = '',
    this.title = 'Material Requisitions',
    this.lockStatusFilter = false,
  });

  final PurchaseDevTestRole? testRole;
  final String initialStatusFilter;
  final String title;
  final bool lockStatusFilter;

  @override
  State<MrListScreen> createState() => _MrListScreenState();
}

class _MrListScreenState extends State<MrListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<MrItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  String _statusFilter = '';

  static const _statusFilters = [
    '',
    'NEW',
    'WAITING DEPT APPROVAL',
    'WAITING IR APPROVAL',
    'APPROVED',
    'RFQ CREATED',
    'RECEIVED',
    'REJECTED',
  ];

  static const _filterLabels = [
    'All',
    'New',
    'Dept Approval',
    'IR Approval',
    'Approved',
    'RFQ Created',
    'Received',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchItems();
  }

  @override
  void didUpdateWidget(covariant MrListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.testRole != widget.testRole) {
      _fetchItems();
    }
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
      _fetchItems(keyword: text);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (_hasMore && !_isLoadingMore && !_isLoading) _loadMore();
    }
  }

  Future<void> _fetchItems({String? keyword, String? status}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.fetchRequisitions(
        page: 1,
        keyword: keyword ?? _keyword,
        status: status ?? _statusFilter,
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

  void _applyStatusFilter(String filter) {
    if (filter == _statusFilter) return;
    setState(() => _statusFilter = filter);
    _fetchItems(status: filter);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
        children: [
          PurchaseManagementGlassHeader(
            title: widget.title,
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                PurchaseSearchBar(controller: _searchController),
                if (!widget.lockStatusFilter)
                  PurchaseFilterChips(
                    filters: _statusFilters,
                    labels: _filterLabels,
                    selected: _statusFilter,
                    onSelect: _applyStatusFilter,
                  ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: PurchaseTheme.accentBlue));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.sp)),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate('home.purchase.no_records'),
          style: GoogleFonts.poppins(color: PurchaseTheme.textMuted, fontSize: 14.sp),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7DB3E8))),
          );
        }
        return _MrCard(
          item: _items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MrDetailScreen(mrId: _items[index].id),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// MR card
// ---------------------------------------------------------------------------

class _MrCard extends StatelessWidget {
  const _MrCard({required this.item, required this.onTap});

  final MrItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = mrStatusFromApi(item.state);
    return PurchaseGlassListCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.textPrimary,
                  ),
                ),
              ),
              PurchaseStatusChip(label: status.label, color: status.color),
            ],
          ),
          SizedBox(height: 6.h),
          if (item.woPo.isNotEmpty)
            _InfoRow(icon: Icons.work_outline, text: item.woPo),
          if (item.requester.isNotEmpty)
            Row(
              children: [
                PurchaseAvatar(
                  name: item.requester,
                  photoUrl: item.requesterPhoto,
                  radius: 12,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _InfoRow(icon: Icons.person_outline, text: item.requester),
                ),
              ],
            ),
          if (item.department.isNotEmpty)
            _InfoRow(icon: Icons.apartment_outlined, text: item.department),
          if (item.requestDate.isNotEmpty)
            _InfoRow(
                icon: Icons.calendar_today_outlined, text: item.requestDate),
          if (item.projectManager.isNotEmpty)
            Row(
              children: [
                PurchaseAvatar(
                  name: item.projectManager,
                  photoUrl: item.projectManagerPhoto,
                  radius: 12,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.manage_accounts_outlined,
                    text: item.projectManager,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 12.sp, color: PurchaseTheme.textMuted),
          SizedBox(width: 5.w),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.5.sp,
                color: PurchaseTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared search bar
