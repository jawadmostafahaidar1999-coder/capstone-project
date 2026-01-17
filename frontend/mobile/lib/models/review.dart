// lib/models/review.dart
class ReviewUser {
  final int id;
  final String name;

  ReviewUser({required this.id, required this.name});

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: (json['id'] as num?)?.toInt() ?? 0,

      name: json['name'] as String? ?? '',
    );
  }
}

class Review {
  final int id;
  final int rating; // 1–5
  final String? comment;
  final DateTime? createdAt;
  final ReviewUser user;

  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.user,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num?)?.toInt() ?? 0,

      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      user: ReviewUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
