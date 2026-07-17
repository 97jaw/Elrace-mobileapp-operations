import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/lpo_smart_filter_sheet.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hub_list_scaffold.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseLpoHubScreen extends StatefulWidget {
  const PurchaseLpoHubScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  State<PurchaseLpoHubScreen> createState() => _PurchaseLpoHubScreenState();
}

class _PurchaseLpoHubScreenState extends State<PurchaseLpoHubScreen> {
  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Backend: empty status returns RFQs too — LPOS = purchase + done only.
  static const _filters = ['LPOS', 'LPO_OPEN', 'LPO_CLOSED'];
  static const _filterLabels = ['All', 'Open', 'Closed'];

  List<RfqItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  String _statusFilter = 'LPOS';
  PurchaseListFilters _smartFilters = const PurchaseListFilters();

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
      final result = await _repo.fetchRfqs(
        page: 1,
        keyword: _keyword,
        status: _statusFilter,
        orderDesc: true,
        filters: _smartFilters.isEmpty ? null : _smartFilters,
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
      final result = await _repo.fetchRfqs(
        page: _currentPage + 1,
        keyword: _keyword,
        status: _statusFilter,
        orderDesc: true,
        filters: _smartFilters.isEmpty ? null : _smartFilters,
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

  Future<void> _openItem(RfqItem item) async {
    try {
      final url = await _repo.fetchPoReportUrl(item.id);
      if (url != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LpoPdfViewerScreen(pdfUrl: url, title: item.name),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _showFilterSheet() async {
    final result = await LpoSmartFilterSheet.show(
      context: context,
      initial: _smartFilters,
      repository: _repo,
      testRole: widget.testRole,
    );
    if (result == null) return;
    setState(() => _smartFilters = result);
    _fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    final smartCount = _smartFilters.activeCount;

    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PurchaseManagementGlassHeader(
              bottom: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(4.tw, 0, 14.tw, 2.th),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18.tsp,
                            color: PurchaseTheme.accentDeep,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 36.tw,
                            minHeight: 36.tw,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 38.th,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(20.tr),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.poppins(
                                color: PurchaseTheme.textPrimary,
                                fontSize: 13.tsp,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search LPOs…',
                                hintStyle: GoogleFonts.poppins(
                                  color: PurchaseTheme.textMuted,
                                  fontSize: 13.tsp,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18.tsp,
                                  color: PurchaseTheme.accentBlue,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8.th,
                                  horizontal: 10.tw,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.tw),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: _showFilterSheet,
                              child: Container(
                                width: 38.tw,
                                height: 38.tw,
                                decoration: BoxDecoration(
                                  color: smartCount > 0
                                      ? PurchaseTheme.accentBlue
                                      : Colors.white.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: PurchaseTheme.accentBlue
                                          .withValues(alpha: 0.12),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 18.tsp,
                                  color: smartCount > 0
                                      ? Colors.white
                                      : PurchaseTheme.accentDeep,
                                ),
                              ),
                            ),
                            if (smartCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.tw,
                                    vertical: 2.th,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PurchaseTheme.accentDeep,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '$smartCount',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8.tsp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PurchaseFilterChips(
                    dense: true,
                    filters: _filters,
                    labels: _filterLabels,
                    selected: _statusFilter,
                    onSelect: (f) {
                      if (f == _statusFilter) return;
                      setState(() => _statusFilter = f);
                      _fetchItems();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
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
        child: Text(
          _error!,
          style: GoogleFonts.poppins(
              color: PurchaseTheme.textPrimary, fontSize: 13.tsp),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No LPOs found',
          style: GoogleFonts.poppins(
              color: PurchaseTheme.textMuted, fontSize: 14.tsp),
        ),
      );
    }
    return RefreshIndicator(
      color: PurchaseTheme.accentBlue,
      onRefresh: _fetchItems,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: PurchaseTheme.accentBlue)),
            );
          }
          final item = _items[index];
          return PurchaseGlassListCard(
            onTap: () => _openItem(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: reference | date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w600,
                          color: PurchaseTheme.accentDeep,
                        ),
                      ),
                    ),
                    if (item.dateOrder.isNotEmpty) ...[
                      SizedBox(width: 6.tw),
                      Text(
                        item.dateOrder,
                        style: GoogleFonts.poppins(
                          fontSize: 10.tsp,
                          color: PurchaseTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                // Row 2: project title
                if (item.project.isNotEmpty) ...[
                  SizedBox(height: 6.th),
                  Text(
                    item.project,
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w700,
                      color: PurchaseTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Row 3: vendor
                if (item.vendorName.isNotEmpty) ...[
                  SizedBox(height: 4.th),
                  Text(
                    'For ${item.vendorName}',
                    style: GoogleFonts.poppins(
                      fontSize: 11.tsp,
                      color: PurchaseTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Row 4: amount right-aligned
                if (item.amountTotal > 0) ...[
                  SizedBox(height: 8.th),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      ApprovalDisplayHelpers.formatAmountWithAed(
                        item.amountTotal,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 17.tsp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE8694D),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
