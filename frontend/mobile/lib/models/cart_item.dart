// lib/models/cart_item.dart
import 'product.dart';

class CartItem {
  final int id;
  final int productId;
  final int quantity;
  final double subtotal;
  final Product product;

  CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.subtotal,
    required this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: (json['id'] as num?)?.toInt() ?? 0,

      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    );
  }
}

class CartData {
  final List<CartItem> items;
  final int totalQuantity;
  final double totalPrice;

  CartData({
    required this.items,
    required this.totalQuantity,
    required this.totalPrice,
  });

  factory CartData.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return CartData(
      items: itemsJson
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
