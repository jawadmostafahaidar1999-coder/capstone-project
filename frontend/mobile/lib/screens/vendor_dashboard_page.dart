// lib/screens/vendor_dashboard_page.dart
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/vendor_dashboard_service.dart';
import '../models/vendor_dashboard.dart';

class VendorDashboardPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const VendorDashboardPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends State<VendorDashboardPage> {
  late final VendorDashboardService _service;

  VendorDashboard? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = VendorDashboardService(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getDashboard();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard';
        _loading = false;
      });
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : data == null
          ? const Center(child: Text('No data'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Text(
                    data.storeName.isNotEmpty ? data.storeName : 'My kitchen',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    'Total products',
                    data.totalProducts.toString(),
                    Icons.fastfood,
                  ),
                  _buildStatCard(
                    'Total orders',
                    data.totalOrders.toString(),
                    Icons.receipt_long,
                  ),
                  _buildStatCard(
                    'Pending orders',
                    data.pendingOrders.toString(),
                    Icons.pending_actions,
                  ),
                  _buildStatCard(
                    'Items sold',
                    data.totalItemsSold.toString(),
                    Icons.shopping_bag,
                  ),
                  _buildStatCard(
                    'Total revenue',
                    data.totalRevenue.toStringAsFixed(2),
                    Icons.attach_money,
                  ),
                  _buildStatCard(
                    'Rating',
                    data.ratingCount == 0
                        ? 'No reviews yet'
                        : '${data.ratingAvg.toStringAsFixed(1)} (${data.ratingCount} reviews)',
                    Icons.star,
                  ),
                ],
              ),
            ),
    );
  }
}
