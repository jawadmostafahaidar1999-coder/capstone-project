import 'category.dart';
import 'vendor.dart';

class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? image;

  // ✅ ADD THIS
  final String status;

  final bool isOffer;
  final DateTime? offerEndsAt;

  final Category? category;
  final Vendor? vendor;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.image,

    // ✅ ADD THIS (default keeps old constructor calls working)
    this.status = 'active',

    this.isOffer = false,
    this.offerEndsAt,
    this.category,
    this.vendor,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawOffer = json['is_offer'];
    final bool offer = rawOffer == true || rawOffer == 1 || rawOffer == '1';

    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      price:
          (json['price'] as num?)?.toDouble() ??
          double.tryParse('${json['price']}') ??
          0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      image: (json['image_url'] as String?) ?? (json['image'] as String?),

      // ✅ ADD THIS
      status: (json['status'] as String?) ?? 'active',

      isOffer: offer,
      offerEndsAt: json['offer_ends_at'] == null
          ? null
          : DateTime.tryParse(json['offer_ends_at'].toString()),
      category: json['category'] is Map
          ? Category.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
      vendor: json['vendor'] is Map
          ? Vendor.fromJson(Map<String, dynamic>.from(json['vendor']))
          : null,
    );
  }
}
