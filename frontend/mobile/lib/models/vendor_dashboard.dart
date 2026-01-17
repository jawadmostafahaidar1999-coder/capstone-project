// lib/models/vendor_dashboard.dart

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class VendorDashboard {
  final String storeName;
  final int totalProducts;
  final int totalOrders;
  final int totalItemsSold;
  final double totalRevenue;
  final int pendingOrders;
  final double ratingAvg;
  final int ratingCount;

  VendorDashboard({
    required this.storeName,
    required this.totalProducts,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory VendorDashboard.fromJson(Map<String, dynamic> json) {
    return VendorDashboard(
      storeName: json['store_name'] as String? ?? '',
      totalProducts: _parseInt(json['total_products']),
      totalOrders: _parseInt(json['total_orders']),
      totalItemsSold: _parseInt(json['total_items_sold']),
      totalRevenue: _parseDouble(json['total_revenue']),
      pendingOrders: _parseInt(json['pending_orders']),
      ratingAvg: _parseDouble(json['rating_avg']),
      ratingCount: _parseInt(json['rating_count']),
    );
  }
}
