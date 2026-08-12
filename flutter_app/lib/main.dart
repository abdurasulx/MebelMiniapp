import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_store.dart';
import 'cart_store.dart';
import 'likes_store.dart';
import 'locale_store.dart';
import 'location_store.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

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
        home: _ready ? const RootScreen() : const SplashScreen(),
      ),
    );
  }
}
