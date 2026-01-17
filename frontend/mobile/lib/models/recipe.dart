// lib/models/recipe_models.dart

class RecipeAuthor {
  final int id;
  final String name;
  final String role;
  final bool isVerifiedVendor;

  const RecipeAuthor({
    required this.id,
    required this.name,
    required this.role,
    required this.isVerifiedVendor,
  });

  factory RecipeAuthor.fromJson(Map<String, dynamic> j) => RecipeAuthor(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '') as String,
    role: (j['role'] ?? 'user') as String,
    isVerifiedVendor: j['is_verified_vendor'] == true,
  );
}

class RecipeCategory {
  final int id;
  final String name;
  final String slug;

  const RecipeCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory RecipeCategory.fromJson(Map<String, dynamic> j) => RecipeCategory(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '') as String,
    slug: (j['slug'] ?? '') as String,
  );
}

class RecipeTag {
  final int id;
  final String name;
  final String slug;

  const RecipeTag({required this.id, required this.name, required this.slug});

  factory RecipeTag.fromJson(Map<String, dynamic> j) => RecipeTag(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '') as String,
    slug: (j['slug'] ?? '') as String,
  );
}

class RecipeListItem {
  final int id;
  final String title;
  final String? description;

  final String? status; // pending|approved|rejected
  final String? visibility; // public|private
  final String? rejectionReason; // optional (owner/admin)
  final String? coverImage;

  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;

  final double ratingAvg;
  final int ratingCount;

  final int likesCount;
  final int bookmarksCount;
  final bool isLiked;
  final bool isBookmarked;

  final int likesWeekCount; // optional (trending)
  final DateTime? createdAt;

  final RecipeAuthor? author;
  final RecipeCategory? category;
  final List<RecipeTag> tags;

  const RecipeListItem({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.visibility,
    this.rejectionReason,
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.coverImage,
    required this.ratingAvg,
    required this.ratingCount,
    required this.likesCount,
    required this.bookmarksCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.likesWeekCount,
    required this.createdAt,
    required this.author,
    required this.category,
    required this.tags,
  });

  RecipeListItem copyWith({
    int? likesCount,
    int? bookmarksCount,
    bool? isLiked,
    bool? isBookmarked,
  }) {
    return RecipeListItem(
      id: id,
      title: title,
      description: description,
      status: status,
      visibility: visibility,
      rejectionReason: rejectionReason,
      servings: servings,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      likesCount: likesCount ?? this.likesCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      likesWeekCount: likesWeekCount,
      createdAt: createdAt,
      author: author,
      category: category,
      tags: tags,
    );
  }

  factory RecipeListItem.fromJson(Map<String, dynamic> j) => RecipeListItem(
    id: (j['id'] ?? 0) as int,
    title: (j['title'] ?? '') as String,
    description: j['description'] as String?,
    status: j['status'] as String?,
    visibility: j['visibility'] as String?,
    rejectionReason: j['rejection_reason'] as String?,
    servings: j['servings'] as int?,
    prepMinutes: j['prep_minutes'] as int?,
    cookMinutes: j['cook_minutes'] as int?,
    ratingAvg: (j['rating_avg'] ?? 0).toDouble(),
    ratingCount: (j['rating_count'] ?? 0) as int,
    likesCount: (j['likes_count'] ?? 0) as int,
    bookmarksCount: (j['bookmarks_count'] ?? 0) as int,
    isLiked: j['is_liked'] == true,
    isBookmarked: j['is_bookmarked'] == true,
    coverImage: j['cover_image']?.toString(),
    likesWeekCount: (j['likes_week_count'] ?? 0) is int
        ? (j['likes_week_count'] ?? 0) as int
        : 0,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String)
        : null,
    author: j['author'] != null
        ? RecipeAuthor.fromJson(j['author'] as Map<String, dynamic>)
        : null,
    category: j['category'] != null
        ? RecipeCategory.fromJson(j['category'] as Map<String, dynamic>)
        : null,
    tags: (j['tags'] as List? ?? [])
        .map((e) => RecipeTag.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class RecipeIngredientInput {
  final String name;
  final String? quantity;
  final String? unit;
  final String? note;

  const RecipeIngredientInput({
    required this.name,
    this.quantity,
    this.unit,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'note': note,
  };
}

class RecipeStepInput {
  final String text;
  final int? timerMinutes;

  const RecipeStepInput({required this.text, this.timerMinutes});

  Map<String, dynamic> toJson() => {
    'text': text,
    'timer_minutes': timerMinutes,
  };
}

class RecipeDetail extends RecipeListItem {
  final List<RecipeIngredientInput> ingredients;
  final List<RecipeStepInput> steps;

  const RecipeDetail({
    required super.id,
    required super.title,
    super.description,
    super.status,
    super.visibility,
    super.rejectionReason,
    super.servings,
    super.prepMinutes,
    super.cookMinutes,
    super.coverImage,
    required super.ratingAvg,
    required super.ratingCount,
    required super.likesCount,
    required super.bookmarksCount,
    required super.isLiked,
    required super.isBookmarked,
    required super.likesWeekCount,
    required super.createdAt,
    required super.author,
    required super.category,
    required super.tags,
    required this.ingredients,
    required this.steps,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> j) => RecipeDetail(
    id: (j['id'] ?? 0) as int,
    title: (j['title'] ?? '') as String,
    description: j['description'] as String?,
    status: j['status'] as String?,
    visibility: j['visibility'] as String?,
    rejectionReason: j['rejection_reason'] as String?,
    servings: j['servings'] as int?,
    prepMinutes: j['prep_minutes'] as int?,
    cookMinutes: j['cook_minutes'] as int?,
    ratingAvg: (j['rating_avg'] ?? 0).toDouble(),
    ratingCount: (j['rating_count'] ?? 0) as int,
    likesCount: (j['likes_count'] ?? 0) as int,
    bookmarksCount: (j['bookmarks_count'] ?? 0) as int,
    isLiked: j['is_liked'] == true,
    isBookmarked: j['is_bookmarked'] == true,
    coverImage: j['cover_image']?.toString(),
    likesWeekCount: (j['likes_week_count'] ?? 0) is int
        ? (j['likes_week_count'] ?? 0) as int
        : 0,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String)
        : null,
    author: j['author'] != null
        ? RecipeAuthor.fromJson(j['author'] as Map<String, dynamic>)
        : null,
    category: j['category'] != null
        ? RecipeCategory.fromJson(j['category'] as Map<String, dynamic>)
        : null,
    tags: (j['tags'] as List? ?? [])
        .map((e) => RecipeTag.fromJson(e as Map<String, dynamic>))
        .toList(),
    ingredients: (j['ingredients'] as List? ?? [])
        .map(
          (e) => RecipeIngredientInput(
            name: (e['name'] ?? '') as String,
            quantity: e['quantity'] as String?,
            unit: e['unit'] as String?,
            note: e['note'] as String?,
          ),
        )
        .toList(),
    steps: (j['steps'] as List? ?? [])
        .map(
          (e) => RecipeStepInput(
            text: (e['text'] ?? '') as String,
            timerMinutes: e['timer_minutes'] as int?,
          ),
        )
        .toList(),
  );
}

class MiniUser {
  final int id;
  final String name;
  const MiniUser({required this.id, required this.name});
  factory MiniUser.fromJson(Map<String, dynamic> j) =>
      MiniUser(id: (j['id'] ?? 0) as int, name: (j['name'] ?? '') as String);
}

class RecipeComment {
  final int id;
  final String body;
  final DateTime? createdAt;
  final MiniUser? user;
  final List<RecipeComment> replies;

  const RecipeComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.user,
    required this.replies,
  });

  factory RecipeComment.fromJson(Map<String, dynamic> j) => RecipeComment(
    id: (j['id'] ?? 0) as int,
    body: (j['body'] ?? '') as String,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String)
        : null,
    user: j['user'] != null
        ? MiniUser.fromJson(j['user'] as Map<String, dynamic>)
        : null,
    replies: (j['replies'] as List? ?? [])
        .map((e) => RecipeComment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class RecipeReviewModel {
  final int id;
  final int rating;
  final String? body;
  final DateTime? createdAt;
  final MiniUser? user;

  const RecipeReviewModel({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.user,
  });

  factory RecipeReviewModel.fromJson(Map<String, dynamic> j) =>
      RecipeReviewModel(
        id: (j['id'] ?? 0) as int,
        rating: (j['rating'] ?? 0) as int,
        body: j['body'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        user: j['user'] != null
            ? MiniUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
      );
}
