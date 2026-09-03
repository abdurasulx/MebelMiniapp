import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

/// Bildirishnoma qo'ng'irog'i sonini real vaqtda yangilash — avval har
/// 30s'da bir marta `/notifications/unread_count/` so'ralardi (qarang
/// notifications_screen.dart::_NotificationBellButtonState eski tarixi),
/// endi backend `apps/notifications/consumers.py`ga WebSocket orqali
/// ulanadi. Ulanish uzilsa (tarmoq, token muddati va h.k.) eksponensial
/// orqaga chekinish bilan qayta ulanadi — token har safar QAYTA
/// (`ApiClient.instance.accessToken`) o'qiladi, shunda orada yangilangan
/// bo'lsa ham eskirgan token bilan sinamaydi.
class NotificationSocket {
  final void Function(int count) onCount;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _stopped = false;
  Duration _retryDelay = const Duration(seconds: 1);
  Timer? _retryTimer;

  NotificationSocket({required this.onCount});

  static String _wsUrl(String token) {
    final httpBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final wsBase = httpBase
        .replaceFirst(RegExp(r'^https'), 'wss')
        .replaceFirst(RegExp(r'^http'), 'ws');
    return '$wsBase/ws/notifications/?token=${Uri.encodeComponent(token)}';
  }

  void start() {
    _stopped = false;
    _connect();
  }

  void _connect() {
    if (_stopped) return;
    final token = ApiClient.instance.accessToken;
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl(token)));
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _sub = _channel!.stream.listen(
      (raw) {
        _retryDelay = const Duration(seconds: 1);
        try {
          final data = jsonDecode(raw as String);
          if (data['type'] == 'unread_count') {
            onCount(data['count'] ?? 0);
          }
        } catch (_) {
          // buzuq xabar — jim o'tkaziladi
        }
      },
      onDone: _scheduleRetry,
      onError: (_) => _scheduleRetry(),
      cancelOnError: true,
    );
  }

  void _scheduleRetry() {
    if (_stopped) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _connect);
    final nextMs = (_retryDelay.inMilliseconds * 2).clamp(1000, 30000);
    _retryDelay = Duration(milliseconds: nextMs);
  }

  void stop() {
    _stopped = true;
    _retryTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }
}
