import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'auth_store.dart';
import 'device_signature.dart';
import 'models.dart';
import 'screens/order_detail_screen.dart';
import 'screens/worker/worker_orders_screen.dart';

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

  /// `main.dart`dagi `MaterialApp.navigatorKey` shu bilan bog'lanadi —
  /// notification bosilganda (ilova fon/yopiq holatda bo'lsa ham)
  /// BuildContext'siz navigatsiya qilish uchun (qarang `_handleMessage`).
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Muhim xabarnomalar',
    description: 'Vazifa va buyurtma holati haqidagi bildirishnomalar',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _lastRegisteredToken;
  bool _initialized = false;
  // `onAuthChanged` har safar (login/logout) chaqirilganda yangilanadi —
  // `_route()` shu orqali bildirishnoma turiga mos rejimga (customer/usta)
  // avtomatik o'tkazadi, aks holda foydalanuvchi noto'g'ri rejimda qolib
  // ketardi (masalan "user" rejimida turib usta vazifasi bildirishnomasini
  // bosgach, orqaga qaytganda hamon "user" rejimida qolar edi).
  AuthStore? _auth;

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
      // MUHIM: ilova OLDINDA (foreground) ochiq bo'lganda FCM'ning o'zi
      // emas, pastdagi `onMessage` qo'lda shu mahalliy bildirishnomani
      // ko'rsatadi (chunki OS avtomatik chiqarmaydi) — lekin bu tugma
      // bosilganda hech qanday navigatsiya ulanmagan edi (payload ham
      // yuborilmagan edi), shuning uchun foreground holatida kelgan
      // bildirishnomani bosish HECH NARSA qilmasdi. Endi shu callback
      // orqali xuddi fon/yopiq holatdagi bilan bir xil marshrutlashga
      // ulanadi.
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
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
        // `_handleLocalNotificationTap` shu payload'ni o'qib, xuddi
        // fon/yopiq holatdagi bosishlar bilan bir xil marshrutlashni
        // ishlatadi (qarang `_route`).
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _lastRegisteredToken = null; // majburan qayta yuborish
      final deviceId = DeviceSignature.instance.deviceId;
      if (deviceId != null) _sendToken(deviceId, token);
    });

    // Notification Router (nwupdate.md §2.2): ilova FON holatida bo'lib,
    // foydalanuvchi bosganda ishga tushadi.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    // Ilova UMUMAN YOPIQ bo'lib, notification bosilishi orqali ochilgan
    // bo'lsa — shu holatni alohida tekshirish kerak (onMessageOpenedApp
    // bunday holatda ishga tushmaydi, chunki ilova hali "ochilmagan" edi).
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);
  }

  /// Notification bosilganda `data`dagi `type`ga qarab tegishli sahifaga
  /// o'tadi (nwupdate.md §2.2-2.3: payload faqat ROUTING uchun, haqiqiy
  /// ma'lumot API'dan qayta olinadi — eskirib qolgan bo'lishi mumkin).
  ///
  /// MUHIM (bilinib turgan soddalashtirish): hozircha "task_*" turlari
  /// aniq bitta vazifa sahifasiga emas, usta "Buyurtmalar" ro'yxatiga olib
  /// boradi (alohida bitta-vazifa-ID bo'yicha yuklaydigan ekran hali yo'q)
  /// — muddat torligi sababli. `order_status` esa `/orders/{id}/` orqali
  /// haqiqiy buyurtmani olib, to'g'ridan-to'g'ri uning tafsilot sahifasini
  /// ochadi.
  Future<void> _handleMessage(RemoteMessage message) => _route(message.data);

  /// Ilova OLDINDA (foreground) ochiq bo'lganda qo'lda ko'rsatilgan mahalliy
  /// bildirishnoma (`onMessage` -> `_localNotifications.show`) bosilganda
  /// chaqiriladi — `payload`da saqlangan `data`ni o'qib, xuddi fon/yopiq
  /// holatdagi bosish bilan bir xil marshrutlashga (`_route`) yuboradi.
  /// Buning ulanmaganligi avval shu holatda bosishni butunlay ishlamas
  /// qilgan edi.
  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      _route(data);
    } catch (_) {
      // Payload buzilgan bo'lsa — jim o'tkaziladi.
    }
  }

  /// `data`dagi `type`ga qarab tegishli sahifaga o'tadi (nwupdate.md
  /// §2.2-2.3: payload faqat ROUTING uchun, haqiqiy ma'lumot API'dan qayta
  /// olinadi — eskirib qolgan bo'lishi mumkin).
  ///
  /// MUHIM (bilinib turgan soddalashtirish): hozircha "task_*" turlari
  /// aniq bitta vazifa sahifasiga emas, usta "Buyurtmalar" ro'yxatiga olib
  /// boradi (alohida bitta-vazifa-ID bo'yicha yuklaydigan ekran hali yo'q)
  /// — muddat torligi sababli. `order_status` esa `/orders/{id}/` orqali
  /// haqiqiy buyurtmani olib, to'g'ridan-to'g'ri uning tafsilot sahifasini
  /// ochadi.
  Future<void> _route(Map<String, dynamic> data) async {
    final type = data['type'];
    // MUHIM: ilova YOPIQ holatda notification bosilib ochilganda,
    // `getInitialMessage()` natijasi `runApp()`dan OLDIN (main.dart) shu
    // funksiyaga uzatiladi — o'sha paytda `MaterialApp` hali qurilmagani
    // uchun `navigatorKey.currentState` doim `null` bo'lardi, navigatsiya
    // sababsiz bekor qilinib, foydalanuvchi shunchaki ilovaning standart
    // boshlang'ich ekranida (masalan usta paneli) qolib ketardi. Shu sabab
    // birinchi kadr chizilishini bir necha soniya kutamiz.
    var navigator = navigatorKey.currentState;
    for (var i = 0; navigator == null && i < 25; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      navigator = navigatorKey.currentState;
    }
    if (navigator == null) return;

    switch (type) {
      case 'order_status':
        // Bu — mijozning O'Z bozor xaridi haqidagi bildirishnoma
        // (`OrderDetailScreen` faqat shu kontekst uchun, qarang uning
        // docstringi) — "usta" rejimida turib bosilsa, avval "user"
        // rejimiga o'tkazamiz, aks holda orqaga qaytganda foydalanuvchi
        // hamon usta panelida qolib ketar edi.
        _auth?.setAppMode(AppMode.customer);
        final orderId = data['order_id'];
        if (orderId == null) return;
        try {
          final order = await ApiClient.instance.get(
            '/orders/$orderId/',
            (j) => Order.fromJson(j),
            auth: true,
          );
          navigator.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
        } catch (_) {
          // Buyurtma topilmadi/tarmoq xatosi — jim o'tkaziladi, foydalanuvchi
          // baribir Profil > "So'nggi buyurtmalar"dan qo'lda topa oladi.
        }
        break;
      case 'task_assigned':
      case 'task_available':
      case 'task_pool_open':
        // Aksincha — vazifaga oid bildirishnoma "user" rejimida turib
        // kelsa, avval "usta" rejimiga o'tkazamiz (mavjud lavozimlaridan
        // birini tanlab — allaqachon tanlangani bo'lsa o'shani saqlab
        // qoladi).
        final positions = _auth?.user?.positions ?? const [];
        if (positions.isNotEmpty) {
          final position = _auth!.activePosition != null && positions.contains(_auth!.activePosition)
              ? _auth!.activePosition!
              : positions.first;
          _auth?.enterWorkerMode(position);
        }
        navigator.push(MaterialPageRoute(builder: (_) => const WorkerOrdersScreen()));
        break;
    }
  }

  /// `AuthStore`ga listener sifatida ulanadi (qarang main.dart) — login/
  /// logout bo'lganda avtomatik chaqiriladi.
  Future<void> onAuthChanged(AuthStore auth) async {
    _auth = auth;
    if (!_initialized) return;
    final deviceId = DeviceSignature.instance.deviceId;
    if (deviceId == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (auth.isAuthenticated) {
      await _sendToken(deviceId, token);
    } else {
      _lastRegisteredToken = null;
      // MUHIM: signature'ni O'CHIRISH so'rov (unregister) ketishidan OLDIN
      // emas, KEYIN — chunki bu so'rovning o'zi hali "ro'yxatdan o'tgan"
      // holatda (backend'da hali mavjud) ketishi kerak, aks holda imzosiz
      // ketib, agar boshqa sabab bilan (masalan eski JWT) muvaffaqiyatsiz
      // bo'lsa ham baribir signature qatlami buzilmaydi.
      try {
        await ApiClient.instance.post(
          '/notifications/unregister_device/',
          (j) => j,
          body: {'device_id': deviceId},
        );
      } catch (_) {
        // Muhim emas — bu qurilma baribir hech kimga tegishli bo'lmay qoladi
        // (keyingi login shu tokenni yangi userga o'tkazadi).
      } finally {
        await DeviceSignature.instance.markUnregistered();
      }
    }
  }

  Future<void> _sendToken(String deviceId, String? token) async {
    if (token != null && _lastRegisteredToken == token) return;
    try {
      await ApiClient.instance.post(
        '/notifications/register_device/',
        (j) => j,
        body: {
          'device_id': deviceId,
          if (token != null) 'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'device_name': DeviceSignature.instance.deviceName,
          'vcode': DeviceSignature.instance.vcode,
        },
      );
      if (token != null) _lastRegisteredToken = token;
      await DeviceSignature.instance.markRegistered();
    } catch (_) {
      // Tarmoq xatosi — `_lastRegisteredToken` yangilanmagani uchun
      // keyingi `onAuthChanged`/`onTokenRefresh` chaqiruvida qayta uriniladi.
    }
  }
}
