class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PaginationMeta(
        currentPage: 1,
        lastPage: 1,
        perPage: 10,
        total: 0,
      );
    }
    return PaginationMeta(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'total': total,
    };
  }
}

class PaginatedResponse<T> {
  final bool status;
  final String message;
  final List<T> data;
  final PaginationMeta meta;

  const PaginatedResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.meta,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    // We support multiple shapes:
    // 1) { success/status, message, data: { items: [], meta: {} } }
    // 2) { success/status, message, data: [], meta: {} }
    // 3) { success/status, message, items: [], meta: {} }

    List<dynamic> itemsRaw = const [];
    Map<String, dynamic>? metaJson;

    final dataField = json['data'];

    if (dataField is List) {
      // shape 2
      itemsRaw = dataField;
      if (json['meta'] is Map<String, dynamic>) {
        metaJson = json['meta'] as Map<String, dynamic>;
      }
    } else if (dataField is Map<String, dynamic>) {
      // shape 1  -> your backend: data: { items: [], meta: {} }
      final innerItems = dataField['items'];
      if (innerItems is List) {
        itemsRaw = innerItems;
      }
      if (dataField['meta'] is Map<String, dynamic>) {
        metaJson = dataField['meta'] as Map<String, dynamic>;
      }
    } else if (json['items'] is List) {
      // shape 3
      itemsRaw = json['items'] as List<dynamic>;
      if (json['meta'] is Map<String, dynamic>) {
        metaJson = json['meta'] as Map<String, dynamic>;
      }
    }

    final list = itemsRaw.map((item) => fromJsonT(item)).toList();

    return PaginatedResponse(
      status: (json['status'] as bool?) ?? (json['success'] as bool?) ?? false,
      message: json['message'] as String? ?? '',
      data: list,
      meta: PaginationMeta.fromJson(metaJson),
    );
  }
}
