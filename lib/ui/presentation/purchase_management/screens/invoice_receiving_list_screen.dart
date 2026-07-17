import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/invoice_receiving_create_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/invoice_receiving_detail_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'dart:async';

class InvoiceReceivingListScreen extends ConsumerStatefulWidget {
  const InvoiceReceivingListScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  ConsumerState<InvoiceReceivingListScreen> createState() =>
      _InvoiceReceivingListScreenState();
}

class _InvoiceReceivingListScreenState
    extends ConsumerState<InvoiceReceivingListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<InvoiceReceivingItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  String _statusFilter = '';

  static const _statusFilters = ['', 'CONFIRMED'];
  static const _filterLabels = ['All', 'Received'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchItems();
  }

  @override
  void didUpdateWidget(covariant InvoiceReceivingListScreen oldWidget) {
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
      final result = await _repo.fetchInvoiceReceiving(
        page: 1,
        keyword: keyword ?? _keyword,
        status: status ?? _statusFilter,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items.where((e) => !e.isDraft).toList();
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
      final result = await _repo.fetchInvoiceReceiving(
        page: _currentPage + 1,
        keyword: _keyword,
        status: _statusFilter,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items.where((e) => !e.isDraft));
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

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceReceivingCreateScreen(testRole: widget.testRole),
      ),
    );
    if (created == true) _fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final access = ref.watch(purchaseAccessProvider);

    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
        children: [
          PurchaseManagementGlassHeader(
            title: 'Invoice Receiving',
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    PurchaseSearchBar(controller: _searchController),
                    PurchaseFilterChips(
                      filters: _statusFilters,
                      labels: _filterLabels,
                      selected: _statusFilter,
                      onSelect: _applyStatusFilter,
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
                if (access.canCreateInvoice)
                  Positioned(
                    right: 16.tw,
                    bottom: 16.th,
                    child: FloatingActionButton.extended(
                      onPressed: _openCreate,
                      backgroundColor: PurchaseTheme.accentBlue,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        'Create',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.tsp)),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate('home.purchase.no_records'),
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14.tsp),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: 72.th),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7DB3E8))),
          );
        }
        return _InvoiceReceivingRow(
          item: _items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceReceivingDetailScreen(
                invoiceId: _items[index].id,
                testRole: widget.testRole,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceReceivingRow extends StatelessWidget {
  const _InvoiceReceivingRow({required this.item, required this.onTap});

  final InvoiceReceivingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = invoiceStatusFromApi(item.state);
    // Display name: prefer the Odoo sequence name, fall back to invoiceNo.
    final displayName = item.name.isNotEmpty ? item.name : item.invoiceNo;
    final hasSecondaryNo = item.name.isNotEmpty && item.invoiceNo.isNotEmpty && item.name != item.invoiceNo;
    final amountText = item.amountDisplay.isNotEmpty
        ? item.amountDisplay
        : (item.amount > 0 ? '${item.currency} ${item.amount.toStringAsFixed(2)}' : '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 6.th),
        padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14.tr),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: name + secondary invoice_no + status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (hasSecondaryNo)
                        Text(
                          '- ${item.invoiceNo}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.tsp,
                            color: Colors.white54,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8.tw),
                PurchaseStatusChip(label: status.label, color: status.color),
              ],
            ),
            // Row 2: partner name
            if (item.partner.isNotEmpty) ...[
              SizedBox(height: 6.th),
              Text(
                'For ${item.partner}',
                style: GoogleFonts.poppins(
                  fontSize: 11.tsp,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Row 3: invoice date (left) + amount (right)
            SizedBox(height: 8.th),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.invoiceDate.isNotEmpty)
                  Text(
                    item.invoiceDate,
                    style: GoogleFonts.poppins(
                      fontSize: 11.tsp,
                      color: Colors.white54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const Spacer(),
                if (amountText.isNotEmpty)
                  Text(
                    amountText,
                    style: GoogleFonts.poppins(
                      fontSize: 16.tsp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE8694D),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
