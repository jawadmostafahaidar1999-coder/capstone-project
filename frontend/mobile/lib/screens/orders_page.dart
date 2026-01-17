// lib/screens/orders_page.dart
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../models/order.dart';

class OrdersPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const OrdersPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrderService _orderService;

  List<Order>? _orders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderService = OrderService(apiClient: widget.apiClient);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await _orderService.getMyOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s == 'pending') {
      return Colors.orange;
    } else if (s == 'paid' || s == 'completed' || s == 'delivered') {
      return Colors.green;
    } else if (s == 'cancelled') {
      return Colors.red;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : (orders == null || orders.isEmpty)
          ? const Center(child: Text('You have no orders yet'))
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
                          Text(
                            'Order #${order.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${order.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Row(
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
