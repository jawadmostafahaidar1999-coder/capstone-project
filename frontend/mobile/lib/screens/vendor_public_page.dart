// lib/screens/vendor_public_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/vendor.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/wishlist_service.dart';
import '../widgets/app_images.dart';
import 'product_details_page.dart';

class VendorPublicPage extends StatefulWidget {
  final ApiClient apiClient;
  final int vendorId;

  /// Optional: pass vendor from home page to render instantly (no extra vendor request)
  final Vendor? vendor;

  const VendorPublicPage({
    super.key,
    required this.apiClient,
    required this.vendorId,
    this.vendor,
  });

  @override
  State<VendorPublicPage> createState() => _VendorPublicPageState();
}

class _VendorPublicPageState extends State<VendorPublicPage> {
  static const _bg = Color(0xFFF9F5FB);

  late final WishlistService _wishlistService;

  Vendor? _vendor;
  bool _loading = true;
  String? _error;

  bool _loadingVendorFav = true;
  bool _isVendorFav = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  List<Product> _allProducts = [];
  List<_CatTab> _tabs = const [_CatTab(id: null, name: 'All')];
  int? _selectedCategoryId; // null => All

  @override
  void initState() {
    super.initState();
    _wishlistService = WishlistService(apiClient: widget.apiClient);
    _vendor = widget.vendor;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openProduct(Product p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailsPage(product: p, apiClient: widget.apiClient),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) vendor (if not passed)
      if (_vendor == null) {
        final vRes = await widget.apiClient.get(
          '/vendors/${widget.vendorId}',
          auth: true, // your backend protects this route
        );
        _vendor = Vendor.fromJson(
          (vRes['data'] as Map).cast<String, dynamic>(),
        );
      }

      // 2) products for this vendor
      final pRes = await widget.apiClient.get(
        '/products',
        auth: false, // products list is public in your backend
        query: {
          'vendor_id': widget.vendorId,
          'page': 1,
          'per_page': 200,
          'sort': 'newest',
        },
      );

      final data = (pRes['data'] as Map?) ?? {};
      final items = (data['items'] as List?) ?? [];
      _allProducts = items
          .map((e) => Product.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      // build tabs from vendor products categories
      final map = <int, String>{};
      for (final p in _allProducts) {
        final c = p.category;
        if (c != null) map[c.id] = c.name;
      }
      final tabs = <_CatTab>[const _CatTab(id: null, name: 'All')];
      final sortedKeys = map.keys.toList()
        ..sort((a, b) => map[a]!.compareTo(map[b]!));
      for (final id in sortedKeys) {
        tabs.add(_CatTab(id: id, name: map[id]!));
      }
      _tabs = tabs;

      // load vendor favorite status
      await _loadVendorFavoriteStatus();

      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load vendor page.';
      });
    }
  }

  Future<void> _loadVendorFavoriteStatus() async {
    setState(() => _loadingVendorFav = true);
    try {
      final favs = await _wishlistService.getFavoriteVendors();
      _isVendorFav = favs.any((v) => v.id == widget.vendorId);
    } on ApiException catch (e) {
      // If guest / unauthenticated, just show as not-favorited
      if (e.statusCode == 401) _isVendorFav = false;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingVendorFav = false);
  }

  Future<void> _toggleVendorFavorite() async {
    // Optimistic UI
    final next = !_isVendorFav;
    setState(() => _isVendorFav = next);

    try {
      if (next) {
        await _wishlistService.addVendorToFavorites(widget.vendorId);
        _snack('Added to favorite shops');
      } else {
        await _wishlistService.removeVendorFromFavorites(widget.vendorId);
        _snack('Removed from favorite shops');
      }
    } on ApiException catch (e) {
      // revert
      setState(() => _isVendorFav = !next);

      if (e.statusCode == 401) {
        _snack('Please login to favorite shops.');
      } else {
        _snack(e.message);
      }
    } catch (_) {
      setState(() => _isVendorFav = !next);
      _snack('Failed to update favorites.');
    }
  }

  List<Product> get _filtered {
    final q = _searchText.trim().toLowerCase();
    return _allProducts.where((p) {
      final matchesCategory =
          _selectedCategoryId == null || p.category?.id == _selectedCategoryId;

      if (!matchesCategory) return false;

      if (q.isEmpty) return true;

      final name = p.name.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  void _openSearch() {
    _searchCtrl.text = _searchText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final q = _searchCtrl.text.trim().toLowerCase();
              final matches = q.isEmpty
                  ? <Product>[]
                  : _allProducts.where((p) {
                      final name = p.name.toLowerCase();
                      final desc = (p.description ?? '').toLowerCase();
                      return name.contains(q) || desc.contains(q);
                    }).toList();

              return Container(
                decoration: const BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search input
                    TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search in this store...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setSheetState(() {});
                            setState(() => _searchText = '');
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      onSubmitted: (_) {
                        setState(() => _searchText = _searchCtrl.text.trim());
                        Navigator.pop(ctx);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Live results (dropdown style)
                    if (q.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Type to search…',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else if (matches.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No matches',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: matches.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = matches[i];
                              final img = widget.apiClient.resolveImageUrl(
                                p.image,
                              );
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    color: Colors.black12,
                                    child: img == null
                                        ? const Icon(Icons.fastfood)
                                        : Image.network(
                                            img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.fastfood),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '\$${p.price.toStringAsFixed(2)}',
                                ),
                                onTap: () {
                                  setState(() => _searchText = q);
                                  Navigator.pop(ctx);
                                  _openProduct(p);
                                },
                              );
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _searchText = '');
                              Navigator.pop(ctx);
                            },
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _buildCategoriesSummary(List<Product> products) {
    final names = <String>{};
    for (final p in products) {
      final c = p.category?.name;
      if (c != null && c.trim().isNotEmpty) names.add(c.trim());
    }
    final list = names.toList()..sort();
    if (list.isEmpty) return '';
    if (list.length <= 2) return list.join(', ');
    return '${list.take(2).join(', ')} +${list.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final vendor = _vendor;

    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? _ErrorView(message: _error!, onRetry: _load)
          : (vendor == null)
          ? _ErrorView(message: 'Vendor not found.', onRetry: _load)
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  backgroundColor: _bg,
                  elevation: 0,
                  leading: _IconPill(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  actions: [
                    _IconPill(icon: Icons.search, onTap: _openSearch),
                    const SizedBox(width: 8),
                    _IconPill(
                      icon: _loadingVendorFav
                          ? Icons.favorite_border
                          : (_isVendorFav
                                ? Icons.favorite
                                : Icons.favorite_border),
                      onTap: _loadingVendorFav ? () {} : _toggleVendorFavorite,
                    ),
                    const SizedBox(width: 12),
                  ],
                  expandedHeight: 230,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _HeaderImage(
                      url: widget.apiClient.resolveImageUrl(vendor.image),
                    ),
                  ),
                ),

                // Vendor card (overlaps header)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: _VendorCard(
                      apiClient: widget.apiClient,
                      vendor: vendor,
                      categoriesSummary: _buildCategoriesSummary(_allProducts),
                    ),
                  ),
                ),

                // Category pills (pinned)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    background: _bg,
                    minHeight: 72,
                    maxHeight: 72,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: _CategoryPills(
                        tabs: _tabs,
                        selectedId: _selectedCategoryId,
                        onSelect: (id) {
                          setState(() => _selectedCategoryId = id);
                        },
                      ),
                    ),
                  ),
                ),

                // Content
                if (_filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No items found.')),
                  )
                else
                  _buildMenuSlivers(),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            ),
    );
  }

  SliverList _buildMenuSlivers() {
    final items = _filtered;

    // All selected => group by category
    if (_selectedCategoryId == null) {
      final grouped = <String, List<Product>>{};
      for (final p in items) {
        final key = (p.category?.name.trim().isNotEmpty ?? false)
            ? p.category!.name
            : 'Other';
        (grouped[key] ??= []).add(p);
      }

      final keys = grouped.keys.toList()
        ..sort((a, b) {
          if (a == 'Other') return 1;
          if (b == 'Other') return -1;
          return a.compareTo(b);
        });

      final rows = <Widget>[];
      for (final k in keys) {
        rows.add(_SectionTitle(title: k));
        for (final p in grouped[k]!) {
          rows.add(
            _MenuItemCard(
              apiClient: widget.apiClient,
              product: p,
              onTap: () => _openProduct(p),
            ),
          );
        }
        rows.add(const SizedBox(height: 8));
      }

      return SliverList(delegate: SliverChildListDelegate(rows));
    }

    // Specific category => flat list
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _MenuItemCard(
          apiClient: widget.apiClient,
          product: items[i],
          onTap: () => _openProduct(items[i]),
        ),
        childCount: items.length,
      ),
    );
  }
}

class _CatTab {
  final int? id;
  final String name;
  const _CatTab({required this.id, required this.name});
}

class _HeaderImage extends StatelessWidget {
  final String? url;
  const _HeaderImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // fallback background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB8D88C), Color(0xFFF9F5FB)],
            ),
          ),
        ),

        if (url != null) ...[
          // blurred background layer
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // soft detail layer
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],

        // readability overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.20),
                Colors.black.withOpacity(0.06),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconPill({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Material(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final ApiClient apiClient;
  final Vendor vendor;
  final String categoriesSummary;

  const _VendorCard({
    required this.apiClient,
    required this.vendor,
    required this.categoriesSummary,
  });

  @override
  Widget build(BuildContext context) {
    final mins = vendor.orderDurationMinutes;
    final letter = vendor.storeName.isNotEmpty
        ? vendor.storeName[0].toUpperCase()
        : '?';

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AppNetAvatar(
              apiClient: apiClient,
              pathOrUrl: vendor.image,
              radius: 22,
              fallbackLetter: letter,
              fallbackIcon: Icons.storefront,
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.storeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16),
                      const SizedBox(width: 4),
                      const Text('--'),
                      const SizedBox(width: 10),
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 4),
                      Text(mins == null ? '--' : '${mins}m'),
                      if ((vendor.address ?? '').trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            vendor.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (categoriesSummary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      categoriesSummary,
                      style: const TextStyle(color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPills extends StatelessWidget {
  final List<_CatTab> tabs;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _CategoryPills({
    required this.tabs,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final selected = t.id == selectedId;
          return ChoiceChip(
            label: Text(t.name),
            selected: selected,
            onSelected: (_) => onSelect(t.id),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final ApiClient apiClient;
  final Product product;
  final VoidCallback onTap;

  const _MenuItemCard({
    required this.apiClient,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((product.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: const TextStyle(color: Colors.black54),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppNetImage(
                  apiClient: apiClient,
                  pathOrUrl: product.image,
                  width: 92,
                  height: 72,
                  borderRadius: BorderRadius.circular(14),
                  fallbackIcon: Icons.fastfood,
                  memCacheWidth: 300,
                  memCacheHeight: 240,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;
  final Color background;

  _CategoryHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
    required this.background,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.background != background;
  }
}
