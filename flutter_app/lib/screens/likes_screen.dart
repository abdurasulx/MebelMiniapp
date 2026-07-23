import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../likes_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

/// "Sevimlilar" — marketplace'lardagi kabi, serverda saqlangan sevimli
/// mahsulotlar ro'yxati (iOS'dagi `LikesView` bilan bir xil).
class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});
  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  List<Like> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.read<AuthStore>().isAuthenticated) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.instance.get(
        '/likes/',
        (j) => Paginated<Like>.fromJson(j, Like.fromJson),
        auth: true,
      );
      setState(() => _items = page.results);
      if (mounted)
        context.read<LikesStore>().sync(
          page.results.map((l) => l.productDetail).toList(),
        );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('Sevimlilar')),
      body: !isAuthenticated
          ? _emptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Sevimlilar uchun kiring',
              message:
                  'Yoqqan mahsulotlaringizni saqlash uchun Profil bo\'limidan tizimga kiring.',
            )
          : _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.deep),
            )
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _items.isEmpty
          ? _emptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Hali sevimli mahsulot yo\'q',
              message: 'Katalogdan yoqqan mahsulotni yurakcha bilan belgilang.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final like = _items[i];
                  return ProductCard(
                    product: like.productDetail,
                    onUnliked: () => setState(() => _items.removeAt(i)),
                  );
                },
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
            Icon(icon, size: 44, color: const Color(0xFF8A7357)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A7357)),
            ),
          ],
        ),
      ),
    );
  }
}
