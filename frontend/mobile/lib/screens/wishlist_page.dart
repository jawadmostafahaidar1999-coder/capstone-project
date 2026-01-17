// lib/screens/wishlist_page.dart
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/app_images.dart';
import 'product_details_page.dart';
import 'vendor_public_page.dart';

class WishlistPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const WishlistPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const _bg = Color(0xFFF9F5FB);

  late final WishlistService _wishlistService;

  List<Vendor>? _vendors;
  List<Product>? _products;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wishlistService = WishlistService(apiClient: widget.apiClient);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _wishlistService.getFavoriteVendors(),
        _wishlistService.getWishlist(),
      ]);

      if (!mounted) return;

      setState(() {
        _vendors = results[0] as List<Vendor>;
        _products = results[1] as List<Product>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load wishlist';
        _loading = false;
      });
    }
  }

  Future<void> _removeVendor(Vendor vendor) async {
    try {
      await _wishlistService.removeVendorFromFavorites(vendor.id);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed store from favorites')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove store')));
    }
  }

  Future<void> _removeProduct(Product product) async {
    try {
      await _wishlistService.removeFromWishlist(product.id);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from wishlist')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove product')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = _vendors ?? [];
    final products = _products ?? [];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('My wishlist'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : (vendors.isEmpty && products.isEmpty)
          ? const Center(child: Text('Your wishlist is empty'))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                children: [
                  if (vendors.isNotEmpty) ...[
                    const _SectionTitle('Favorite shops'),
                    const SizedBox(height: 10),
                    ...vendors.map((v) {
                      final img = widget.apiClient.resolveImageUrl(v.image);
                      final address = (v.address ?? '').trim();
                      final rating = v.rating;
                      final mins = v.orderDurationMinutes;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NiceCard(
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
                          leading: AppNetImage(
                            apiClient: widget.apiClient,
                            pathOrUrl:
                                img, // keeps your existing resolveImageUrl()
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(14),
                            fallbackLetter: v.storeName.trim().isEmpty
                                ? '?'
                                : v.storeName.trim()[0].toUpperCase(),
                            fallbackIcon: Icons.storefront,
                            memCacheWidth: 180,
                            memCacheHeight: 180,
                          ),
                          title: v.storeName,
                          subtitle: address.isEmpty ? '—' : address,
                          chips: [
                            _MiniChip(
                              icon: Icons.star,
                              text: rating == null
                                  ? '--'
                                  : rating.toStringAsFixed(1),
                            ),
                            _MiniChip(
                              icon: Icons.schedule,
                              text: mins == null ? '--' : '${mins}m',
                            ),
                          ],
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeVendor(v),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  if (products.isNotEmpty) ...[
                    const _SectionTitle('Saved products'),
                    const SizedBox(height: 10),
                    ...products.map((p) {
                      final img = widget.apiClient.resolveImageUrl(p.image);
                      final catName = p.category?.name ?? 'No category';
                      final vendorName = p.vendor?.storeName;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NiceCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailsPage(
                                  product: p,
                                  apiClient: widget.apiClient,
                                ),
                              ),
                            );
                          },
                          leading: AppNetImage(
                            apiClient: widget.apiClient,
                            pathOrUrl:
                                img, // keeps your existing resolveImageUrl()
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(14),
                            fallbackLetter: p.name.trim().isEmpty
                                ? '?'
                                : p.name.trim()[0].toUpperCase(),
                            fallbackIcon: Icons.fastfood,
                            memCacheWidth: 180,
                            memCacheHeight: 180,
                          ),
                          title: p.name,
                          subtitle:
                              vendorName == null || vendorName.trim().isEmpty
                              ? catName
                              : '$catName • $vendorName',
                          chips: [
                            _MiniChip(
                              icon: Icons.attach_money,
                              text: p.price.toStringAsFixed(2),
                            ),
                          ],
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeProduct(p),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _NiceCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget trailing;

  const _NiceCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: chips),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
