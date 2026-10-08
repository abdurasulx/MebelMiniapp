import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../likes_store.dart';
import '../locale_store.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

/// "Sevimlilar" — marketplace'lardagi kabi, serverda saqlangan sevimli
/// mahsulotlar ro'yxati (iOS'dagi `LikesView` bilan bir xil).
///
/// Bu ekran endi o'zining alohida ro'yxatini saqlamaydi — to'g'ridan-to'g'ri
/// `LikesStore.likedProducts`dan render qiladi. Boshqa ekranda (Bosh sahifa,
/// mahsulot sahifasi) LIKE/UNLIKE bosilganda `LikesStore.toggle()` shu
/// ro'yxatni darhol yangilaydi — Sevimlilar tabiga kirilganda serverdan
/// qayta so'ralmaydi (faqat birinchi marta, qarang `loadIfNeeded`), shuning
/// uchun hech qanday o'zgarish bo'lmasa tab qayta ochilganda "Loading..."
/// ko'rinmaydi.
class LikesScreen extends StatefulWidget {
  final bool visible;
  const LikesScreen({super.key, this.visible = true});
  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.read<AuthStore>().isAuthenticated) _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    setState(() => _loading = true);
    await context.read<LikesStore>().loadIfNeeded();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    await context.read<LikesStore>().reload();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    final loc = context.watch<LocaleStore>();
    final products = context.watch<LikesStore>().likedProducts;
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('likes_title'))),
      body: !isAuthenticated
          ? _emptyState(
              icon: Icons.favorite_border_rounded,
              title: loc.t('likes_login_title'),
              message: loc.t('likes_login_message'),
            )
          : _loading && products.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.deep),
                )
              : products.isEmpty
                  ? _emptyState(
                      icon: Icons.favorite_border_rounded,
                      title: loc.t('likes_empty_title'),
                      message: loc.t('likes_empty_message'),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, i) =>
                            ProductCard(product: products[i]),
                      ),
                    ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.backgroundAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.brand),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center, style: AppText.sectionTitle),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
