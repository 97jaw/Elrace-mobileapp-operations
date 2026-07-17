import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/providers/global_search_provider.dart';
import 'package:el_race/utils/global_search_navigation_helper.dart';
import 'package:el_race/data/services/global_search_history_service.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/widgets/global_search_category_screen.dart';
import 'package:el_race/ui/widgets/global_search_header.dart';
import 'package:el_race/ui/widgets/global_search_item_builder.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// Global Search Screen — unified search across all ERP domains.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final GlobalSearchItemBuilder _itemBuilder;

  @override
  void initState() {
    super.initState();
    _itemBuilder = GlobalSearchItemBuilder(
      onTap: _navigateToDetail,
      highlight: _buildHighlightedText,
    );
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GlobalSearchProvider>();
      provider.clearResults();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        HomeNavigation.handleSystemBack(context);
      },
      child: Consumer<GlobalSearchProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: GlobalSearchTheme.screenBase,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ChatUnifiedHeaderBackdrop.layer(),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlobalSearchHeader(
                      searchController: _searchController,
                      onSearchChanged: (value) {
                        provider.search(keyword: value);
                      },
                      onSearchClear: () {
                        _searchController.clear();
                        provider.clearResults();
                      },
                    ),
                    Expanded(child: _buildSearchResults()),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applySuggestion(String query) async {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    final provider = context.read<GlobalSearchProvider>();
    await provider.searchImmediate(keyword: query);
  }

  Widget _glassSuggestionChip(
    String label,
    Future<void> Function(String) onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(20.tr),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20.tr),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsPanel() {
    final recent = GlobalSearchHistoryService.getRecent();
    final shortcuts = GlobalSearchHistoryService.getShortcuts();
    final queryLen = _searchController.text.trim().length;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
      children: [
        if (queryLen > 0 && queryLen < 2)
          Padding(
            padding: EdgeInsets.only(bottom: 12.th),
            child: Text(
              translate('search.min_chars_hint'),
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: GlobalSearchTheme.onGlassMuted,
              ),
            ),
          ),
        if (recent.isNotEmpty) ...[
          Text(
            translate('search.recent'),
            style: GoogleFonts.poppins(
              fontSize: 14.tsp,
              fontWeight: FontWeight.w600,
              color: GlobalSearchTheme.sectionHeader,
            ),
          ),
          SizedBox(height: 8.th),
          Wrap(
            spacing: 8.tw,
            runSpacing: 8.th,
            children: recent
                .map((q) => _glassSuggestionChip(q, _applySuggestion))
                .toList(),
          ),
          SizedBox(height: 16.th),
        ],
        Text(
          translate('search.suggestions'),
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            fontWeight: FontWeight.w600,
            color: GlobalSearchTheme.sectionHeader,
          ),
        ),
        SizedBox(height: 8.th),
        Wrap(
          spacing: 8.tw,
          runSpacing: 8.th,
          children: shortcuts
              .map((q) => _glassSuggestionChip(q, _applySuggestion))
              .toList(),
        ),
        if (recent.isEmpty && queryLen == 0) ...[
          SizedBox(height: 24.th),
          Center(
            child: Icon(
              Icons.search_rounded,
              size: 64.tsp,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          SizedBox(height: 12.th),
          Center(
            child: Text(
              translate('search.empty_hint'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: GlobalSearchTheme.onGlassMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build search results based on state
  Widget _buildSearchResults() {
    return Consumer<GlobalSearchProvider>(
      builder: (context, provider, _) {
        if (provider.state == GlobalSearchState.idle) {
          return _buildSuggestionsPanel();
        }

        // Loading state - Show skeleton loaders
        if (provider.isLoading) {
          return _buildSkeletonLoader();
        }

        // Error state
        if (provider.hasError) {
          return _buildErrorState(
            message: provider.errorMessage ?? 'An error occurred',
            onRetry: () => provider.retry(),
          );
        }

        // Empty state
        if (provider.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: translate('search.no_results'),
            message: translate(
              'search.no_results_for',
              args: {'keyword': provider.currentKeyword},
            ),
          );
        }

        // Grouped results by category
        return _buildGroupedResults(provider);
      },
    );
  }

  Widget _buildGroupedResults(GlobalSearchProvider provider) {
    final sections = provider.sections;
    final keyword = provider.currentKeyword;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 4.th, 0, 24.th),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildHorizontalSection(
          provider: provider,
          section: section,
          keyword: keyword,
        );
      },
    );
  }

  void _openCategoryList(GlobalSearchSection section, String keyword) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlobalSearchCategoryScreen(
          category: section.category,
          categoryTitle: section.title,
          keyword: keyword,
        ),
      ),
    );
  }

  Widget _buildHorizontalSection({
    required GlobalSearchProvider provider,
    required GlobalSearchSection section,
    required String keyword,
  }) {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.78;
    const rowHeight = 108.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          section.title,
          onSeeMore: section.items.isNotEmpty
              ? () => _openCategoryList(section, keyword)
              : null,
        ),
        SizedBox(
          height: rowHeight.th,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 14.tw),
            physics: const BouncingScrollPhysics(),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: cardWidth,
                height: rowHeight.th,
                child: _itemBuilder.buildCard(
                  section.items[index],
                  keyword,
                  compact: true,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 10.th),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeMore}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.tw, 14.th, 14.tw, 6.th),
      child: Row(
        children: [
          Container(
            width: 3.tw,
            height: 14.th,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2.tr),
            ),
          ),
          SizedBox(width: 8.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: GlobalSearchTheme.sectionHeader,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.tw),
                minimumSize: Size(0, 32.th),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                translate('search.view_all'),
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w600,
                  color: GlobalSearchTheme.greenBright,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 4.th, 0, 24.th),
      itemCount: 5,
      itemBuilder: (context, index) => _buildGenericSkeleton(),
    );
  }

  Widget _buildGlassRowSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 5.th),
      child: Container(
        height: 96.th,
        padding: EdgeInsets.all(12.tw),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.tr),
          color: GlobalSearchTheme.white.withValues(alpha: 0.2),
          border: Border.all(
            color: GlobalSearchTheme.greyLight.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            _buildShimmerBox(width: 44.tw, height: 44.tw),
            SizedBox(width: 12.tw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildShimmerBox(width: double.infinity, height: 13.th),
                  SizedBox(height: 8.th),
                  _buildShimmerBox(width: 160.tw, height: 10.th),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericSkeleton() => _buildGlassRowSkeleton();

  /// Shimmer box widget
  Widget _buildShimmerBox({
    required double width,
    required double height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(isCircle ? 22.tr : 4.tr),
        shape: BoxShape.rectangle,
      ),
    );
  }


  /// Build highlighted text with keyword emphasis
  Widget _buildHighlightedText(
    String text,
    String keyword, {
    required TextStyle style,
  }) {
    if (keyword.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int indexOfKeyword;

    while ((indexOfKeyword = lowerText.indexOf(lowerKeyword, start)) != -1) {
      // Add text before keyword
      if (indexOfKeyword > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfKeyword)));
      }

      // Add highlighted keyword
      spans.add(TextSpan(
        text: text.substring(indexOfKeyword, indexOfKeyword + keyword.length),
        style: style.copyWith(
          backgroundColor: GlobalSearchTheme.maroon.withValues(alpha: 0.85),
          color: GlobalSearchTheme.white,
          fontWeight: FontWeight.w700,
        ),
      ));

      start = indexOfKeyword + keyword.length;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Empty state widget
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.tw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80.tsp,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.th),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18.tsp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: GlobalSearchTheme.onGlassMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state widget with retry
  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.tw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80.tsp,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            SizedBox(height: 16.th),
            Text(
              translate('search.error'),
              style: GoogleFonts.poppins(
                fontSize: 18.tsp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: GlobalSearchTheme.onGlassMuted,
              ),
            ),
            SizedBox(height: 24.th),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(translate('search.retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: GlobalSearchTheme.screenBase,
                padding: EdgeInsets.symmetric(horizontal: 24.tw, vertical: 12.th),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(GlobalSearchItem item) {
    if (item.category == 'my_actions') {
      GlobalSearchNavigationHelper.navigateToMyAction(context, item);
      return;
    }
    GlobalSearchNavigationHelper.navigateToDetail(context, item);
  }
}
