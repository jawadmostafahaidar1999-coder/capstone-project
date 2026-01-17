// lib/services/wishlist_service.dart
import '../models/product.dart';
import '../models/vendor.dart';
import 'api_client.dart';

class WishlistService {
  final ApiClient _api;

  WishlistService({required ApiClient apiClient}) : _api = apiClient;

  // ---------- PRODUCTS ----------
  Future<List<Product>> getWishlist() async {
    final json = await _api.get('/wishlist', auth: true);
    final data = (json['data'] as Map<String, dynamic>?) ?? {};

    // Support either: data.items OR data.products (future-proof)
    final items =
        (data['items'] as List?) ?? (data['products'] as List?) ?? const [];

    return items
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> addToWishlist(int productId) async {
    await _api.post(
      '/wishlist',
      auth: true,
      body: {'product_id': productId.toString()},
    );
  }

  Future<void> removeFromWishlist(int productId) async {
    await _api.delete('/wishlist/$productId', auth: true);
  }

  // ---------- VENDORS / STORES ----------
  Future<List<Vendor>> getFavoriteVendors() async {
    final json = await _api.get('/wishlist/vendors', auth: true);
    final data = (json['data'] as Map<String, dynamic>?) ?? {};

    // Support either: data.items OR data.vendors (future-proof)
    final items =
        (data['items'] as List?) ?? (data['vendors'] as List?) ?? const [];

    return items
        .whereType<Map>()
        .map((e) => Vendor.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> addVendorToFavorites(int vendorId) async {
    await _api.post(
      '/wishlist/vendors',
      auth: true,
      body: {'vendor_id': vendorId.toString()},
    );
  }

  Future<void> removeVendorFromFavorites(int vendorId) async {
    await _api.delete('/wishlist/vendors/$vendorId', auth: true);
  }
}
