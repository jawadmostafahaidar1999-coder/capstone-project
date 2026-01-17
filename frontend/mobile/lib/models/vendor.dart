class Vendor {
  final int id;
  final String storeName;
  final String? image;
  final String? bio;
  final double? rating;
  final String status;

  final String? address;
  final String? phone;
  final int? orderDurationMinutes;

  Vendor({
    required this.id,
    required this.storeName,
    this.image,
    this.bio,
    this.rating,
    required this.status,
    this.address,
    this.phone,
    this.orderDurationMinutes,
  });

  /// So UI can use vendor.description
  String? get description => bio;

  factory Vendor.fromJson(Map<String, dynamic> json) {
    double? parseRating;
    final rawRating = json['rating'];
    if (rawRating is num) {
      parseRating = rawRating.toDouble();
    } else if (rawRating is String) {
      parseRating = double.tryParse(rawRating);
    }

    return Vendor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      storeName: json['store_name'] as String? ?? '',
      image: json['image_url'] as String? ?? json['image'] as String?,
      // accept both keys:
      bio: (json['bio'] as String?) ?? (json['description'] as String?),
      rating: parseRating,
      status: json['status'] as String? ?? 'pending',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      orderDurationMinutes: (json['order_duration_minutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'image': image,
      'bio': bio,
      'rating': rating,
      'status': status,
      'address': address,
      'phone': phone,
      'order_duration_minutes': orderDurationMinutes,
    };
  }
}
