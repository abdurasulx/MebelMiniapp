import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import 'catalog_screen.dart';

/// Bosh sahifa — yirik marketplace uslubidagi landing (hero banner +
/// kolleksiyalar + ommabop mahsulotlar), iOS'dagi `HomeView` bilan bir xil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _products = [];
  List<_Category> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final productsPage = await ApiClient.instance.get(
        '/products/',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
        auth: true,
      );
      final categoriesPage = await ApiClient.instance.get(
        '/categories/',
        (j) => Paginated<_Category>.fromJson(j, _Category.fromJson),
      );
      setState(() {
        _products = productsPage.results;
        _categories = categoriesPage.results;
      });
      if (mounted) context.read<LikesStore>().sync(productsPage.results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _hero(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.deep),
                  ),
                )
              else ...[
                if (_categories.isNotEmpty) ...[
                  _sectionHeader('Kolleksiyalar', 'Har xona uchun'),
                  _collectionsRow(),
                  const SizedBox(height: 24),
                ],
                if (_products.isNotEmpty) ...[
                  _sectionHeader('Ommabop mahsulotlar', 'Eng ko\'p tanlangan'),
                  _featuredRow(),
                  const SizedBox(height: 24),
                ],
                _arBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, Color(0xFF6B4130)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deep.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MINIMAL VA FUNKSIONAL',
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Uyingizga\nqulaylik va hashamat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'O\'zbekistonning eng yaxshi mebel ustalari. O\'lchamingizga mos dizayn, uyingizga yetkazib berish.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CatalogScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xarid qilish',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.deep, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
          ),
        ],
      ),
    );
  }

  Widget _collectionsRow() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return SizedBox(
            width: 78,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chair_rounded,
                    color: AppColors.deep,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.nameUz,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _featuredRow() {
    final items = _products.length > 10 ? _products.sublist(0, 10) : _products;
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => SizedBox(
          width: 160,
          child: ProductCard(product: items[i]),
        ),
      ),
    );
  }

  Widget _arBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CatalogScreen()),
        ),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🧊 AR bilan sinab ko\'ring',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 260,
                child: Text(
                  'Xonangizga real o\'lchamda joylashtiring — sotib olishdan oldin ko\'zingiz bilan ko\'ring.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Category {
  final String id;
  final String nameUz;
  _Category({required this.id, required this.nameUz});
  factory _Category.fromJson(Map<String, dynamic> j) =>
      _Category(id: j['id'], nameUz: j['name_uz'] ?? '');
}
