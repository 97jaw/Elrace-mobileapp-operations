import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_invoice_detail_sheet.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_list_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// Full list of vendor bills (all states) under Purchase Management.
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

  @override
  void initState() {
    super.initState();
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

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - 240) {
      _loadMore();
    }
    return false;
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.fetchInvoices(
        page: 1,
        limit: 15,
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
      if (kDebugMode) {
        debugPrint(
          'invoices list: page=1 count=${_items.length} '
          'total=$_total hasMore=$_hasMore',
        );
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
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    try {
      final result = await _repo.fetchInvoices(
        page: nextPage,
        limit: 15,
        keyword: _keyword,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        if (result.items.isEmpty) {
          _hasMore = false;
        } else {
          // Deduplicate in case API returns overlapping pages.
          final existing = _items.map((e) => e.id).toSet();
          _items.addAll(result.items.where((e) => !existing.contains(e.id)));
          _hasMore = result.hasMore;
          _currentPage = nextPage;
          if (result.total > 0) _total = result.total;
        }
        _isLoadingMore = false;
      });
      if (kDebugMode) {
        debugPrint(
          'invoices list: page=$nextPage got=${result.items.length} '
          'totalLoaded=${_items.length} hasMore=$_hasMore',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      if (kDebugMode) {
        debugPrint('invoices loadMore failed: $e');
      }
    }
  }

  void _openDetail(DraftInvoiceItem item) {
    showPurchaseInvoiceDetailSheet(
      context,
      invoiceId: item.id,
      preview: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            PurchaseManagementGlassHeader(
              title: 'Invoices',
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
                  if (_total > 0 || _items.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 8.th),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _total > 0
                              ? 'Showing ${_items.length} of $_total invoices'
                              : '${_items.length} invoices'
                                  '${_hasMore ? ' (scroll for more)' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            color: PurchaseTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 12.tw),
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
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.tsp),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate('home.purchase.no_records'),
          style: GoogleFonts.poppins(
            color: PurchaseTheme.textMuted,
            fontSize: 14.tsp,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: RefreshIndicator(
        color: PurchaseTheme.accentBlue,
        onRefresh: _fetchItems,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          // Keep a footer while more pages exist so load-more is triggered
          // when that row is built (more reliable than scroll metrics alone).
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadMore();
              });
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.th),
                child: const Center(
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
              onTap: () => _openDetail(item),
            );
          },
        ),
      ),
    );
  }
}
