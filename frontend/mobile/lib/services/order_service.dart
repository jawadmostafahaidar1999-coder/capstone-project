// lib/services/order_service.dart
import '../models/order.dart';
import 'api_client.dart';

class OrderService {
  final ApiClient _api;

  OrderService({required ApiClient apiClient}) : _api = apiClient;

  Future<List<Order>> getMyOrders() async {
    final json = await _api.get('/orders', auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];

    return items.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> checkoutFromCart() async {
    final json = await _api.post(
      '/orders/checkout',
      auth: true,
      body: const {}, // nothing required for now
    );

    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Order.fromJson(data);
  }
}
