import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

/// Katalog — qidiruv va to'liq mahsulot to'ri (iOS'dagi "Darix" uslubidagi
/// `ShopView` bilan bir xil vazifa; hero banner "Bosh sahifa" tabida).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _search = '';

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
      final page = await ApiClient.instance.get(
        '/products/',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
        auth: true,
      );
      setState(() => _products = page.results);
      if (mounted) context.read<LikesStore>().sync(page.results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    if (_search.trim().isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products
        .where(
          (p) =>
              p.nameUz.toLowerCase().contains(q) ||
              p.companyName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(child: _searchBar()),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 6),
                  child: Text(
                    '${_filtered.length} ta mahsulot',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8A7357),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.deep),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Mahsulot topilmadi',
                    style: TextStyle(color: Color(0xFF8A7357)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => ProductCard(product: _filtered[i]),
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Mahsulot yoki firma qidirish…',
          prefixIcon: Icon(Icons.search, color: Color(0xFF8A7357)),
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
