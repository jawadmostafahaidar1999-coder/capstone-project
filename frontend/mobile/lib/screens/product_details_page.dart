// lib/screens/product_details_page.dart
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import 'vendor_public_page.dart';
import '../services/review_service.dart';
import '../models/review.dart';
import '../widgets/app_images.dart';

class ProductDetailsPage extends StatelessWidget {
  final Product product;
  final ApiClient apiClient;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.apiClient,
  });

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addToCart(BuildContext context) async {
    final cartService = CartService(apiClient: apiClient);

    try {
      await cartService.addToCart(productId: product.id, quantity: 1);
      _snack(context, 'Added to cart!');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _snack(context, 'Please login to add items to cart.');
      } else {
        _snack(context, e.message);
      }
    } catch (_) {
      _snack(context, 'Failed to add to cart.');
    }
  }

  Future<void> _addToWishlist(BuildContext context) async {
    final wishlistService = WishlistService(apiClient: apiClient);

    try {
      await wishlistService.addToWishlist(product.id);
      _snack(context, 'Added to wishlist!');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _snack(context, 'Please login to add to wishlist.');
      } else {
        _snack(context, e.message);
      }
    } catch (_) {
      _snack(context, 'Failed to add to wishlist.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (product.image != null && product.image!.trim().isNotEmpty)
              AppNetImage(
                apiClient: apiClient,
                pathOrUrl: product.image,
                width: double.infinity,
                height: 220,
                borderRadius: BorderRadius.circular(16),
                fallbackIcon: Icons.fastfood,
                memCacheWidth: 900,
                memCacheHeight: 600,
              ),

            Text(
              product.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            if (product.description != null &&
                product.description!.trim().isNotEmpty)
              Text(product.description!),

            const SizedBox(height: 16),

            if (product.category != null)
              Text('Category: ${product.category!.name}'),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () => _addToCart(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to cart'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _addToWishlist(context),
              icon: const Icon(Icons.favorite_border),
              label: const Text('Add to wishlist'),
            ),

            const SizedBox(height: 8),
            // Vendor button
            if (product.vendor != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VendorPublicPage(
                        apiClient: apiClient,
                        vendor: product.vendor!,
                        vendorId: product.vendor!.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront),
                label: const Text('View vendor'),
              ),

            const SizedBox(height: 18),

            // Reviews section (no authService pre-checks anymore)
            ProductReviewsSection(apiClient: apiClient, productId: product.id),
          ],
        ),
      ),
    );
  }
}

class ProductReviewsSection extends StatefulWidget {
  final ApiClient apiClient;
  final int productId;

  const ProductReviewsSection({
    super.key,
    required this.apiClient,
    required this.productId,
  });

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  late final ReviewService _reviewService;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _reviewService = ReviewService(apiClient: widget.apiClient);
    _loadReviews();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _reviewService.getReviewsForProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reviews.';
        _loading = false;
      });
    }
  }

  double _avgRating() {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return sum / _reviews.length;
  }

  Future<void> _openReviewDialog() async {
    final result = await showDialog<_ReviewDialogResult>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );

    if (result == null) return;

    setState(() => _submitting = true);

    try {
      await _reviewService.addOrUpdateReview(
        productId: widget.productId,
        rating: result.rating,
        comment: result.comment,
      );
      await _loadReviews();
      _snack('Review saved ✅');
    } on ApiException catch (e) {
      // 401 => not logged in
      if (e.statusCode == 401) {
        _snack('Please login to leave a review.');
      }
      // 403 => backend says user did not order (your controller returns 403)
      else if (e.statusCode == 403) {
        _snack(
          e.message.isNotEmpty
              ? e.message
              : 'You can only review products you ordered.',
        );
      } else {
        _snack(e.message.isNotEmpty ? e.message : 'Failed to save review.');
      }
    } catch (_) {
      _snack('Failed to save review.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgRating();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: _submitting ? null : _openReviewDialog,
              icon: const Icon(Icons.rate_review),
              label: Text(_submitting ? 'Submitting...' : 'Write'),
            ),
          ],
        ),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          )
        else ...[
          Row(
            children: [
              const Icon(Icons.star, size: 18),
              const SizedBox(width: 4),
              Text(
                avg > 0 ? avg.toStringAsFixed(1) : 'No rating yet',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text('(${_reviews.length})'),
            ],
          ),
          const SizedBox(height: 10),

          if (_reviews.isEmpty)
            const Text('No reviews yet. Be the first!')
          else
            Column(
              children: _reviews.map((r) {
                final dateText = r.createdAt != null
                    ? r.createdAt!.toLocal().toString().split('.').first
                    : '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.user.name),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < r.rating ? Icons.star : Icons.star_border,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.comment != null && r.comment!.trim().isNotEmpty)
                        Text(r.comment!),
                      if (dateText.isNotEmpty)
                        Text(
                          dateText,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------

class _ReviewDialogResult {
  final int rating;
  final String? comment;
  const _ReviewDialogResult({required this.rating, this.comment});
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(filled ? Icons.star : Icons.star_border),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _ReviewDialogResult(
                rating: _rating,
                comment: _commentCtrl.text.trim().isEmpty
                    ? null
                    : _commentCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
