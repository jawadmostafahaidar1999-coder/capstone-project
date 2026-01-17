// lib/models/vendor_order.dart
import 'order.dart'; // for OrderItem

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class VendorOrderCustomer {
  final int id;
  final String name;
  final String email;

  VendorOrderCustomer({
    required this.id,
    required this.name,
    required this.email,
  });

  factory VendorOrderCustomer.fromJson(Map<String, dynamic> json) {
    return VendorOrderCustomer(
      id: (json['id'] as num?)?.toInt() ?? 0,

      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class VendorOrder {
  final int id;
  final double totalPrice; // full order total (for info)
  final String status;
  final DateTime? createdAt;
  final VendorOrderCustomer customer;
  final List<OrderItem> items; // only this vendor's items

  VendorOrder({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.customer,
    required this.items,
  });

  double get vendorTotal {
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return VendorOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,

      totalPrice: _parseDouble(json['total_price']),
      status: json['status'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      customer: VendorOrderCustomer.fromJson(
        json['customer'] as Map<String, dynamic>,
      ),
      items: itemsJson
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
