// lib/models/order.dart
import 'product.dart';

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class OrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price; // unit price at order time
  final double total; // quantity * price
  final Product product;

  OrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,

      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      price: _parseDouble(json['price']),
      total: _parseDouble(json['total']),
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    );
  }
}

class Order {
  final int id;
  final double totalPrice;
  final String status;
  final DateTime? createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return Order(
      id: (json['id'] as num?)?.toInt() ?? 0,

      totalPrice: _parseDouble(json['total_price']),
      status: json['status'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      items: itemsJson
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
