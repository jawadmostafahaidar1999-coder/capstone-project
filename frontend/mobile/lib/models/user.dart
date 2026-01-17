class User {
  final int id;
  final String name;
  final String email;
  final String? role; // 'user', 'admin', etc.
  final bool? isVendor; // if your API sends something like is_vendor
  final String? vendorStatus; // 'pending', 'approved', etc. (optional)

  User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.isVendor,
    this.vendorStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Adjust field names to whatever your Laravel AuthController returns
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      isVendor:
          json['is_vendor'] as bool? ??
          (json['vendor'] != null), // fallback if vendor relation exists
      vendorStatus: json['vendor_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_vendor': isVendor,
      'vendor_status': vendorStatus,
    };
  }
}
