class AppUser {
  final int id;
  final String name;
  final String email;
  final String? image;

  final String? role;
  final bool isVendor;

  final int? vendorId;
  final String? vendorStoreName;
  final String? vendorStatus;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    required this.isVendor,
    this.vendorId,
    this.vendorStoreName,
    this.vendorStatus,
    this.image,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] as Map<String, dynamic>?;

    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      isVendor: json['is_vendor'] as bool? ?? false,
      vendorId: (vendor?['id'] as num?)?.toInt(),
      vendorStoreName: vendor?['store_name'] as String?,
      vendorStatus: vendor?['status'] as String?,
      image: json['image'] as String?,
    );
  }

  bool get canSeeVendorProfile => isVendor;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'image': image,
      'role': role,
      'is_vendor': isVendor,
      'vendor': vendorId == null
          ? null
          : {
              'id': vendorId,
              'store_name': vendorStoreName,
              'status': vendorStatus,
            },
    };
  }
}
