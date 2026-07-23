import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import 'catalog_screen.dart';
import 'home_screen.dart';
import 'likes_screen.dart';
import 'profile_screen.dart';
import 'worker/worker_home_screen.dart';
import 'worker/worker_orders_screen.dart';

/// iOS'dagi `RootView` bilan **bir xil** tab tuzilishi: xaridor — Bosh sahifa /
/// Katalog / Sevimlilar / Profil (buyurtmalar Profil ichida ko'rsatiladi);
/// `appMode == worker` bo'lganda usta paneli tablariga almashadi.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final isWorker =
        auth.appMode == AppMode.worker && auth.user?.company != null;

    final tabs = isWorker
        ? const [WorkerHomeScreen(), WorkerOrdersScreen(), ProfileScreen()]
        : const [HomeScreen(), CatalogScreen(), LikesScreen(), ProfileScreen()];

    final items = isWorker
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.handyman),
              label: 'Usta paneli',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Buyurtmalar',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Bosh sahifa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Katalog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded),
              label: 'Sevimlilar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ];

    final safeIndex = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
        items: items,
      ),
    );
  }
}
