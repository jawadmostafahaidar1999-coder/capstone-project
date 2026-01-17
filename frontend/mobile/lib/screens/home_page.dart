import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/vendor.dart';
import 'vendor_profile_page.dart';
import 'cart_page.dart';
import 'wishlist_page.dart';
import 'recipe_page.dart';
import 'vendor_public_page.dart';
import 'orders_page.dart';
import '../widgets/notification_bell.dart';

class HomePage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const HomePage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  List<Vendor> _vendors = [];

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.apiClient.get(
        '/vendors',
        auth: true,
      ); // must exist in your API
      final data = (res['data'] as List?) ?? [];
      final vendors = data.map((e) => Vendor.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _loading = false;
      });

      _precacheVendorImages(vendors);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vendors.';
        _loading = false;
      });
    }
  }

  Future<void> _precacheVendorImages(List<Vendor> vendors) async {
    final urls = vendors
        .map((v) => widget.apiClient.resolveImageUrl(v.image))
        .where((u) => u != null)
        .cast<String>()
        .take(12)
        .toList();

    for (final u in urls) {
      // ignore: unawaited_futures
      precacheImage(CachedNetworkImageProvider(u), context);
    }
  }

  // Home sections (calculated from the vendors list)
  double _ratingOf(Vendor v) => (v.rating ?? 0).toDouble();

  int _weekSeed() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays + 1;
    final week = ((dayOfYear - 1) / 7).floor() + 1;
    return now.year * 100 + week; // e.g., 202552
  }

  double _popularScore(Vendor v, int seed) {
    final base = _ratingOf(v);
    final h = Object.hash(v.storeName, seed).abs() % 1000; // stable per week
    return base * 1000 + h.toDouble();
  }

  /// 'Popular this week' = Top-rated shops with a stable weekly shuffle.
  List<Vendor> get _popularVendors {
    final seed = _weekSeed();
    final list = [..._vendors];
    list.sort(
      (a, b) => _popularScore(b, seed).compareTo(_popularScore(a, seed)),
    );
    return list;
  }

  /// 'Top Rated' = sorted by rating desc.
  List<Vendor> get _topRatedVendors {
    final list = [..._vendors];
    list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    return list;
  }

  /// Until you add real offers fields in the backend, we treat vendors as
  /// 'Offers' if their bio contains keywords like 'discount' or '%'.
  /// If none match, we fall back to Top Rated.
  List<Vendor> get _offerVendors {
    final offers = _vendors.where((v) {
      final bio = (v.bio ?? '').toLowerCase();
      return bio.contains('offer') ||
          bio.contains('discount') ||
          bio.contains('deal') ||
          bio.contains('%');
    }).toList();

    if (offers.isEmpty) return _topRatedVendors;
    offers.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    return offers;
  }

  /// Used for the big list/grid at the bottom.
  List<Vendor> get _allShops {
    final list = [..._vendors];
    list.sort(
      (a, b) => a.storeName.toLowerCase().compareTo(b.storeName.toLowerCase()),
    );
    return list;
  }

  List<Vendor> _take(List<Vendor> list, int n) =>
      list.length <= n ? list : list.take(n).toList();

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final role = (user?.role ?? '').toString().toLowerCase();
    final isVendor = role == 'vendor';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9F5FB),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user != null ? 'Hi, ${user.name}' : 'Homemade Food',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Discover homemade kitchens near you',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (isVendor)
            IconButton(
              icon: const Icon(Icons.storefront),
              tooltip: 'My vendor profile',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VendorProfilePage(
                      apiClient: widget.apiClient,
                      authService: widget.authService,
                      ownerView: true,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'My wishlist',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WishlistPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Cart',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CartPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My orders',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrdersPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          NotificationBell(apiClient: widget.apiClient),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadVendors, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_vendors.isEmpty) {
      return const Center(child: Text('No kitchens available yet.'));
    }

    final popular = _take(_popularVendors, 10);
    final topRated = _take(_topRatedVendors, 10);
    final offers = _take(_offerVendors, 10);
    final allShops = _allShops;

    return RefreshIndicator(
      onRefresh: _loadVendors,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _buildTopShortcuts(),
          const SizedBox(height: 16),
          _buildVendorSection(title: 'Popular this week', vendors: popular),
          const SizedBox(height: 16),
          _buildVendorSection(title: 'Top Rated', vendors: topRated),
          const SizedBox(height: 16),
          _buildVendorSection(title: 'Offers', vendors: offers),
          const SizedBox(height: 20),
          _buildAllShopsSection(vendors: allShops),
        ],
      ),
    );
  }

  Widget _buildTopShortcuts() {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            icon: Icons.menu_book,
            title: 'Recipes',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipesPage(apiClient: widget.apiClient),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.check_circle,
            title: 'Special order',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Special order (coming soon)')),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.smart_toy,
            title: 'AI assistant',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI assistant (coming soon)')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVendorSection({
    required String title,
    required List<Vendor> vendors,
  }) {
    if (vendors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return _VendorCard(
                apiClient: widget.apiClient,
                vendor: vendor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VendorPublicPage(
                        apiClient: widget.apiClient,
                        vendorId: vendor.id,
                        vendor: vendor,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllShopsSection({required List<Vendor> vendors}) {
    if (vendors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),

        // Fancy centered title
        Row(
          children: [
            const Expanded(child: Divider(thickness: 1)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'All shops (${vendors.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const Expanded(child: Divider(thickness: 1)),
          ],
        ),

        const SizedBox(height: 14),

        // Different look: vertical list with larger cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vendors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final v = vendors[index];
            final img = widget.apiClient.resolveImageUrl(v.image);
            final rating = (v.rating ?? 0).toDouble();

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VendorPublicPage(
                      apiClient: widget.apiClient,
                      vendorId: v.id,
                      vendor: v,
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    // image / avatar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: img == null
                          ? Container(
                              width: 62,
                              height: 62,
                              color: const Color(0xFFEFE6F7),
                              alignment: Alignment.center,
                              child: Text(
                                v.storeName.isNotEmpty
                                    ? v.storeName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: img,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                              memCacheWidth: 180,
                              memCacheHeight: 180,
                              placeholder: (_, __) => Container(
                                width: 62,
                                height: 62,
                                color: const Color(0xFFEFE6F7),
                                alignment: Alignment.center,
                                child: Text(
                                  v.storeName.isNotEmpty
                                      ? v.storeName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 62,
                                height: 62,
                                color: const Color(0xFFEFE6F7),
                                alignment: Alignment.center,
                                child: Text(
                                  v.storeName.isNotEmpty
                                      ? v.storeName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(width: 12),

                    // text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (v.bio ?? '').trim().isEmpty
                                ? 'Homemade food'
                                : v.bio!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating == 0 ? '—' : rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if ((v.address ?? '').trim().isNotEmpty) ...[
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    v.address!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE6F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Simple vendor card widget used in horizontal lists + grid
class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback onTap;
  final ApiClient apiClient;
  final double? width;

  const _VendorCard({
    required this.vendor,
    required this.onTap,
    required this.apiClient,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final String name = (vendor.storeName).toString();
    final String description = (vendor.bio ?? '').toString();
    final double? rating = (vendor.rating)?.toDouble();
    final url = apiClient.resolveImageUrl(vendor.image);
    final letter = vendor.storeName.isNotEmpty
        ? vendor.storeName[0].toUpperCase()
        : '?';

    final String ratingText = rating != null ? rating.toStringAsFixed(1) : '—';
    final avatar = _VendorAvatar(url: url, fallbackLetter: letter);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width, // ✅ fixed width for horizontal list, flexible for grid
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(ratingText),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description.isEmpty ? 'Homemade food' : description,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorAvatar extends StatelessWidget {
  final String? url;
  final String fallbackLetter;

  const _VendorAvatar({required this.url, required this.fallbackLetter});

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();

    if (u.isEmpty) {
      return CircleAvatar(radius: 18, child: Text(fallbackLetter));
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: u,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        // decode smaller => faster + less memory
        memCacheWidth: 120,
        memCacheHeight: 120,
        placeholder: (_, __) => const SizedBox(
          width: 36,
          height: 36,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) =>
            CircleAvatar(radius: 18, child: Text(fallbackLetter)),
      ),
    );
  }
}
