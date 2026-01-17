import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api;
  NotificationService({required ApiClient apiClient}) : _api = apiClient;

  Future<List<AppNotification>> fetch({String only = 'all'}) async {
    final json = await _api.get(
      '/notifications',
      auth: true,
      query: {'only': only, 'per_page': 50},
    );

    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = (data['items'] as List?) ?? [];

    return items
        .map(
          (e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<int> unreadCount() async {
    final json = await _api.get('/notifications/unread-count', auth: true);
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.post('/notifications/$id/read', auth: true);
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all', auth: true);
  }

  Future<void> delete(String id) async {
    await _api.delete('/notifications/$id', auth: true);
  }
}
