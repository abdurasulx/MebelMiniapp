import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_store.dart';
import 'screens/root_screen.dart';
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _auth.bootstrap().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: MaterialApp(
        title: 'Furniture Platform',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _ready
            ? const RootScreen()
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
