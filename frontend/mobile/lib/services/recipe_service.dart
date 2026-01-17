// lib/services/recipe_service.dart
import '../models/recipe.dart';
import 'api_client.dart';

class Paged<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;

  const Paged({
    required this.data,
    required this.currentPage,
    required this.lastPage,
  });
  bool get hasMore => currentPage < lastPage;
}

class RecipeService {
  final ApiClient api;
  RecipeService(this.api);

  Paged<T> _parsePaged<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = (json['data'] as List? ?? [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    return Paged<T>(
      data: list,
      currentPage: (meta['current_page'] ?? 1) as int,
      lastPage: (meta['last_page'] ?? 1) as int,
    );
  }

  Map<String, dynamic> _buildQuery({
    String? q,
    String? sort,
    int? page,
    int? perPage,
    int? categoryId,
    List<int>? tagIds,
    bool? verifiedOnly,
  }) {
    final query = <String, dynamic>{};

    if (q != null) query['q'] = q;
    if (sort != null) query['sort'] = sort;
    if (page != null) query['page'] = page;
    if (perPage != null) query['per_page'] = perPage;
    if (categoryId != null) query['category_id'] = categoryId;

    if (tagIds != null && tagIds.isNotEmpty) {
      for (var i = 0; i < tagIds.length; i++) {
        query['tag_ids[$i]'] = tagIds[i];
      }
    }

    if (verifiedOnly == true) query['verified_only'] = 1;

    return query;
  }

  Future<Paged<RecipeListItem>> fetchRecipes({
    String q = '',
    String sort = 'date',
    int page = 1,
    int perPage = 10,
    int? categoryId,
    List<int> tagIds = const [],
    bool verifiedOnly = false,
  }) async {
    final res = await api.get(
      '/recipes',
      query: _buildQuery(
        q: q,
        sort: sort,
        page: page,
        perPage: perPage,
        categoryId: categoryId,
        tagIds: tagIds,
        verifiedOnly: verifiedOnly,
      ),
      auth: true,
    );

    return _parsePaged(res, (j) => RecipeListItem.fromJson(j));
  }

  Future<Paged<RecipeListItem>> trendingWeek({
    int page = 1,
    int perPage = 10,
  }) async {
    final res = await api.get(
      '/recipes/trending/week',
      query: _buildQuery(page: page, perPage: perPage),
      auth: true,
    );
    return _parsePaged(res, (j) => RecipeListItem.fromJson(j));
  }

  Future<Paged<RecipeListItem>> myRecipes({
    int page = 1,
    int perPage = 10,
  }) async {
    final res = await api.get(
      '/recipes/mine',
      query: _buildQuery(page: page, perPage: perPage),
      auth: true,
    );
    return _parsePaged(res, (j) => RecipeListItem.fromJson(j));
  }

  Future<Paged<RecipeListItem>> myBookmarks({
    int page = 1,
    int perPage = 10,
  }) async {
    final res = await api.get(
      '/recipes/bookmarks',
      query: _buildQuery(page: page, perPage: perPage),
      auth: true,
    );
    return _parsePaged(res, (j) => RecipeListItem.fromJson(j));
  }

  Future<RecipeDetail> fetchRecipe(int id) async {
    final res = await api.get('/recipes/$id', auth: true);

    final dynamic raw = res['data'] ?? res; // <-- unwrap Laravel Resource
    final map = Map<String, dynamic>.from(raw as Map);

    return RecipeDetail.fromJson(map);
  }

  Future<RecipeDetail> createRecipe({
    required String title,
    String? description,
    String? coverImage,
    int? servings,
    int? prepMinutes,
    int? cookMinutes,
    String visibility = 'public',
    int? categoryId,
    List<int> tagIds = const [],
    required List<RecipeIngredientInput> ingredients,
    required List<RecipeStepInput> steps,
  }) async {
    final res = await api.post(
      '/recipes',
      auth: true,
      body: {
        'title': title,
        'description': description,
        'cover_image': coverImage,
        'servings': servings,
        'prep_minutes': prepMinutes,
        'cook_minutes': cookMinutes,
        'visibility': visibility,
        'category_id': categoryId,
        'tag_ids': tagIds,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
      },
    );
    return RecipeDetail.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<RecipeCategory>> categories() async {
    final res = await api.get('/recipe-categories');
    final list = (res['data'] as List? ?? []);
    return list
        .map((e) => RecipeCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeTag>> tags({String search = ''}) async {
    final res = await api.get('/recipe-tags', query: {'search': search});
    final list = (res['data'] as List? ?? []);
    return list
        .map((e) => RecipeTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> like(int recipeId) =>
      api.post('/recipes/$recipeId/like', auth: true);
  Future<Map<String, dynamic>> unlike(int recipeId) =>
      api.delete('/recipes/$recipeId/like', auth: true);
  Future<Map<String, dynamic>> bookmark(int recipeId) =>
      api.post('/recipes/$recipeId/bookmark', auth: true);
  Future<Map<String, dynamic>> unbookmark(int recipeId) =>
      api.delete('/recipes/$recipeId/bookmark', auth: true);

  Future<Paged<RecipeComment>> comments(int recipeId, {int page = 1}) async {
    final res = await api.get(
      '/recipes/$recipeId/comments',
      query: {'page': page},
      auth: true,
    );
    return _parsePaged(res, (j) => RecipeComment.fromJson(j));
  }

  Future<RecipeComment> addComment(
    int recipeId,
    String body, {
    int? parentId,
  }) async {
    final res = await api.post(
      '/recipes/$recipeId/comments',
      auth: true,
      body: {'body': body, if (parentId != null) 'parent_id': parentId},
    );
    return RecipeComment.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(int commentId) async {
    await api.delete('/recipes/comments/$commentId', auth: true);
  }

  Future<Map<String, dynamic>> upsertReview(
    int recipeId, {
    required int rating,
    String? body,
  }) {
    return api.post(
      '/recipes/$recipeId/review',
      auth: true,
      body: {'rating': rating, 'body': body},
    );
  }

  Future<Map<String, dynamic>> deleteMyReview(int recipeId) {
    return api.delete('/recipes/$recipeId/review', auth: true);
  }

  Future<Paged<RecipeReviewModel>> reviews(int recipeId, {int page = 1}) async {
    final res = await api.get(
      '/recipes/$recipeId/reviews',
      query: {'page': page},
      auth: true,
    );
    return _parsePaged(res, (j) => RecipeReviewModel.fromJson(j));
  }

  Future<void> deleteRecipe(int recipeId) async {
    await api.delete('/recipes/$recipeId', auth: true);
  }
}
