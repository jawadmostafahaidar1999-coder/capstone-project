import '../models/vendor.dart';
import 'api_client.dart' show ApiClient, ApiException;

class VendorService {
  final ApiClient _api;

  VendorService(this._api);

  Future<Vendor?> getMyVendor() async {
    try {
      final json = await _api.get('/vendors/me', auth: true);

      // 🔎 DEBUG
      // You will see this in your Flutter debug console
      // when opening "My vendor profile" (owner mode).
      // Remove these prints later if you want.
      // ignore: avoid_print
      print('GET /vendors/me response: $json');

      dynamic data = json['data'];

      if (data is Map<String, dynamic> &&
          data['vendor'] is Map<String, dynamic>) {
        data = data['vendor'];
      }

      if (data == null && (json['id'] != null || json['store_name'] != null)) {
        data = json;
      }

      if (data == null) {
        // ignore: avoid_print
        print('getMyVendor: data is null → returning null');
        return null;
      }

      if (data is Map<String, dynamic>) {
        final v = Vendor.fromJson(data);
        // ignore: avoid_print
        print('getMyVendor: parsed vendor id=${v.id}, store=${v.storeName}');
        return v;
      }

      // ignore: avoid_print
      print('getMyVendor: data type not Map → $data');
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403) {
        // ignore: avoid_print
        print('getMyVendor: ApiException ${e.statusCode} → returning null');
        return null;
      }
      rethrow;
    }
  }

  Future<Vendor> clearVendorImage({required int vendorId}) async {
    final json = await _api.put(
      '/vendors/$vendorId',
      auth: true,
      body: {'image': null}, // IMPORTANT: send the key with null
    );
    return Vendor.fromJson((json['data'] as Map).cast<String, dynamic>());
  }

  /// POST /vendors  (create vendor / send request)
  ///
  /// You can call it with:
  /// - description: "My kitchen ..." (preferred from Flutter)
  /// - OR bio: "My kitchen ..." (older code)
  Future<Vendor?> createVendor({
    required String storeName,
    String? description, // <-- from Flutter forms
    String? bio, // <-- legacy / alternative name
    String? image,
    String? address,
    String? phone,
    int? orderDurationMinutes,
  }) async {
    // Prefer description if provided, otherwise fall back to bio
    final String? effectiveBio;
    if (description != null && description.trim().isNotEmpty) {
      effectiveBio = description.trim();
    } else if (bio != null && bio.trim().isNotEmpty) {
      effectiveBio = bio.trim();
    } else {
      effectiveBio = null;
    }

    final body = <String, dynamic>{'store_name': storeName};

    if (effectiveBio != null) {
      body['description'] = effectiveBio;
    }
    if (image != null && image.trim().isNotEmpty) {
      body['image'] = image.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      body['address'] = address.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (orderDurationMinutes != null) {
      body['order_duration_minutes'] = orderDurationMinutes;
    }

    final json = await _api.post('/vendors', auth: true, body: body);

    if (json['success'] == true && json['data'] != null) {
      return Vendor.fromJson(json['data'] as Map<String, dynamic>);
    }

    return null;
  }

  /// PUT /vendors/{id}  (update vendor profile)
  ///
  /// Used by the new VendorProfilePage "Profile" tab.
  Future<Vendor> updateVendorProfile({
    required int vendorId,
    String? storeName,
    String? description, // maps to `bio` in backend
    String? image,
    String? address,
    String? phone,
    int? orderDurationMinutes,
  }) async {
    final body = <String, dynamic>{};

    if (storeName != null && storeName.trim().isNotEmpty) {
      body['store_name'] = storeName.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    if (image != null && image.trim().isNotEmpty) {
      body['image'] = image.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      body['address'] = address.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (orderDurationMinutes != null) {
      body['order_duration_minutes'] = orderDurationMinutes;
    }

    final json = await _api.put('/vendors/$vendorId', auth: true, body: body);

    if (json['success'] == true && json['data'] != null) {
      return Vendor.fromJson(json['data'] as Map<String, dynamic>);
    }

    // 2xx but backend says success=false → throw
    throw ApiException(
      400,
      json['message']?.toString() ?? 'Failed to update vendor',
      json,
    );
  }
}
