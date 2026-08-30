import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_client.dart';
import 'auth_store.dart';
import 'cart_store.dart';
import 'likes_store.dart';
import 'locale_store.dart';
import 'location_store.dart';
import 'push_service.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'widgets/offline_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push (FCM) — `google-services.json` orqali avtomatik konfiguratsiya
  // qilinadi (Android'da alohida `FirebaseOptions` kerak emas). Xatoga
  // uchrasa (masalan fayl hali qo'yilmagan bo'lsa) ilova baribir ishga
  // tushishi kerak — push shunchaki ishlamay qoladi.
  try {
    await Firebase.initializeApp();
    await PushService.instance.init();
  } catch (_) {}
  runApp(const FurniturePlatformApp());
}

class FurniturePlatformApp extends StatefulWidget {
  const FurniturePlatformApp({super.key});
  @override
  State<FurniturePlatformApp> createState() => _FurniturePlatformAppState();
}

class _FurniturePlatformAppState extends State<FurniturePlatformApp> {
  final _auth = AuthStore();
  final _likes = LikesStore();
  final _location = LocationStore();
  final _cart = CartStore();
  final _locale = LocaleStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // To'liq bootstrap (tokenlarni o'qish + `/users/me/`) VPN kechikishiga
    // chidamli bo'lish uchun uzunroq timeout ishlatadi — oflaynda splash
    // shuncha vaqt osilib qolmasligi uchun, tezkor (qisqa timeout'li)
    // ulanish tekshiruvi bilan PARALLEL yuboriladi: qaysi biri OLDIN
    // tugasa, splash o'shanda yopiladi (ikkalasi ham bir marta
    // `setState`ni ishga tushiradi, keyingisi shunchaki e'tiborsiz qoladi).
    _auth.bootstrap().then((_) => _finishSplash());
    ApiClient.instance.probeConnectivity().then((_) => _finishSplash());
    _auth.addListener(() {
      if (!_auth.isAuthenticated) _likes.clear();
      PushService.instance.onAuthChanged(_auth);
    });
    _location.init();
    _cart.load();
    _locale.init();
  }

  void _finishSplash() {
    if (!_ready && mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _likes),
        ChangeNotifierProvider.value(value: _location),
        ChangeNotifierProvider.value(value: _cart),
        ChangeNotifierProvider.value(value: _locale),
      ],
      child: MaterialApp(
        title: 'Furniture Platform',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _ready ? const _AppGate() : const SplashScreen(),
      ),
    );
  }
}

/// Butun ilova ustidan global ulanish holatini kuzatadi — oflayn bo'lganda
/// to'liq ekranli [OfflineView] `RootScreen` USTIDAN qoplanadi (shu bilan
/// foydalanuvchi menyu/katalog/profilga kira olmaydi), lekin `RootScreen`ning
/// o'zi HECH QACHON yo'q qilinmaydi — aks holda (avvalgi versiyada bo'lgani
/// kabi) barcha tablarning keshlangan holati yo'qolib, ulanish tiklanganda
/// hammasi qaytadan "Loading..." holatidan boshlanardi (bitta tabning
/// birgina sekin so'rovi butun ilovani qayta tug'ilishga majburlardi).
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const RootScreen(),
        ValueListenableBuilder<bool>(
          valueListenable: ApiClient.instance.isOffline,
          builder: (context, offline, child) {
            if (!offline) return const SizedBox.shrink();
            return Scaffold(
              body: SafeArea(
                child: OfflineView(onRetry: ApiClient.instance.checkConnectivity),
              ),
            );
          },
        ),
      ],
    );
  }
}
