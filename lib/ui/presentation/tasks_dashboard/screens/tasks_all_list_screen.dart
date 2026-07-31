import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_widgets.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_task_sober_card.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Full paginated Task Management listing with filters + search.
class TasksAllListScreen extends StatefulWidget {
  const TasksAllListScreen({
    super.key,
    this.initialFilter = TaskFilter.all,
    this.embedded = false,
  });

  final TaskFilter initialFilter;

  /// When true, render body only (hub owns shell + bottom bar).
  final bool embedded;

  @override
  State<TasksAllListScreen> createState() => _TasksAllListScreenState();
}

class _TasksAllListScreenState extends State<TasksAllListScreen> {
  static const _pageSize = 10;

  late TaskFilter _filter;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _searchVisible = false;
  String _searchQuery = '';
  int _visibleCount = _pageSize;
  Map<int, String> _memberPhotoById = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoFirebaseProvider>().loadTodos();
      _loadMemberPhotos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberPhotos() async {
    try {
      final members =
          await TeamMembersApiService.instance.getTeamMembers(forceRefresh: true);
      final map = <int, String>{};
      for (final m in members) {
        final url = m.image?.trim();
        if (url != null && url.isNotEmpty) {
          map[m.id] = url;
          if (m.employeeId != null) map[m.employeeId!] = url;
        }
      }
      if (!mounted) return;
      setState(() => _memberPhotoById = map);
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() => _visibleCount += _pageSize);
  }

  void _resetPagination() {
    _visibleCount = _pageSize;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  List<TodoModel> _filtered(List<TodoModel> all) {
    final byFilter = applyTaskFilter(all, _filter);
    final bySearch = searchTodos(byFilter, _searchQuery);
    return sortTodosNewestFirst(bySearch);
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<TodoFirebaseProvider>(
      builder: (context, provider, _) {
        final filtered = _filtered(provider.todos);
        final visible = filtered.take(_visibleCount).toList();
        final hasMore = visible.length < filtered.length;

        if (provider.isLoading && provider.todos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadTodos(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ProductivityLightFilterBar(
                  selected: _filter,
                  searchActive: _searchVisible,
                  onChanged: (f) {
                    setState(() {
                      _filter = f;
                      _resetPagination();
                    });
                  },
                  onSearchTap: () {
                    setState(() {
                      _searchVisible = !_searchVisible;
                      if (!_searchVisible) {
                        _searchController.clear();
                        _searchQuery = '';
                        _resetPagination();
                      }
                    });
                  },
                ),
              ),
              if (_searchVisible)
                SliverToBoxAdapter(
                  child: ProductivityLightSearchField(
                    controller: _searchController,
                    onChanged: (q) {
                      setState(() {
                        _searchQuery = q;
                        _resetPagination();
                      });
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
                  child: Text(
                    '${filtered.length} task${filtered.length == 1 ? '' : 's'}',
                    style: ProductivityLightTheme.cardMeta,
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _searchQuery.trim().isEmpty
                          ? 'No tasks'
                          : 'No matching tasks',
                      style: ProductivityLightTheme.cardSubtitle.copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final todo = visible[index];
                      return ProductivityTaskSoberCard(
                        todo: todo,
                        photoById: _memberPhotoById,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailsScreen(taskId: todo.firebaseId),
                            ),
                          );
                        },
                      );
                    },
                    childCount: visible.length,
                  ),
                ),
              if (hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );

    if (widget.embedded) return body;

    return ProductivityLightShell(
      showBack: true,
      title: 'Tasks',
      body: body,
    );
  }
}
