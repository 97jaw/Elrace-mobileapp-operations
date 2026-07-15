import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/invoice_receiving_create_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/invoice_receiving_detail_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/lpo_smart_filter_sheet.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_hub_list_scaffold.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseRfqHubScreen extends ConsumerStatefulWidget {
  const PurchaseRfqHubScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  ConsumerState<PurchaseRfqHubScreen> createState() =>
      _PurchaseRfqHubScreenState();
}

class _PurchaseRfqHubScreenState extends ConsumerState<PurchaseRfqHubScreen> {
  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  int _segment = 0;
  List<RfqItem> _rfqItems = [];
  List<InvoiceReceivingItem> _invoiceItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  String _keyword = '';
  PurchaseListFilters _smartFilters = const PurchaseListFilters();

  bool get _isInvoiceSegment {
    final access = ref.read(purchaseAccessProvider);
    return access.canSeeInvoiceReceiving && _segment == 2;
  }

  List<String> get _segmentLabels {
    final access = ref.read(purchaseAccessProvider);
    if (access.canSeeInvoiceReceiving) {
      return const ['Waiting', 'All RFQs', 'Invoice Receiving'];
    }
    return const ['Waiting', 'All RFQs'];
  }

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

  String get _rfqStatusFilter => _segment == 0 ? 'WAITING_RFQS' : '';

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_isInvoiceSegment) {
        final result = await _repo.fetchInvoiceReceiving(
          page: 1,
          keyword: _keyword,
          testRole: widget.testRole,
        );
        if (!mounted) return;
        setState(() {
          _invoiceItems = result.items;
          _hasMore = result.hasMore;
          _currentPage = 1;
          _isLoading = false;
        });
      } else {
        final result = await _repo.fetchRfqs(
          page: 1,
          keyword: _keyword,
          status: _rfqStatusFilter,
          filters: _smartFilters.isEmpty ? null : _smartFilters,
          testRole: widget.testRole,
        );
        if (!mounted) return;
        setState(() {
          _rfqItems = result.items;
          _hasMore = result.hasMore;
          _currentPage = 1;
          _isLoading = false;
        });
      }
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
      if (_isInvoiceSegment) {
        final result = await _repo.fetchInvoiceReceiving(
          page: _currentPage + 1,
          keyword: _keyword,
          testRole: widget.testRole,
        );
        if (!mounted) return;
        setState(() {
          _invoiceItems.addAll(result.items);
          _hasMore = result.hasMore;
          _currentPage++;
          _isLoadingMore = false;
        });
      } else {
        final result = await _repo.fetchRfqs(
          page: _currentPage + 1,
          keyword: _keyword,
          status: _rfqStatusFilter,
          filters: _smartFilters.isEmpty ? null : _smartFilters,
          testRole: widget.testRole,
        );
        if (!mounted) return;
        setState(() {
          _rfqItems.addAll(result.items);
          _hasMore = result.hasMore;
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSegmentChanged(int index) {
    if (index == _segment) return;
    setState(() => _segment = index);
    _fetchItems();
  }

  Future<void> _openRfq(RfqItem item) async {
    try {
      final url = await _repo.fetchRfqReportUrl(item.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(pdfUrl: url, title: item.name),
        ),
      );
    } on RfqNoAttachmentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open RFQ attachments')),
      );
    }
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
    final access = ref.watch(purchaseAccessProvider);
    final itemCount = _isInvoiceSegment ? _invoiceItems.length : _rfqItems.length;

    return Stack(
      children: [
        PurchaseHubListScaffold(
          title: 'RFQs',
          searchController: _searchController,
          segmentLabels: _segmentLabels,
          selectedSegment: _segment,
          onSegmentChanged: _onSegmentChanged,
          onSmartFilterTap: _isInvoiceSegment ? null : _showFilterSheet,
          smartFilterCount: _isInvoiceSegment ? 0 : _smartFilters.activeCount,
          itemCount: itemCount,
          isLoading: _isLoading,
          isLoadingMore: _isLoadingMore,
          error: _error,
          scrollController: _scrollController,
          onRefresh: _fetchItems,
          itemBuilder: (context, index) {
            if (_isInvoiceSegment) {
              final item = _invoiceItems[index];
              return _InvoiceRow(
                item: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceReceivingDetailScreen(
                      invoiceId: item.id,
                      testRole: widget.testRole,
                    ),
                  ),
                ),
              );
            }
            final item = _rfqItems[index];
            return _RfqRow(item: item, onTap: () => _openRfq(item));
          },
        ),
        if (_isInvoiceSegment && access.canCreateInvoice)
          Positioned(
            right: 16.w,
            bottom: 16.h,
            child: FloatingActionButton.extended(
              backgroundColor: PurchaseTheme.accentBlue,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InvoiceReceivingCreateScreen(testRole: widget.testRole),
                  ),
                );
                if (mounted) _fetchItems();
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Create',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _RfqRow extends StatelessWidget {
  const _RfqRow({required this.item, required this.onTap});
  final RfqItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = rfqStatusFromApi(item.state);
    return PurchaseGlassListCard(
      onTap: onTap,
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
                    color: PurchaseTheme.textMuted,
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
                color: PurchaseTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Row 3: vendor + requested-by
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
                        color: PurchaseTheme.textSecondary,
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
                      color: PurchaseTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ],
          // Row 4: full amount (no K/M abbreviation / whole-number round-off)
          if (item.amountTotal > 0 || item.amountDisplay.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                ApprovalDisplayHelpers.formatAmountWithAed(
                  item.amountTotal > 0 ? item.amountTotal : item.amountDisplay,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: PurchaseTheme.accentDeep,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.item, required this.onTap});
  final InvoiceReceivingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = invoiceStatusFromApi(item.state);
    // Primary sequence is item.name (Odoo sequence like INV/2024/0001);
    // secondary invoice_no shown only when it differs from name.
    final seqLabel = item.name.isNotEmpty ? item.name : item.invoiceNo;
    final showSecondary =
        item.invoiceNo.isNotEmpty && item.invoiceNo != item.name;
    return PurchaseGlassListCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: sequence name | status chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: seqLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: PurchaseTheme.accentDeep,
                        ),
                      ),
                      if (showSecondary)
                        TextSpan(
                          text: '  –  ${item.invoiceNo}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                            color: PurchaseTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PurchaseStatusChip(label: status.label, color: status.color),
            ],
          ),
          // Row 2: partner / vendor
          if (item.partner.isNotEmpty) ...[
            SizedBox(height: 5.h),
            Text(
              'For ${item.partner}',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: PurchaseTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Row 3: invoice_date (left) | amount (right)
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.invoiceDate.isNotEmpty)
                Text(
                  item.invoiceDate,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: PurchaseTheme.textMuted,
                  ),
                ),
              const Spacer(),
              Text(
                item.amount > 0
                    ? ApprovalDisplayHelpers.formatAmountWithAed(item.amount)
                    : ApprovalDisplayHelpers.formatAmountWithAed(
                        item.amountDisplay,
                      ),
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: PurchaseTheme.accentDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
