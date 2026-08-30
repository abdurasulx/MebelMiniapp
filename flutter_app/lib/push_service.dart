import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'auth_store.dart';

/// Ilova FON/YOPIQ holatida FCM xabari kelganda chaqiriladi — FlutterFire
/// talabiga ko'ra top-level (yoki static) va `@pragma('vm:entry-point')`
/// bilan belgilangan bo'lishi SHART (alohida background isolate'da ishga
/// tushadi). Qo'shimcha ishlov kerak emas — bu holatda OS o'zi
/// bildirishnomani tokchaga chiqaradi (qarang AndroidManifest'dagi
/// `default_notification_channel_id`/`default_notification_icon`).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Backend orqali yuborilgan push (FCM) xabarnomalarni boshqaradi:
/// - login bo'lganda qurilma tokenini backend'ga ro'yxatdan o'tkazadi
///   (`/notifications/register_device/`), logout bo'lganda o'chiradi;
/// - token yangilanganda (`onTokenRefresh`) qayta yuboradi;
/// - ilova OLDINDA (foreground) ochiq bo'lganda FCM avtomatik OS tokchasiga
///   chiqarmaydi — shu holatda qo'lda mahalliy bildirishnoma ko'rsatadi.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Muhim xabarnomalar',
    description: 'Vazifa va buyurtma holati haqidagi bildirishnomalar',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _lastRegisteredToken;
  bool _initialized = false;

  /// `main.dart`da `Firebase.initializeApp()`dan KEYIN, ilova to'liq
  /// ochilishidan oldin bir marta chaqiriladi.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Android 13+ da runtime ruxsat so'raladi (avtomatik rad javobi bo'lsa
    // ham xato chiqarmaydi — push shunchaki OS darajasida ko'rsatilmaydi).
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _lastRegisteredToken = null; // majburan qayta yuborish
      _sendToken(token);
    });
  }

  /// `AuthStore`ga listener sifatida ulanadi (qarang main.dart) — login/
  /// logout bo'lganda avtomatik chaqiriladi.
  Future<void> onAuthChanged(AuthStore auth) async {
    if (!_initialized) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    if (auth.isAuthenticated) {
      await _sendToken(token);
    } else {
      _lastRegisteredToken = null;
      try {
        await ApiClient.instance.post(
          '/notifications/unregister_device/',
          (j) => j,
          body: {'token': token},
        );
      } catch (_) {
        // Muhim emas — bu qurilma baribir hech kimga tegishli bo'lmay qoladi
        // (keyingi login shu tokenni yangi userga o'tkazadi).
      }
    }
  }

  Future<void> _sendToken(String token) async {
    if (_lastRegisteredToken == token) return;
    try {
      await ApiClient.instance.post(
        '/notifications/register_device/',
        (j) => j,
        body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
      _lastRegisteredToken = token;
    } catch (_) {
      // Tarmoq xatosi — `_lastRegisteredToken` yangilanmagani uchun
      // keyingi `onAuthChanged`/`onTokenRefresh` chaqiruvida qayta uriniladi.
    }
  }
}
