// lib/services/vendor_order_service.dart
import '../models/vendor_order.dart';
import 'api_client.dart';

class VendorOrderService {
  final ApiClient _api;

  VendorOrderService({required ApiClient apiClient}) : _api = apiClient;

  Future<List<VendorOrder>> getMyVendorOrders() async {
    final json = await _api.get('/vendor/orders', auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((e) => VendorOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorOrder> getVendorOrder(int id) async {
    final json = await _api.get('/vendor/orders/$id', auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return VendorOrder.fromJson(data);
  }
}
