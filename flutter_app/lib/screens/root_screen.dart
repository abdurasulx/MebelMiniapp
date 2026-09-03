import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../cart_store.dart';
import '../locale_store.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'home_screen.dart';
import 'likes_screen.dart';
import 'profile_screen.dart';
import 'worker/worker_home_screen.dart';
import 'worker/worker_orders_screen.dart';
import 'worker/worker_payslips_screen.dart';

/// Xaridor — Bosh sahifa / Katalog / Sevimlilar / Savat / Profil (savat
/// tabida checkout, buyurtma tarixi Profil ichida ko'rsatiladi);
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

    final cartCount = context.watch<CartStore>().count;
    final loc = context.watch<LocaleStore>();

    final tabs = isWorker
        ? const [
            WorkerHomeScreen(),
            WorkerOrdersScreen(),
            WorkerPayslipsScreen(),
            ProfileScreen(),
          ]
        : [
            const HomeScreen(),
            const CatalogScreen(),
            LikesScreen(visible: _index == 2),
            const CartScreen(),
            const ProfileScreen(),
          ];

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
            BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              label: 'Ish haqim',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ]
        : [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: loc.t('nav_home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_rounded),
              label: loc.t('nav_catalog'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_rounded),
              label: loc.t('nav_likes'),
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: const Icon(Icons.shopping_basket_rounded),
              ),
              label: loc.t('nav_cart'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_rounded),
              label: loc.t('nav_profile'),
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
