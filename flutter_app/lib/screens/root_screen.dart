import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../cart_store.dart';
import '../locale_store.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'likes_screen.dart';
import 'profile_screen.dart';
import 'worker/worker_home_screen.dart';
import 'worker/worker_orders_screen.dart';
import 'worker/worker_payslips_screen.dart';

/// Xaridor — Bosh sahifa (endi katalog vazifasini ham bajaradi, qarang
/// home_screen.dart) / Sevimlilar / Savat / Profil (savat tabida
/// checkout, buyurtma tarixi Profil ichida ko'rsatiladi); `appMode ==
/// worker` bo'lganda usta paneli tablariga almashadi.
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
            LikesScreen(visible: _index == 1),
            const CartScreen(),
            const ProfileScreen(),
          ];

    final items = isWorker
        ? [
            BottomNavigationBarItem(
              icon: const Icon(Icons.handyman),
              label: loc.t('worker_panel_tab'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment),
              label: loc.t('worker_orders_tab'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.payments_outlined),
              label: loc.t('worker_payslip_tab'),
            ),
            BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.t('nav_profile')),
          ]
        : [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: loc.t('nav_home'),
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
