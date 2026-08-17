import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_client.dart';
import 'auth_store.dart';
import 'cart_store.dart';
import 'likes_store.dart';
import 'locale_store.dart';
import 'location_store.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'widgets/offline_view.dart';

void main() {
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
    _auth.bootstrap().then((_) => setState(() => _ready = true));
    _auth.addListener(() {
      if (!_auth.isAuthenticated) _likes.clear();
    });
    _location.init();
    _cart.load();
    _locale.init();
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
/// `RootScreen` (tab menyusi bilan birga) butunlay to'liq ekranli
/// [OfflineView]ga almashadi, shu bilan foydalanuvchi oflaynda menyu,
/// katalog yoki profilga kira olmaydi (faqat "Qayta urinish" tugmasi ishlaydi).
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiClient.instance.isOffline,
      builder: (context, offline, child) {
        if (!offline) return child!;
        return Scaffold(
          body: SafeArea(
            child: OfflineView(onRetry: ApiClient.instance.checkConnectivity),
          ),
        );
      },
      child: const RootScreen(),
    );
  }
}
