// lib/pages/recipe_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../services/api_client.dart';
import '../services/recipe_service.dart';
import '../models/recipe.dart';
import '../widgets/app_images.dart';
import '../utils/image_upload_helper.dart';

class RecipesPage extends StatefulWidget {
  final ApiClient apiClient;
  const RecipesPage({super.key, required this.apiClient});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  int _tab = 0;
  final Set<int> _builtTabs = {0}; // build Discover first only

  @override
  Widget build(BuildContext context) {
    final service = RecipeService(widget.apiClient);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateRecipePage(apiClient: widget.apiClient),
                  ),
                );
                if (created == true) {
                  // trigger rebuild so Discover refreshes via key
                  DiscoverRecipesTab.refreshSignal.value++;
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New recipe'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() {
          _tab = i;
          _builtTabs.add(i);
        }),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'My',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          DiscoverRecipesTab(apiClient: widget.apiClient, service: service),

          _builtTabs.contains(1)
              ? SavedRecipesTab(apiClient: widget.apiClient, service: service)
              : const SizedBox.shrink(),

          _builtTabs.contains(2)
              ? MyRecipesTab(apiClient: widget.apiClient, service: service)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/* ========================= DISCOVER TAB ========================= */

class DiscoverRecipesTab extends StatefulWidget {
  final ApiClient apiClient;
  final RecipeService service;
  const DiscoverRecipesTab({
    super.key,
    required this.apiClient,
    required this.service,
  });

  // simple refresh trigger after creating a recipe
  static final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  @override
  State<DiscoverRecipesTab> createState() => _DiscoverRecipesTabState();
}

class _DiscoverRecipesTabState extends State<DiscoverRecipesTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _sort = 'date'; // date|rating
  int? _categoryId;
  final Set<int> _tagIds = {};
  bool _verifiedOnly = false;

  bool _loadingFilters = true;
  List<RecipeCategory> _categories = const [];
  List<RecipeTag> _tags = const [];

  bool _loadingTrending = true;
  List<RecipeListItem> _trending = const [];

  bool _loadingFeed = true;
  bool _loadingMore = false;
  int _page = 1;
  final int _perPage = 10;
  bool _hasMore = true;
  List<RecipeListItem> _items = const [];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    DiscoverRecipesTab.refreshSignal.addListener(_onExternalRefresh);
    _bootstrap();
  }

  @override
  void dispose() {
    DiscoverRecipesTab.refreshSignal.removeListener(_onExternalRefresh);
    _scroll.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _sortLabel(String v) {
    switch (v) {
      case 'rating':
        return 'Rating (highest)';
      case 'date':
      default:
        return 'Date (newest)';
    }
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadFilters(),
      _loadTrending(),
      _loadFeed(reset: true),
    ]);
  }

  void _onExternalRefresh() {
    _loadTrending();
    _loadFeed(reset: true);
  }

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    try {
      final cats = await widget.service.categories();
      final tags = await widget.service.tags();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _tags = tags;
        _loadingFilters = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFilters = false);
      _snack('Failed to load filters.');
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _loadingTrending = true);
    try {
      final paged = await widget.service.trendingWeek(page: 1, perPage: 10);
      if (!mounted) return;

      var list = paged.data;
      if (_verifiedOnly) {
        list = list.where((r) => r.author?.isVerifiedVendor == true).toList();
      }

      setState(() {
        _trending = list;
        _loadingTrending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTrending = false);
    }
  }

  Future<void> _loadFeed({required bool reset}) async {
    if (reset) {
      setState(() {
        _loadingFeed = true;
        _loadingMore = false;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final paged = await widget.service.fetchRecipes(
        q: _searchCtrl.text.trim(),
        sort: _sort,
        page: _page,
        perPage: _perPage,
        categoryId: _categoryId,
        tagIds: _tagIds.toList(),
        verifiedOnly: _verifiedOnly, // safe even if backend ignores it
      );

      if (!mounted) return;

      var list = paged.data;
      if (_verifiedOnly) {
        list = list.where((r) => r.author?.isVerifiedVendor == true).toList();
      }

      setState(() {
        _items = reset ? list : [..._items, ...list];
        _hasMore = paged.hasMore;
        _page = paged.currentPage + 1;
        _loadingFeed = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFeed = false;
        _loadingMore = false;
      });
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingFeed = false;
        _loadingMore = false;
      });
      _snack('Failed to load recipes.');
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loadingFeed) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 250) {
      _loadFeed(reset: false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _loadFeed(reset: true);
      _loadTrending();
    });
  }

  Future<void> _openTagsPicker() async {
    if (_loadingFilters) return;

    final picked = await openTagsPickerPage(
      context,
      allTags: _tags,
      selected: _tagIds,
      title: 'Filter tags',
    );

    if (picked == null) return;

    setState(() {
      _tagIds
        ..clear()
        ..addAll(picked);
    });

    _loadFeed(reset: true);
    _loadTrending();
  }

  void _clearFilters() {
    setState(() {
      _sort = 'date';
      _categoryId = null;
      _tagIds.clear();
      _verifiedOnly = false;
    });
    _loadFeed(reset: true);
    _loadTrending();
  }

  Future<void> _toggleLike(int index) async {
    final old = _items[index];
    final optimistic = old.copyWith(
      isLiked: !old.isLiked,
      likesCount: old.isLiked
          ? (old.likesCount - 1).clamp(0, 1 << 31)
          : old.likesCount + 1,
    );
    setState(() {
      final copy = [..._items];
      copy[index] = optimistic;
      _items = copy;
    });

    try {
      final res = old.isLiked
          ? await widget.service.unlike(old.id)
          : await widget.service.like(old.id);
      final updated = optimistic.copyWith(
        isLiked: res['is_liked'] == true,
        likesCount: (res['likes_count'] ?? optimistic.likesCount) as int,
      );
      setState(() {
        final copy = [..._items];
        copy[index] = updated;
        _items = copy;
      });
      _loadTrending();
    } on ApiException catch (e) {
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
      setState(() {
        final copy = [..._items];
        copy[index] = old;
        _items = copy;
      });
    } catch (_) {
      _snack('Failed to update like.');
      setState(() {
        final copy = [..._items];
        copy[index] = old;
        _items = copy;
      });
    }
  }

  Future<void> _toggleBookmark(int index) async {
    final old = _items[index];
    final optimistic = old.copyWith(
      isBookmarked: !old.isBookmarked,
      bookmarksCount: old.isBookmarked
          ? (old.bookmarksCount - 1).clamp(0, 1 << 31)
          : old.bookmarksCount + 1,
    );
    setState(() {
      final copy = [..._items];
      copy[index] = optimistic;
      _items = copy;
    });

    try {
      final res = old.isBookmarked
          ? await widget.service.unbookmark(old.id)
          : await widget.service.bookmark(old.id);
      final updated = optimistic.copyWith(
        isBookmarked: res['is_bookmarked'] == true,
        bookmarksCount:
            (res['bookmarks_count'] ?? optimistic.bookmarksCount) as int,
      );
      setState(() {
        final copy = [..._items];
        copy[index] = updated;
        _items = copy;
      });
    } on ApiException catch (e) {
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
      setState(() {
        final copy = [..._items];
        copy[index] = old;
        _items = copy;
      });
    } catch (_) {
      _snack('Failed to update bookmark.');
      setState(() {
        final copy = [..._items];
        copy[index] = old;
        _items = copy;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _categoryId != null ||
        _tagIds.isNotEmpty ||
        _sort != 'date' ||
        _verifiedOnly;

    final selectedTags = _tags.where((t) => _tagIds.contains(t.id)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search recipes…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadFeed(reset: true);
                            _loadTrending();
                            setState(() {});
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Filter Row 1: Verified + Tags + Clear
              Row(
                children: [
                  FilterChip(
                    selected: _verifiedOnly,
                    label: const Text('Verified only'),
                    onSelected: (v) {
                      setState(() => _verifiedOnly = v);
                      _loadTrending();
                      _loadFeed(reset: true);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadingFilters ? null : _openTagsPicker,
                      icon: const Icon(Icons.local_offer_outlined),
                      label: Text(
                        _tagIds.isEmpty ? 'Tags' : 'Tags (${_tagIds.length})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Clear filters',
                    onPressed: hasActiveFilters ? _clearFilters : null,
                    icon: const Icon(Icons.filter_alt_off),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filter Row 2: Sort dropdown + Category dropdown
              // Filter Row 2: Sort dropdown + Category dropdown (responsive + no overflow)
              LayoutBuilder(
                builder: (context, constraints) {
                  Widget sortDd() => DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _sort,
                    items: const [
                      DropdownMenuItem(
                        value: 'date',
                        child: Text(
                          'Date (newest)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'rating',
                        child: Text(
                          'Rating (highest)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _sort = v);
                      _loadFeed(reset: true);
                      _loadTrending();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  );

                  Widget catDd() => DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _categoryId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'All categories',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _loadingFilters
                        ? null
                        : (id) {
                            setState(() => _categoryId = id);
                            _loadFeed(reset: true);
                            _loadTrending();
                          },
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: _loadingFilters
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );

                  // Small screens: stack vertically to prevent overflow
                  if (constraints.maxWidth < 360) {
                    return Column(
                      children: [sortDd(), const SizedBox(height: 10), catDd()],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: sortDd()),
                      const SizedBox(width: 10),
                      Expanded(child: catDd()),
                    ],
                  );
                },
              ),

              // Active filter chips
              if (hasActiveFilters || selectedTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_verifiedOnly) const _MiniChip('Verified'),
                      if (_sort != 'date')
                        _MiniChip('Sort: ${_sortLabel(_sort)}'),
                      if (_categoryId != null)
                        _MiniChip(
                          'Cat: ${_categories.firstWhere((c) => c.id == _categoryId).name}',
                        ),
                      if (selectedTags.isNotEmpty) ...[
                        ...selectedTags
                            .take(6)
                            .map(
                              (t) => InputChip(
                                label: Text(t.name),
                                onDeleted: () {
                                  setState(() => _tagIds.remove(t.id));
                                  _loadFeed(reset: true);
                                  _loadTrending();
                                },
                              ),
                            ),
                        if (selectedTags.length > 6)
                          ActionChip(
                            label: Text('+${selectedTags.length - 6} more'),
                            onPressed: _openTagsPicker,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadTrending();
              await _loadFeed(reset: true);
            },
            child: _loadingFeed
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    children: [
                      _TrendingSection(
                        loading: _loadingTrending,
                        items: _trending,
                        onTap: (id) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailsPage(
                              apiClient: widget.apiClient,
                              recipeId: id,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: Text('No recipes found.')),
                        )
                      else
                        ..._items.asMap().entries.map((e) {
                          final i = e.key;
                          final r = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecipeCard(
                              apiClient: widget.apiClient,
                              item: r,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailsPage(
                                    apiClient: widget.apiClient,
                                    recipeId: r.id,
                                  ),
                                ),
                              ),
                              onLike: () => _toggleLike(i),
                              onBookmark: () => _toggleBookmark(i),
                            ),
                          );
                        }),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!_hasMore && _items.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: Text('No more recipes')),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/* ========================= SAVED TAB ========================= */

class SavedRecipesTab extends StatefulWidget {
  final ApiClient apiClient;
  final RecipeService service;

  const SavedRecipesTab({
    super.key,
    required this.apiClient,
    required this.service,
  });

  @override
  State<SavedRecipesTab> createState() => _SavedRecipesTabState();
}

class _SavedRecipesTabState extends State<SavedRecipesTab> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _perPage = 10;
  List<RecipeListItem> _items = const [];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 250) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final paged = await widget.service.myBookmarks(
        page: _page,
        perPage: _perPage,
      );
      if (!mounted) return;

      setState(() {
        _items = reset ? paged.data : [..._items, ...paged.data];
        _hasMore = paged.hasMore;
        _page = paged.currentPage + 1;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      _snack(
        e.statusCode == 401
            ? 'Login required to see saved recipes.'
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      _snack('Failed to load saved recipes.');
    }
  }

  Future<void> _unbookmark(int index) async {
    final old = _items[index];
    setState(() {
      final copy = [..._items];
      copy.removeAt(index);
      _items = copy;
    });

    try {
      await widget.service.unbookmark(old.id);
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() {
        final copy = [..._items];
        copy.insert(index, old);
        _items = copy;
      });
    } catch (_) {
      _snack('Failed to update bookmark.');
      setState(() {
        final copy = [..._items];
        copy.insert(index, old);
        _items = copy;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No saved recipes yet.')),
            )
          else
            ..._items.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecipeCard(
                  apiClient: widget.apiClient,
                  item: r,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailsPage(
                        apiClient: widget.apiClient,
                        recipeId: r.id,
                      ),
                    ),
                  ),
                  onLike: () {},
                  onBookmark: () => _unbookmark(i),
                ),
              );
            }),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/* ========================= MY TAB ========================= */

class MyRecipesTab extends StatefulWidget {
  final ApiClient apiClient;
  final RecipeService service;

  const MyRecipesTab({
    super.key,
    required this.apiClient,
    required this.service,
  });

  @override
  State<MyRecipesTab> createState() => _MyRecipesTabState();
}

class _MyRecipesTabState extends State<MyRecipesTab> {
  bool _loading = true;
  List<RecipeListItem> _all = const [];
  String _statusFilter = 'all'; // all|pending|approved|rejected

  final Set<int> _deletingIds = {}; // track which recipe is deleting

  Future<void> _confirmDelete(RecipeListItem r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text(
          'Are you sure you want to delete "${r.title}"?\nThis can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteRecipe(r);
    }
  }

  Future<void> _deleteRecipe(RecipeListItem r) async {
    if (_deletingIds.contains(r.id)) return;

    final oldList = List<RecipeListItem>.from(_all);

    setState(() {
      _deletingIds.add(r.id);
      _all = _all.where((x) => x.id != r.id).toList(); // optimistic remove
    });

    try {
      await widget.service.deleteRecipe(r.id);
      if (!mounted) return;
      _snack('Recipe deleted.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _all = oldList);
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _all = oldList);
      _snack('Failed to delete recipe.');
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(r.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final paged = await widget.service.myRecipes(page: 1, perPage: 50);
      if (!mounted) return;
      setState(() {
        _all = paged.data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(
        e.statusCode == 401 ? 'Login required to see your recipes.' : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to load your recipes.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final items = _statusFilter == 'all'
        ? _all
        : _all
              .where((r) => (r.status ?? '').toLowerCase() == _statusFilter)
              .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              _StatusChip(
                label: 'All',
                value: 'all',
                current: _statusFilter,
                onTap: () => setState(() => _statusFilter = 'all'),
              ),
              _StatusChip(
                label: 'Pending',
                value: 'pending',
                current: _statusFilter,
                onTap: () => setState(() => _statusFilter = 'pending'),
              ),
              _StatusChip(
                label: 'Approved',
                value: 'approved',
                current: _statusFilter,
                onTap: () => setState(() => _statusFilter = 'approved'),
              ),
              _StatusChip(
                label: 'Rejected',
                value: 'rejected',
                current: _statusFilter,
                onTap: () => setState(() => _statusFilter = 'rejected'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No recipes here.')),
            )
          else
            ...items.map((r) {
              final status = (r.status ?? 'unknown').toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: (r.coverImage == null)
                        ? null
                        : AppNetImage(
                            apiClient: widget.apiClient,
                            pathOrUrl: r.coverImage,
                            width: 46,
                            height: 46,
                            borderRadius: BorderRadius.circular(8),
                            fallbackIcon: Icons.restaurant_menu,
                            memCacheWidth: 180,
                            memCacheHeight: 180,
                          ),
                    title: Text(r.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MiniChip('STATUS: $status'),
                            if ((r.rejectionReason ?? '').trim().isNotEmpty &&
                                (r.status ?? '') == 'rejected')
                              _MiniChip('Reason: ${r.rejectionReason}'),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_deletingIds.contains(r.id))
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _confirmDelete(r),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),

                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailsPage(
                          apiClient: widget.apiClient,
                          recipeId: r.id,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/* ========================= DETAILS PAGE ========================= */

class RecipeDetailsPage extends StatefulWidget {
  final ApiClient apiClient;
  final int recipeId;

  const RecipeDetailsPage({
    super.key,
    required this.apiClient,
    required this.recipeId,
  });

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late final RecipeService _service = RecipeService(widget.apiClient);

  bool _loading = true;
  RecipeDetail? _recipe;
  String? _error;

  bool _loadingComments = true;
  List<RecipeComment> _comments = const [];
  final _commentCtrl = TextEditingController();
  int? _replyToCommentId;
  bool _sendingComment = false;

  bool _loadingReviews = true;
  List<RecipeReviewModel> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadAll() async {
    await Future.wait([_loadRecipe(), _loadComments(), _loadReviews()]);
  }

  Future<void> _loadRecipe() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await _service.fetchRecipe(widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load recipe.';
        _loading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final paged = await _service.comments(widget.recipeId, page: 1);
      if (!mounted) return;
      setState(() {
        _comments = paged.data;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final paged = await _service.reviews(widget.recipeId, page: 1);
      if (!mounted) return;
      setState(() {
        _reviews = paged.data;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
      // If you didn't add /recipes/{id}/reviews yet, this section will just stay empty.
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      await _service.addComment(
        widget.recipeId,
        text,
        parentId: _replyToCommentId,
      );
      _commentCtrl.clear();
      setState(() => _replyToCommentId = null);
      await _loadComments();
    } on ApiException catch (e) {
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
    } catch (_) {
      _snack('Failed to add comment.');
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _rateDialog() async {
    int rating = 5;
    final bodyCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rate this recipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: rating,
              items: [1, 2, 3, 4, 5]
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n star${n == 1 ? '' : 's'}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => rating = v ?? 5,
              decoration: const InputDecoration(labelText: 'Rating'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (ok != true) {
      bodyCtrl.dispose();
      return;
    }

    try {
      await _service.upsertReview(
        widget.recipeId,
        rating: rating,
        body: bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
      );
      await _loadRecipe();
      await _loadReviews();
      _snack('Review saved.');
    } on ApiException catch (e) {
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
    } catch (_) {
      _snack('Failed to submit review.');
    } finally {
      bodyCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: Center(child: Text(_error!)),
      );
    }

    final r = _recipe!;
    final author = r.author;
    final coverUrl = widget.apiClient.resolveImageUrl(r.coverImage);

    return Scaffold(
      appBar: AppBar(title: Text(r.title)),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (coverUrl != null)
              AppNetImage(
                apiClient: widget.apiClient,
                pathOrUrl:
                    coverUrl, // already absolute => resolve keeps it fine
                width: double.infinity,
                height: 220,
                borderRadius: BorderRadius.circular(12),
                fallbackIcon: Icons.restaurant_menu,
                memCacheWidth: 900,
                memCacheHeight: 600,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (author != null)
                  _Pill('${author.name}${author.isVerifiedVendor ? ' ✓' : ''}'),
                if (r.category != null) _Pill(r.category!.name),
                if (r.status != null) _Pill('Status: ${r.status}'),
                _Pill('${r.ratingAvg.toStringAsFixed(1)} ★ (${r.ratingCount})'),
              ],
            ),
            if ((r.rejectionReason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Rejection reason: ${r.rejectionReason}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if ((r.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(r.description!),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _rateDialog,
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Rate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ingredients',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...r.ingredients.map((i) {
              final text =
                  '• ${i.quantity ?? ''} ${i.unit ?? ''} ${i.name}${(i.note ?? '').trim().isEmpty ? '' : ' — ${i.note}'}'
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim();
              return Text(text);
            }),
            const SizedBox(height: 16),
            const Text('Steps', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...r.steps.asMap().entries.map((e) {
              final idx = e.key + 1;
              final s = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$idx) ${s.text}${s.timerMinutes == null ? '' : ' (${s.timerMinutes}m)'}',
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Reviews',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loadingReviews)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reviews.isEmpty)
              const Text('No reviews yet.')
            else
              ..._reviews.take(10).map((rv) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${rv.user?.name ?? 'User'} • ${rv.rating}★'),
                  subtitle: Text(
                    (rv.body ?? '').trim().isEmpty ? '—' : rv.body!,
                  ),
                );
              }),
            const SizedBox(height: 16),
            const Text(
              'Comments',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loadingComments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_comments.isEmpty)
              const Text('No comments yet.')
            else
              ..._comments.map(
                (c) => _CommentTile(
                  comment: c,
                  onReply: () => setState(() => _replyToCommentId = c.id),
                ),
              ),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 10,
          bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToCommentId != null)
              Row(
                children: [
                  Expanded(
                    child: Text('Replying… (comment #$_replyToCommentId)'),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyToCommentId = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _sendingComment ? null : _sendComment,
                  icon: _sendingComment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final RecipeComment comment;
  final VoidCallback onReply;

  const _CommentTile({required this.comment, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment.user?.name ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(comment.body),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Reply'),
                ),
              ],
            ),
            if (comment.replies.isNotEmpty) ...[
              const Divider(),
              ...comment.replies.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(left: 10, top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.user?.name ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(r.body),
                          ],
                        ),
                      ),
                    ],
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

/* ========================= CREATE PAGE (INSIDE SAME FILE) ========================= */

class CreateRecipePage extends StatefulWidget {
  final ApiClient apiClient;
  const CreateRecipePage({super.key, required this.apiClient});

  @override
  State<CreateRecipePage> createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends State<CreateRecipePage> {
  late final RecipeService _service = RecipeService(widget.apiClient);

  int _step = 0;
  bool _submitting = false;

  bool _loadingFilters = true;
  List<RecipeCategory> _categories = const [];
  List<RecipeTag> _tags = const [];

  Uint8List? _coverBytes;
  String? _coverPath;

  final _basicKey = GlobalKey<FormState>();
  final _ingredientsKey = GlobalKey<FormState>();
  final _stepsKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController(text: '1');
  final _prepCtrl = TextEditingController();
  final _cookCtrl = TextEditingController();

  String _visibility = 'public';
  int? _categoryId;
  final Set<int> _tagIds = {};

  final List<_IngredientDraft> _ingredients = [_IngredientDraft()];
  final List<_StepDraft> _steps = [_StepDraft()];

  static const List<String> _unitOptions = [
    'g',
    'kg',
    'ml',
    'l',
    'cup',
    'tbsp',
    'tsp',
    'piece',
  ];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _servingsCtrl.dispose();
    _prepCtrl.dispose();
    _cookCtrl.dispose();
    for (final i in _ingredients) {
      i.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    try {
      final cats = await _service.categories();
      final tags = await _service.tags();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _tags = tags;
        _loadingFilters = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFilters = false);
      _snack('Failed to load categories/tags.');
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      setState(() => _submitting = true);

      final up = await ImageUploadHelper.pickAndUpload(
        apiClient: widget.apiClient,
        folder: 'recipes',
        auth: true,
        imageQuality: 75,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (up == null) return;

      if (!mounted) return;
      setState(() {
        _coverBytes = up.bytes;
        _coverPath = up.path;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverBytes = null;
      _coverPath = null;
    });
  }

  bool _validateIngredients() {
    final ok = _ingredientsKey.currentState?.validate() ?? false;
    if (!ok) return false;
    final anyNamed = _ingredients.any((e) => e.nameCtrl.text.trim().isNotEmpty);
    if (!anyNamed) {
      _snack('Add at least 1 ingredient.');
      return false;
    }
    return true;
  }

  bool _validateSteps() {
    final ok = _stepsKey.currentState?.validate() ?? false;
    if (!ok) return false;
    final anyStep = _steps.any((e) => e.textCtrl.text.trim().isNotEmpty);
    if (!anyStep) {
      _snack('Add at least 1 step.');
      return false;
    }
    return true;
  }

  List<RecipeIngredientInput> _buildIngredients() {
    return _ingredients
        .where((d) => d.nameCtrl.text.trim().isNotEmpty)
        .map(
          (d) => RecipeIngredientInput(
            name: d.nameCtrl.text.trim(),
            quantity: d.qtyCtrl.text.trim().isEmpty
                ? null
                : d.qtyCtrl.text.trim(),
            unit: d.unit,
            note: d.noteCtrl.text.trim().isEmpty
                ? null
                : d.noteCtrl.text.trim(),
          ),
        )
        .toList();
  }

  List<RecipeStepInput> _buildSteps() {
    return _steps
        .where((d) => d.textCtrl.text.trim().isNotEmpty)
        .map(
          (d) => RecipeStepInput(
            text: d.textCtrl.text.trim(),
            timerMinutes: int.tryParse(d.timerCtrl.text.trim()),
          ),
        )
        .toList();
  }

  Future<void> _publish() async {
    if (!(_basicKey.currentState?.validate() ?? false)) return;
    if (!_validateIngredients()) return;
    if (!_validateSteps()) return;

    setState(() => _submitting = true);
    try {
      // 1) upload image first (optional)
      final coverPath = _coverPath;

      // 2) now create recipe with cover_image path
      await _service.createRecipe(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        servings: int.parse(_servingsCtrl.text.trim()),
        prepMinutes: int.tryParse(_prepCtrl.text.trim()),
        cookMinutes: int.tryParse(_cookCtrl.text.trim()),
        visibility: _visibility,
        categoryId: _categoryId,
        tagIds: _tagIds.toList(),
        ingredients: _buildIngredients(),
        steps: _buildSteps(),
        coverImage: coverPath,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.statusCode == 401 ? 'Login required.' : e.message);
    } catch (_) {
      _snack('Failed to create recipe.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _continue() {
    if (_step == 0) {
      if (!(_basicKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!_validateIngredients()) return;
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (!_validateSteps()) return;
      setState(() => _step = 3);
      return;
    }
    _publish();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTags = _tags.where((t) => _tagIds.contains(t.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create recipe'),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: _loadingFilters
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.vertical,
              currentStep: _step,
              onStepContinue: _submitting ? null : _continue,
              onStepCancel: _submitting ? null : _back,
              controlsBuilder: (context, details) {
                final isLast = _step == 3;
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isLast ? 'Publish' : 'Continue'),
                      ),
                      const SizedBox(width: 12),
                      if (_step > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Basic'),
                  isActive: _step >= 0,
                  content: Form(
                    key: _basicKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recipe title *',
                            hintText: 'e.g. Grandma’s Kibbeh',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Title is required';
                            if (v.trim().length < 3)
                              return 'Title is too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_coverBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _coverBytes!,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (_coverBytes != null) const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickCoverImage,
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  _coverBytes == null
                                      ? 'Add photo (optional)'
                                      : 'Change photo',
                                ),
                              ),
                            ),
                            if (_coverBytes != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove photo',
                                onPressed: _removeCoverImage,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Short description',
                            hintText: '1–2 lines about your recipe',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _servingsCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Servings *',
                                  hintText: 'e.g. 4',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0)
                                    return 'Enter a valid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _visibility,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Text('Public'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'private',
                                    child: Text('Private'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _visibility = v ?? 'public'),
                                decoration: const InputDecoration(
                                  labelText: 'Visibility',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _prepCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Prep minutes',
                                  hintText: 'e.g. 20',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _cookCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cook minutes',
                                  hintText: 'e.g. 30',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: _categoryId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No category'),
                            ),
                            ..._categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await openTagsPickerPage(
                                context,
                                allTags: _tags,
                                selected: _tagIds,
                                title: 'Select recipe tags',
                              );

                              if (picked != null) {
                                setState(() {
                                  _tagIds
                                    ..clear()
                                    ..addAll(picked);
                                });
                              }

                              if (picked != null) {
                                setState(() {
                                  _tagIds
                                    ..clear()
                                    ..addAll(picked);
                                });
                              }
                            },
                            icon: const Icon(Icons.local_offer_outlined),
                            label: const Text('Pick tags'),
                          ),
                        ),
                        if (selectedTags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: selectedTags
                                .map(
                                  (t) => InputChip(
                                    label: Text(t.name),
                                    onDeleted: () =>
                                        setState(() => _tagIds.remove(t.id)),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Ingredients'),
                  isActive: _step >= 1,
                  content: Form(
                    key: _ingredientsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add ingredients (at least 1).'),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _ingredients.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _ingredients.removeAt(oldIndex);
                              _ingredients.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final d = _ingredients[index];
                            return Card(
                              key: ValueKey(d.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Ingredient ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: _ingredients.length == 1
                                              ? null
                                              : () {
                                                  setState(() {
                                                    final removed = _ingredients
                                                        .removeAt(index);
                                                    removed.dispose();
                                                  });
                                                },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                        const Icon(Icons.drag_handle),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: d.nameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Name *',
                                        hintText: 'e.g. Bulgur',
                                      ),
                                      validator: (v) {
                                        if (_ingredients.length == 1 ||
                                            (v != null &&
                                                v.trim().isNotEmpty)) {
                                          if (v == null || v.trim().isEmpty)
                                            return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: d.qtyCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Quantity',
                                              hintText: 'e.g. 2 or 300',
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                                value: d.unit,
                                                items: _unitOptions
                                                    .map(
                                                      (u) => DropdownMenuItem(
                                                        value: u,
                                                        child: Text(u),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) =>
                                                    setState(() => d.unit = v),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Unit',
                                                    ),
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: d.noteCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Note',
                                        hintText: 'e.g. finely chopped',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _ingredients.add(_IngredientDraft()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add ingredient'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Steps'),
                  isActive: _step >= 2,
                  content: Form(
                    key: _stepsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add steps (at least 1).'),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _steps.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _steps.removeAt(oldIndex);
                              _steps.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final d = _steps[index];
                            return Card(
                              key: ValueKey(d.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Step ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: _steps.length == 1
                                              ? null
                                              : () {
                                                  setState(() {
                                                    final removed = _steps
                                                        .removeAt(index);
                                                    removed.dispose();
                                                  });
                                                },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                        const Icon(Icons.drag_handle),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: d.textCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Instruction *',
                                        hintText:
                                            'Describe what to do in this step',
                                      ),
                                      maxLines: 3,
                                      validator: (v) {
                                        if (_steps.length == 1 ||
                                            (v != null &&
                                                v.trim().isNotEmpty)) {
                                          if (v == null || v.trim().isEmpty)
                                            return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: d.timerCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Timer minutes',
                                        hintText: 'e.g. 10',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _steps.add(_StepDraft())),
                            icon: const Icon(Icons.add),
                            label: const Text('Add step'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Preview'),
                  isActive: _step >= 3,
                  content: Builder(
                    builder: (_) {
                      final preview = {
                        'title': _titleCtrl.text.trim(),
                        'description': _descCtrl.text.trim().isEmpty
                            ? null
                            : _descCtrl.text.trim(),
                        'servings': int.tryParse(_servingsCtrl.text.trim()),
                        'prep_minutes': int.tryParse(_prepCtrl.text.trim()),
                        'cook_minutes': int.tryParse(_cookCtrl.text.trim()),
                        'visibility': _visibility,
                        'category_id': _categoryId,
                        'tag_ids': _tagIds.toList(),
                        'ingredients': _buildIngredients()
                            .map((e) => e.toJson())
                            .toList(),
                        'steps': _buildSteps().map((e) => e.toJson()).toList(),
                      };
                      final jsonPretty = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(preview);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          jsonPretty,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _IngredientDraft {
  final String id = UniqueKey().toString();
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  String? unit;
  final noteCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }
}

class _StepDraft {
  final String id = UniqueKey().toString();
  final textCtrl = TextEditingController();
  final timerCtrl = TextEditingController();

  void dispose() {
    textCtrl.dispose();
    timerCtrl.dispose();
  }
}

/* ========================= UI PARTS ========================= */

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TagsPanel extends StatefulWidget {
  final bool loading;
  final List<RecipeTag> tags;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  const _TagsPanel({
    required this.loading,
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  State<_TagsPanel> createState() => _TagsPanelState();
}

class _TagsPanelState extends State<_TagsPanel> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const Center(child: CircularProgressIndicator());

    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.tags
        : widget.tags.where((t) => t.name.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final t = filtered[i];
              final checked = widget.selectedIds.contains(t.id);
              return CheckboxListTile(
                value: checked,
                title: Text(t.name),
                onChanged: (v) {
                  final next = Set<int>.from(widget.selectedIds);
                  if (v == true) next.add(t.id);
                  if (v == false) next.remove(t.id);
                  widget.onChanged(next);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingSection extends StatelessWidget {
  final bool loading;
  final List<RecipeListItem> items;
  final void Function(int recipeId) onTap;

  const _TrendingSection({
    required this.loading,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator()),
      );
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Most liked this week',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final r = items[i];
              return InkWell(
                onTap: () => onTap(r.id),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.favorite, size: 16),
                          const SizedBox(width: 6),
                          Text('${r.likesCount} likes'),
                          const SizedBox(width: 12),
                          const Icon(Icons.star, size: 16),
                          const SizedBox(width: 6),
                          Text(r.ratingAvg.toStringAsFixed(1)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final ApiClient apiClient;
  final RecipeListItem item;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  const _RecipeCard({
    required this.apiClient,
    required this.item,
    required this.onTap,
    required this.onLike,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final author = item.author;
    final coverUrl = apiClient.resolveImageUrl(item.coverImage);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (optional) cover image (needs model field coverImage)
              if (coverUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: item.isBookmarked ? 'Unsave' : 'Save',
                    onPressed: onBookmark,
                    icon: Icon(
                      item.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),

              if ((item.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (author != null)
                    _Pill(
                      '${author.name}${author.isVerifiedVendor ? ' ✓' : ''}',
                    ),
                  if (item.category != null) _Pill(item.category!.name),
                  if (item.servings != null) _Pill('${item.servings} servings'),
                  if (item.prepMinutes != null)
                    _Pill('Prep ${item.prepMinutes}m'),
                  if (item.cookMinutes != null)
                    _Pill('Cook ${item.cookMinutes}m'),

                  // NOTE: rating pill REMOVED from here (was in your current code)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: item.tags
                        .take(6)
                        .map((t) => _Pill('#${t.name}'))
                        .toList(),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                      item.isLiked ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text('${item.likesCount}'),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: onBookmark,
                    icon: Icon(
                      item.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    label: Text('${item.bookmarksCount}'),
                  ),
                  const SizedBox(width: 10),

                  // ✅ rating moved here beside like/bookmark
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${item.ratingAvg.toStringAsFixed(1)} (${item.ratingCount})',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

Future<Set<int>?> openTagsPickerPage(
  BuildContext context, {
  required List<RecipeTag> allTags,
  required Set<int> selected,
  String title = 'Select tags',
}) async {
  // Hide keyboard before opening
  FocusManager.instance.primaryFocus?.unfocus();

  return Navigator.of(context).push<Set<int>>(
    MaterialPageRoute(
      builder: (_) => TagsPickerPage(
        title: title,
        allTags: allTags,
        initialSelected: selected,
      ),
    ),
  );
}

class TagsPickerPage extends StatefulWidget {
  final String title;
  final List<RecipeTag> allTags;
  final Set<int> initialSelected;

  const TagsPickerPage({
    super.key,
    required this.title,
    required this.allTags,
    required this.initialSelected,
  });

  @override
  State<TagsPickerPage> createState() => _TagsPickerPageState();
}

class _TagsPickerPageState extends State<TagsPickerPage> {
  final _searchCtrl = TextEditingController();
  late Set<int> _selected = Set<int>.from(widget.initialSelected);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();

    final filtered = q.isEmpty
        ? widget.allTags
        : widget.allTags
              .where((t) => t.name.toLowerCase().contains(q))
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Done'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: filtered.isEmpty
                      ? null
                      : () {
                          setState(() {
                            // Select all *visible* tags
                            for (final t in filtered) {
                              _selected.add(t.id);
                            }
                          });
                        },
                  child: const Text('Select visible'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.length} selected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final t = filtered[i];
                  final checked = _selected.contains(t.id);

                  return CheckboxListTile(
                    value: checked,
                    title: Text(t.name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(t.id);
                        } else {
                          _selected.remove(t.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
