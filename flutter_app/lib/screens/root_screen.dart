import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import 'catalog_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'worker/worker_home_screen.dart';
import 'worker/worker_orders_screen.dart';

/// Web'dagi portal ajratish va iOS'dagi `RootView`ning Android'dagi mos
/// keladigan varianti: `appMode == worker` bo'lganda xaridor tablari o'rniga
/// usta paneli tablari ko'rsatiladi.
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
        : const [CatalogScreen(), OrdersScreen(), ProfileScreen()];

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
              icon: Icon(Icons.grid_view),
              label: 'Katalog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Buyurtmalarim',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ];

    final safeIndex = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
        items: items,
        selectedItemColor: const Color(0xFF4C2C24),
      ),
    );
  }
}
