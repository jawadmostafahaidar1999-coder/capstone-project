// lib/services/review_service.dart
import '../models/review.dart';
import 'api_client.dart';

class ReviewService {
  final ApiClient _api;

  ReviewService({required ApiClient apiClient}) : _api = apiClient;

  Future<List<Review>> getReviewsForProduct(int productId) async {
    final json = await _api.get('/products/$productId/reviews', auth: false);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Review> addOrUpdateReview({
    required int productId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': rating.toString()};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }

    final json = await _api.post(
      '/products/$productId/reviews',
      auth: true,
      body: body,
    );

    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Review.fromJson(data);
  }

  Future<bool> canReviewForProduct(int productId) async {
    final json = await _api.get('/products/$productId/can-review', auth: true);
    final data = (json['data'] as Map<String, dynamic>?) ?? {};
    return data['can_review'] == true;
  }
}
