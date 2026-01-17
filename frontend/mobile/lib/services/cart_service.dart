// lib/services/cart_service.dart
import '../models/cart_item.dart';
import 'api_client.dart';

class CartService {
  final ApiClient _api;

  CartService({required ApiClient apiClient}) : _api = apiClient;

  Future<CartData> getCart() async {
    final json = await _api.get('/cart', auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return CartData.fromJson(data);
  }

  Future<CartData> addToCart({required int productId, int quantity = 1}) async {
    await _api.post(
      '/cart',
      auth: true,
      body: {
        'product_id': productId.toString(),
        'quantity': quantity.toString(),
      },
    );
    // re-fetch to get updated totals
    return getCart();
  }

  Future<CartData> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) async {
    await _api.put(
      '/cart/$cartItemId',
      auth: true,
      body: {'quantity': quantity.toString()},
    );
    return getCart();
  }

  Future<CartData> removeItem(int cartItemId) async {
    await _api.delete('/cart/$cartItemId', auth: true);
    return getCart();
  }

  Future<CartData> clearCart() async {
    await _api.delete('/cart/clear', auth: true);
    return getCart();
  }
}
