import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../locale_store.dart';
import '../models.dart';
import '../notification_ws.dart';
import '../widgets/employee_invitation_sheet.dart';
import '../widgets/offline_view.dart';
import 'order_detail_screen.dart';
import 'worker/worker_orders_screen.dart';
import '../theme.dart';

/// Bell tugmasi — AppBar `actions`ga qo'yiladi, o'qilmagan sonini
/// WebSocket orqali real vaqtda oladi (avval 30s'da bir marta HTTP bilan
/// so'ralardi, qarang notification_ws.dart) va bosilganda
/// [NotificationsScreen]ni ochadi.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});
  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _count = 0;
  NotificationSocket? _socket;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _socket = NotificationSocket(onCount: (c) {
      if (mounted) setState(() => _count = c);
    })
      ..start();
  }

  @override
  void dispose() {
    _socket?.stop();
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
    final loc = context.watch<LocaleStore>();
    return IconButton(
      icon: Badge(
        label: Text('$_count'),
        isLabelVisible: _count > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: loc.t('notif_title'),
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
      await ApiClient.instance
          .post('/notifications/${n.id}/mark_read/', (j) => j, auth: true);
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
                orderId: item.orderId,
                workflowInstanceId: item.workflowInstanceId,
              )
            else
              item,
        ];
      });
    } catch (_) {
      // jim o'tkazamiz
    }
  }

  /// Backend `NotificationViewSet.get_queryset` "erkin topshiriq"
  /// (TASK_POOL_OPEN) turidagi eskirgan (boshqa usta olib ulgurgan yoki
  /// bosqich holati o'zgargan) xabarnomalarni chiqarib tashlaydi — shu
  /// bir xil filtrdan retrieve orqali ham foydalanamiz: agar shu ID endi
  /// ko'rinmasa (404), demak eskirgan.
  Future<bool> _stillOpen(AppNotification n) async {
    try {
      await ApiClient.instance
          .get('/notifications/${n.id}/', (j) => j, auth: true);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _open(AppNotification n) async {
    await _markRead(n);
    switch (n.notifType) {
      case 'employee_invited':
        if (!mounted) return;
        await showEmployeeInvitationSheet(context);
        break;
      case 'order_status':
        if (n.orderId == null) return;
        try {
          final order = await ApiClient.instance.get(
            '/orders/${n.orderId}/',
            (j) => Order.fromJson(j),
            auth: true,
          );
          if (!mounted) return;
          context.read<AuthStore>().setAppMode(AppMode.customer);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
          );
        } catch (_) {
          // Buyurtma topilmadi/tarmoq xatosi — jim o'tkaziladi.
        }
        break;
      case 'task_assigned':
      case 'task_available':
      case 'task_pool_open':
        // "Erkin topshiriq" bir nechta ustaga BIR VAQTDA yuboriladi, lekin
        // faqat bittasi qabul qila oladi — boshqa usta olib ulgurgan yoki
        // bosqich holati o'zgargan bo'lsa, bu yerda hech qayerga ochilmaydi,
        // ro'yxatdan olib tashlanadi ("g'oyib bo'ladi").
        if (n.notifType == 'task_pool_open') {
          final stillOpen = await _stillOpen(n);
          if (!stillOpen) {
            if (mounted) {
              setState(
                  () => _items = _items.where((x) => x.id != n.id).toList());
            }
            return;
          }
        }
        // task_assigned/task_available uchun — bosqichning ANIQ qaysi
        // buyurtmaga tegishli ekanini olib, to'g'ridan-to'g'ri o'sha
        // buyurtmani ochamiz (aks holda ro'yxat filtrida ko'rinmasligi
        // mumkin, qarang WorkerOrdersScreen._isActiveForMe).
        String? orderId;
        if (n.notifType != 'task_pool_open' && n.workflowInstanceId != null) {
          try {
            final step = await ApiClient.instance.get(
              '/workflow-instances/${n.workflowInstanceId}/',
              (j) => WorkflowStepInstance.fromJson(j),
              auth: true,
            );
            orderId = step.order;
          } catch (_) {
            // Bosqich topilmadi/tarmoq xatosi — umumiy ro'yxatga o'tamiz.
          }
        }
        if (!mounted) return;
        final auth = context.read<AuthStore>();
        final positions = auth.user?.positions ?? const [];
        if (positions.isNotEmpty) {
          final position = auth.activePosition != null &&
                  positions.contains(auth.activePosition)
              ? auth.activePosition!
              : positions.first;
          auth.enterWorkerMode(position);
        }
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => WorkerOrdersScreen(openOrderId: orderId)),
        );
        break;
    }
  }

  /// Bo'sh/xato holat: RefreshIndicator ishlashi uchun scrollable ichida markazda.
  Widget _centered({
    required IconData icon,
    required String title,
    Color iconColor = AppColors.brand,
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.xl, 80, AppSpacing.xl, 0),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: iconColor),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary, height: 1.4),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                action
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Bildirishnoma turiga mos ikonka (faqat backend bergan turlar; noma'lum tur — umumiy qo'ng'iroq).
  IconData _iconFor(String type) {
    switch (type) {
      case 'order_status':
        return Icons.inventory_2_outlined;
      case 'task_assigned':
      case 'task_available':
      case 'task_pool_open':
        return Icons.assignment_outlined;
      case 'employee_invited':
        return Icons.work_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Widget _tile(AppNotification n, LocaleStore loc) {
    final unread = !n.isRead;
    return Material(
      color: unread ? AppColors.card : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _open(n),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: unread
                    ? AppColors.brandSecondary.withValues(alpha: 0.35)
                    : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread
                      ? AppColors.backgroundAlt
                      : AppColors.disabledBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(n.notifType),
                  size: 20,
                  color: unread ? AppColors.brand : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14.5,
                        height: 1.25,
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(loc.timeAgo(n.createdAt),
                        style: AppText.caption
                            .copyWith(color: AppColors.textDisabled)),
                  ],
                ),
              ),
              if (unread)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm, top: 4),
                  child: Icon(Icons.circle, size: 9, color: AppColors.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.instance
          .post('/notifications/mark_all_read/', (j) => j, auth: true);
      await _load();
    } catch (_) {
      // jim o'tkazamiz
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final hasUnread = _items.any((n) => !n.isRead);
    if (!_loading && OfflineView.isNetworkError(_error) && _items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('notif_title'))),
        body: OfflineView(onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('notif_title')),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(loc.t('notif_mark_all_read')),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? _centered(
                    icon: Icons.error_outline_rounded,
                    iconColor: AppColors.error,
                    title: _error.toString(),
                    action: OutlinedButton(
                      onPressed: _load,
                      child: Text(loc.t('loc_retry')),
                    ),
                  )
                : _items.isEmpty
                    ? _centered(
                        icon: Icons.notifications_none_rounded,
                        title: loc.t('notif_empty'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => _tile(_items[i], loc),
                      ),
      ),
    );
  }
}
