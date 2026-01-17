// lib/screens/vendor_orders_page.dart
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/vendor_order_service.dart';
import '../models/vendor_order.dart';
import '../services/api_client.dart' show ApiException;

class VendorOrdersPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const VendorOrdersPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  late final VendorOrderService _vendorOrderService;

  List<VendorOrder>? _orders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vendorOrderService = VendorOrderService(apiClient: widget.apiClient);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await _vendorOrderService.getMyVendorOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        if (e.statusCode == 403) {
          _error = 'You are not an approved vendor.';
        } else {
          _error = e.message;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load vendor orders';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s == 'pending') return Colors.orange;
    if (s == 'paid' || s == 'completed' || s == 'delivered')
      return Colors.green;
    if (s == 'cancelled') return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;

    return Scaffold(
      appBar: AppBar(title: const Text('Orders for my kitchen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : (orders == null || orders.isEmpty)
          ? const Center(child: Text('No orders for your products yet'))
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final createdAt = order.createdAt;
                  final dateText = createdAt != null
                      ? createdAt.toLocal().toString().split('.').first
                      : 'Unknown date';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Order #${order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            order.vendorTotal.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${order.customer.name}'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateText),
                              Chip(
                                label: Text(order.status),
                                backgroundColor: _statusColor(
                                  order.status,
                                  context,
                                ).withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: _statusColor(order.status, context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        const Divider(height: 1),
                        ...order.items.map((item) {
                          final product = item.product;
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              'Qty: ${item.quantity} · '
                              'Price: ${item.price.toStringAsFixed(2)}',
                            ),
                            trailing: Text(
                              item.total.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
