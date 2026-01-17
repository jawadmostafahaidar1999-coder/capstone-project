import '../models/product.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

class ProductService {
  final ApiClient _api;

  ProductService(this._api);

  Future<PaginatedResponse<Product>> getProducts({
    int page = 1,
    int perPage = 10,
    String? search,
    int? categoryId,
    int? vendorId,
    String sort = 'newest', // newest | price_asc | price_desc
  }) async {
    final json = await _api.get(
      '/products',
      query: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort': sort,
        if (categoryId != null) 'category_id': categoryId.toString(),
        if (vendorId != null) 'vendor_id': vendorId.toString(),
      },
    );

    return PaginatedResponse<Product>.fromJson(
      json,
      (obj) => Product.fromJson(obj as Map<String, dynamic>),
    );
  }
}
