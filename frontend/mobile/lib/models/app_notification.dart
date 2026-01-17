class AppNotification {
  final String id;
  final String? type;
  final String? title;
  final String? body;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? deeplink;
  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.type,
    this.title,
    this.body,
    this.payload,
    this.deeplink,
    this.readAt,
    this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    DateTime? _dt(String? s) =>
        (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

    return AppNotification(
      id: j['id'].toString(),
      type: j['type']?.toString(),
      title: j['title']?.toString(),
      body: j['body']?.toString(),
      payload: (j['payload'] is Map)
          ? (j['payload'] as Map).cast<String, dynamic>()
          : null,
      deeplink: (j['deeplink'] is Map)
          ? (j['deeplink'] as Map).cast<String, dynamic>()
          : null,
      readAt: _dt(j['read_at']?.toString()),
      createdAt: _dt(j['created_at']?.toString()),
    );
  }
}
