import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// RFQ / Local Purchase Order list — paginated, searchable, status-filtered.
/// Tapping a card either opens the PDF (if PO state = Purchase Order) or
/// pushes an RFQ detail screen (read-only, reusing get_rfq_details).
class RfqListScreen extends StatefulWidget {
  const RfqListScreen({
    super.key,
    this.testRole,
    this.initialStatusFilter = '',
    this.title = 'RFQ / LPO',
    this.lockStatusFilter = false,
  });

  final PurchaseDevTestRole? testRole;
  final String initialStatusFilter;
  final String title;
  final bool lockStatusFilter;

  @override
  State<RfqListScreen> createState() => _RfqListScreenState();
}

class _RfqListScreenState extends State<RfqListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<RfqItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  String _statusFilter = '';

  static const _statusFilters = [
    '',
    'RFQ',
    'RFQ SENT',
    'WAITING APPROVAL',
    'PURCHASE ORDER',
    'RECEIVED',
    'CANCELLED',
  ];

  static const _filterLabels = [
    'All',
    'RFQ',
    'RFQ Sent',
    'Waiting',
    'PO',
    'Received',
    'Cancelled',
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
  void didUpdateWidget(covariant RfqListScreen oldWidget) {
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
      final result = await _repo.fetchRfqs(
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
      final result = await _repo.fetchRfqs(
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

  Future<void> _openItem(RfqItem item) async {
    // For all states: try to open the PDF via po/report_url.
    // Fall back gracefully if no PDF is available.
    try {
      final url = await _repo.fetchPoReportUrl(item.id);
      if (url != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LpoPdfViewerScreen(
              pdfUrl: url,
              title: item.name,
            ),
          ),
        );
        return;
      }
    } catch (_) {}
    // No PDF — show a simple read-only card
    if (mounted) _showRfqQuickView(item);
  }

  void _showRfqQuickView(RfqItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RfqQuickViewSheet(item: item),
    );
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
          child: CircularProgressIndicator(color: Color(0xFF7DB3E8)));
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
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14.sp),
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
                child: CircularProgressIndicator(
                    color: Color(0xFF7DB3E8))),
          );
        }
        return _RfqCard(
          item: _items[index],
          onTap: () => _openItem(_items[index]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// RFQ card — mirrors the existing LpoCardWidget design
// ---------------------------------------------------------------------------

class _RfqCard extends StatelessWidget {
  const _RfqCard({required this.item, required this.onTap});

  final RfqItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = rfqStatusFromApi(item.state);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: reference | date | status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7DB3E8),
                    ),
                  ),
                ),
                if (item.dateOrder.isNotEmpty) ...[
                  SizedBox(width: 6.w),
                  Text(
                    item.dateOrder,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                PurchaseStatusChip(label: status.label, color: status.color),
              ],
            ),
            // Row 2: project / title
            if (item.project.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                item.project,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Row 3: "For [vendor]" + requested-by
            if (item.vendorName.isNotEmpty || item.requestedBy.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  if (item.vendorName.isNotEmpty)
                    Expanded(
                      child: Text(
                        'For ${item.vendorName}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.requestedBy.isNotEmpty)
                    Text(
                      item.requestedBy,
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
            ],
            // Row 4: amount right-aligned
            if (item.amountDisplay.isNotEmpty || item.amountTotal > 0) ...[
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  item.amountDisplay.isNotEmpty
                      ? item.amountDisplay
                      : 'AED ${item.amountTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE8694D),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-view bottom sheet (shown when PDF is unavailable)
// ---------------------------------------------------------------------------

class _RfqQuickViewSheet extends StatelessWidget {
  const _RfqQuickViewSheet({required this.item});
  final RfqItem item;

  @override
  Widget build(BuildContext context) {
    final status = rfqStatusFromApi(item.state);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D2D6),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E2A4A),
                    ),
                  ),
                ),
                PurchaseStatusChip(
                    label: status.label, color: status.color),
              ],
            ),
            SizedBox(height: 14.h),
            _SheetRow(label: 'Vendor', value: item.vendorName),
            _SheetRow(label: 'Project', value: item.project),
            _SheetRow(label: 'Department', value: item.department),
            _SheetRow(label: 'Requested By', value: item.requestedBy),
            _SheetRow(label: 'Date', value: item.dateOrder),
            _SheetRow(label: 'Currency', value: item.currency),
            if (item.amountTotal > 0)
              _SheetRow(
                label: 'Amount',
                value: item.amountDisplay.isNotEmpty
                    ? item.amountDisplay
                    : 'AED ${item.amountTotal.toStringAsFixed(2)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A9BB5))),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E2A4A))),
          ),
        ],
      ),
    );
  }
}
