import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../screens/notifications_page.dart';

class NotificationBell extends StatefulWidget {
  final ApiClient apiClient;
  const NotificationBell({super.key, required this.apiClient});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final NotificationService _service;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = NotificationService(apiClient: widget.apiClient);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final c = await _service.unreadCount();
      if (!mounted) return;
      setState(() => _count = c);
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationsPage(apiClient: widget.apiClient),
          ),
        );
        _refresh();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (_count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _count > 99 ? '99+' : '$_count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
