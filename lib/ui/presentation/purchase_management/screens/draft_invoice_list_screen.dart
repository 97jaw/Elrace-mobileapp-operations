import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

class DraftInvoiceListScreen extends StatefulWidget {
  const DraftInvoiceListScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  State<DraftInvoiceListScreen> createState() => _DraftInvoiceListScreenState();
}

class _DraftInvoiceListScreenState extends State<DraftInvoiceListScreen> {
  final _repo = PurchaseRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<DraftInvoiceItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;
  int _total = 0;
  String _keyword = '';
  int? _selectedId;

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
      final result = await _repo.fetchDraftInvoices(
        page: 1,
        keyword: _keyword,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _total = result.total;
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
      final result = await _repo.fetchDraftInvoices(
        page: _currentPage + 1,
        keyword: _keyword,
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
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            PurchaseManagementGlassHeader(
              title: 'Draft Purchase Invoices',
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  PurchaseSearchBar(
                    controller: _searchController,
                    hint: 'Search vendor or invoice…',
                  ),
                  if (_total > 0)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$_total pending drafts',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: PurchaseTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: PurchaseTheme.glassPanel(),
                      clipBehavior: Clip.antiAlias,
                      child: _buildBody(),
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
        child: CircularProgressIndicator(color: PurchaseTheme.accentBlue),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.sp),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate('home.purchase.no_records'),
          style: GoogleFonts.poppins(
            color: PurchaseTheme.textMuted,
            fontSize: 14.sp,
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: PurchaseTheme.accentBlue,
      onRefresh: _fetchItems,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: PurchaseTheme.accentBlue,
                ),
              ),
            );
          }
          final item = _items[index];
          return PurchaseDraftInvoiceRow(
            item: item,
            compact: true,
            selected: _selectedId == item.id,
            onTap: () => setState(() => _selectedId = item.id),
          );
        },
      ),
    );
  }
}
