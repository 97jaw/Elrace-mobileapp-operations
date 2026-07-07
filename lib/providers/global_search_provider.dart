import 'dart:async';

import 'package:dio/dio.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/data/services/global_search_api_service.dart';
import 'package:el_race/data/services/global_search_history_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_translate/flutter_translate.dart';

enum GlobalSearchState {
  idle,
  loading,
  loaded,
  empty,
  error,
}

/// One result group in stable display order.
class GlobalSearchSection {
  const GlobalSearchSection({
    required this.category,
    required this.title,
    required this.items,
  });

  final String category;
  final String title;
  final List<GlobalSearchItem> items;
}

class GlobalSearchProvider extends ChangeNotifier {
  GlobalSearchProvider({GlobalSearchApiService? apiService})
      : _apiService = apiService ?? GlobalSearchApiService();

  final GlobalSearchApiService _apiService;

  static const List<String> sectionOrder = [
    'lpo',
    'petty_cash',
    'projects',
    'my_actions',
    'notes',
    'documents',
    'tasks',
  ];

  GlobalSearchState _state = GlobalSearchState.idle;
  GlobalSearchState get state => _state;

  List<GlobalSearchItem> _results = [];
  List<GlobalSearchItem> get results => _results;

  Map<String, int> _countsByCategory = {};
  Map<String, int> get countsByCategory => _countsByCategory;

  int _limitPerCategory = 5;
  String? _loadingMoreCategory;

  List<GlobalSearchSection> get sections => _buildSections(_results);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _currentKeyword = '';
  String get currentKeyword => _currentKeyword;

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  bool _isDisposed = false;
  int _searchGeneration = 0;
  CancelToken? _cancelToken;

  void search({
    required String keyword,
    int limitPerCategory = 5,
  }) {
    _debounceTimer?.cancel();

    if (keyword.trim().isEmpty) {
      _clearResults();
      return;
    }

    if (keyword.trim().length < 2) {
      _clearResults();
      return;
    }

    _currentKeyword = keyword;
    _setState(GlobalSearchState.loading);

    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(keyword: keyword, limitPerCategory: limitPerCategory);
    });
  }

  Future<void> searchImmediate({
    required String keyword,
    int limitPerCategory = 5,
  }) async {
    _debounceTimer?.cancel();

    if (keyword.trim().isEmpty) {
      _clearResults();
      return;
    }

    _currentKeyword = keyword;

    await _performSearch(
      keyword: keyword,
      limitPerCategory: limitPerCategory,
    );
  }

  Future<void> _performSearch({
    required String keyword,
    int limitPerCategory = 5,
  }) async {
    if (_isDisposed) return;

    final generation = ++_searchGeneration;
    _cancelToken?.cancel('superseded');
    _cancelToken = _apiService.createCancelToken();

    try {
      _setState(GlobalSearchState.loading);
      _errorMessage = null;

      final page = await _apiService.globalSearchAll(
        keyword: keyword,
        limitPerCategory: limitPerCategory,
        cancelToken: _cancelToken,
      );

      if (_isDisposed || generation != _searchGeneration) return;

      _results = page.items;
      _countsByCategory = page.countsByCategory;
      _limitPerCategory = page.limitPerCategory;

      if (page.items.isEmpty) {
        _setState(GlobalSearchState.empty);
      } else {
        _setState(GlobalSearchState.loaded);
        await GlobalSearchHistoryService.addQuery(keyword);
      }
    } on GlobalSearchApiException catch (e) {
      if (_isDisposed || generation != _searchGeneration) return;
      if (e.message == 'Search cancelled') return;
      _errorMessage = e.message;
      _results = [];
      _setState(GlobalSearchState.error);
    } catch (e) {
      if (_isDisposed || generation != _searchGeneration) return;
      _errorMessage = 'An unexpected error occurred';
      _results = [];
      _setState(GlobalSearchState.error);
      if (kDebugMode) {
        debugPrint('GlobalSearchProvider error: $e');
      }
    }
  }

  List<GlobalSearchSection> _buildSections(List<GlobalSearchItem> items) {
    final grouped = <String, List<GlobalSearchItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final sections = <GlobalSearchSection>[];
    for (final cat in sectionOrder) {
      final list = grouped[cat];
      if (list == null || list.isEmpty) continue;
      sections.add(GlobalSearchSection(
        category: cat,
        title: _sectionTitle(cat),
        items: list,
      ));
    }

    for (final entry in grouped.entries) {
      if (sectionOrder.contains(entry.key)) continue;
      sections.add(GlobalSearchSection(
        category: entry.key,
        title: entry.key,
        items: entry.value,
      ));
    }
    return sections;
  }

  String _sectionTitle(String category) {
    switch (category) {
      case 'lpo':
        return translate('search.category_lpo');
      case 'petty_cash':
        return translate('search.category_petty_cash');
      case 'projects':
        return translate('search.category_projects');
      case 'my_actions':
        return translate('search.category_my_actions');
      case 'notes':
        return translate('search.category_notes');
      case 'documents':
        return translate('search.category_documents');
      case 'tasks':
        return translate('search.category_tasks');
      default:
        return category;
    }
  }

  Future<void> retry() async {
    if (_currentKeyword.isNotEmpty) {
      await searchImmediate(keyword: _currentKeyword);
    }
  }

  void clearResults() {
    _clearResults();
  }

  /// True when ERP reports more rows for [category] than currently shown.
  bool hasMoreInCategory(String category) {
    final shown = _results.where((e) => e.category == category).length;
    final total = _countsByCategory[category];
    if (total != null && total > 0) {
      return shown < total;
    }
    return shown >= _limitPerCategory && shown > 0;
  }

  bool isLoadingMoreCategory(String category) =>
      _loadingMoreCategory == category;

  /// Loads full category list for the "See more" screen (up to 50 rows).
  Future<List<GlobalSearchItem>> fetchCategoryList({
    required String category,
    required String keyword,
  }) async {
    final page = await _apiService.globalSearchCategory(
      category: category,
      keyword: keyword,
      limit: 50,
      cancelToken: _cancelToken,
    );
    return page.items;
  }

  /// Fetches up to 50 rows for one category and merges into results.
  Future<void> loadMoreForCategory(String category) async {
    if (_currentKeyword.trim().isEmpty) return;
    if (_loadingMoreCategory != null) return;
    if (!hasMoreInCategory(category)) return;

    _loadingMoreCategory = category;
    notifyListeners();

    try {
      final total = _countsByCategory[category];
      final limit = total != null && total > 0 ? total.clamp(1, 50) : 50;

      final page = await _apiService.globalSearchCategory(
        category: category,
        keyword: _currentKeyword,
        limit: limit,
        cancelToken: _cancelToken,
      );

      if (_isDisposed) return;

      _results = [
        ..._results.where((e) => e.category != category),
        ...page.items,
      ];

      if (page.countsByCategory.isNotEmpty) {
        _countsByCategory = {..._countsByCategory, ...page.countsByCategory};
      } else if (total != null) {
        _countsByCategory[category] = page.items.length;
      }

      _setState(
        _results.isEmpty ? GlobalSearchState.empty : GlobalSearchState.loaded,
      );
    } on GlobalSearchApiException catch (e) {
      if (e.message == 'Search cancelled') return;
      _errorMessage = e.message;
      _setState(GlobalSearchState.error);
    } catch (_) {
      _errorMessage = 'An unexpected error occurred';
      _setState(GlobalSearchState.error);
    } finally {
      _loadingMoreCategory = null;
      if (!_isDisposed) notifyListeners();
    }
  }

  void _clearResults() {
    _debounceTimer?.cancel();
    _searchGeneration++;
    _cancelToken?.cancel('cleared');
    _cancelToken = null;
    _results = [];
    _countsByCategory = {};
    _limitPerCategory = 5;
    _loadingMoreCategory = null;
    _errorMessage = null;
    _currentKeyword = '';
    _setState(GlobalSearchState.idle);
  }

  void _setState(GlobalSearchState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  bool get isLoading => _state == GlobalSearchState.loading;
  bool get hasResults => _results.isNotEmpty;
  bool get hasError => _state == GlobalSearchState.error;
  bool get isEmpty => _state == GlobalSearchState.empty;

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _apiService.cancelRequests();
    _cancelToken?.cancel('disposed');
    super.dispose();
  }
}
