class ApiResponse<T> {
  final bool status;
  final String message;
  final T? data;

  ApiResponse({required this.status, required this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    // Your backend uses "success": true, but we keep the field name "status"
    final rawStatus = json['success'] ?? json['status'];

    return ApiResponse(
      status: rawStatus is bool ? rawStatus : false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }
}
