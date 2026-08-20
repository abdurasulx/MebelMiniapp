import 'dart:async';

import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/offline_view.dart';

String _timeAgo(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'hozir';
  if (diff.inMinutes < 60) return '${diff.inMinutes} daq oldin';
  if (diff.inHours < 24) return '${diff.inHours} soat oldin';
  return '${diff.inDays} kun oldin';
}

/// Bell tugmasi — AppBar `actions`ga qo'yiladi, o'qilmagan sonini 30s'da
/// bir marta so'raydi va bosilganda [NotificationsScreen]ni ochadi.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});
  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCount() async {
    try {
      final resp = await ApiClient.instance.get(
        '/notifications/unread_count/',
        (j) => j as Map<String, dynamic>,
        auth: true,
      );
      if (mounted) setState(() => _count = resp['count'] ?? 0);
    } catch (_) {
      // jim o'tkazamiz
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        label: Text('$_count'),
        isLabelVisible: _count > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: 'Xabarnomalar',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        _loadCount();
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.instance.get(
        '/notifications/',
        (j) => Paginated<AppNotification>.fromJson(j, AppNotification.fromJson),
        auth: true,
      );
      setState(() => _items = page.results);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await ApiClient.instance.post('/notifications/${n.id}/mark_read/', (j) => j, auth: true);
      setState(() {
        _items = [
          for (final item in _items)
            if (item.id == n.id)
              AppNotification(
                id: item.id,
                notifType: item.notifType,
                notifTypeDisplay: item.notifTypeDisplay,
                title: item.title,
                body: item.body,
                isRead: true,
                createdAt: item.createdAt,
              )
            else
              item,
        ];
      });
    } catch (_) {
      // jim o'tkazamiz
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.instance.post('/notifications/mark_all_read/', (j) => j, auth: true);
      await _load();
    } catch (_) {
      // jim o'tkazamiz
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.isRead);
    if (!_loading && OfflineView.isNetworkError(_error) && _items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xabarnomalar')),
        body: OfflineView(onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xabarnomalar'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text("Hammasini o'qilgan qilish"),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(child: Text(_error.toString(), style: const TextStyle(color: Colors.red)))
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text('Hali xabarnoma yo\'q.', style: TextStyle(color: Colors.black54)),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          return ListTile(
                            onTap: () => _markRead(n),
                            tileColor: n.isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                            title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (n.body.isNotEmpty) Text(n.body),
                                const SizedBox(height: 2),
                                Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                              ],
                            ),
                            trailing: n.isRead ? null : const Icon(Icons.circle, size: 8, color: Colors.red),
                          );
                        },
                      ),
      ),
    );
  }
}
