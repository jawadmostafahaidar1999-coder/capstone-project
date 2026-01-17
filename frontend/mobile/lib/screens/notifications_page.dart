import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final ApiClient apiClient;
  const NotificationsPage({super.key, required this.apiClient});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationService _service;

  bool _loading = true;
  String? _error;
  List<AppNotification> _items = [];

  @override
  void initState() {
    super.initState();
    _service = NotificationService(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markAll() async {
    await _service.markAllRead();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _items.isEmpty ? null : _markAll,
            child: const Text('Read all'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No notifications yet.')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final n = _items[i];
                        return ListTile(
                          leading: Icon(
                            n.isUnread
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                          ),
                          title: Text(n.title ?? 'Notification'),
                          subtitle: Text(n.body ?? ''),
                          trailing: n.isUnread
                              ? const Icon(Icons.circle, size: 10)
                              : null,
                          onTap: () async {
                            if (n.isUnread) {
                              await _service.markRead(n.id);
                              await _load();
                            }
                            // Later: use n.deeplink to navigate
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
