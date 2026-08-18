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
