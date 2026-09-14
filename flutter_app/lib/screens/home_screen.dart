import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/offline_view.dart';
import '../widgets/product_card.dart';

/// Bosh sahifa — endi alohida "Katalog" tabi yo'q, bu ekranning o'zi
/// katalog vazifasini bajaradi: qidiruv (nom yoki rasm bo'yicha), "Top"
/// filtri, kategoriya bo'yicha filtr, kolleksiyalar/ommabop
/// mahsulotlar bannerlari va to'liq mahsulotlar to'ri — bittagina umumiy
/// holat (`_products`/`_categories`/filtrlar) asosida, ikkita alohida
/// so'rov/state o'rniga (avval Katalog alohida tab bo'lib, xuddi shu
/// `/products/` so'rovini ikkinchi marta, o'z holati bilan yuklardi).
/// `RootScreen`dagi `IndexedStack` bu ekranni tab almashtirilganda
/// yo'q qilmaydi — shuning uchun qidiruv/filtr/scroll holati va yuklangan
/// ro'yxat boshqa tabga o'tib qaytganda ham saqlanib qoladi, qayta
/// yuklanmaydi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _products = [];
  List<_Category> _categories = [];
  bool _loading = true;
  Object? _error;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategorySlug;
  // "Top tovarlar" — serverga `ordering=top` bilan qayta so'raladi (Katalog
  // sahifasidagi eski `_topOnly` bilan bir xil), shuning uchun boshqa
  // filtrlardan farqli, o'zgarganda `_load()` chaqiriladi.
  bool _topOnly = false;

  List<Product>? _imageResults;
  bool _imageSearching = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, String>{
        if (_topOnly) 'ordering': 'top',
      };
      final query = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
      final productsPage = await ApiClient.instance.get(
        '/products/$query',
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
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleTopOnly() {
    setState(() => _topOnly = !_topOnly);
    _load();
  }

  void _toggleCategory(String slug) {
    setState(() {
      _selectedCategorySlug = _selectedCategorySlug == slug ? null : slug;
    });
  }

  /// Qidiruv matni va/yoki tanlangan kategoriya bo'yicha — server tomonidan
  /// allaqachon olingan `_products`ning o'zidan mijoz tomonida filtrlanadi
  /// (bitta so'rov, bitta ro'yxat — ikkita alohida holat emas).
  List<Product> get _filtered {
    var items = _products;
    if (_selectedCategorySlug != null) {
      items = items.where((p) => p.categorySlug == _selectedCategorySlug).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items
          .where(
            (p) =>
                p.nameUz.toLowerCase().contains(q) ||
                p.companyName.toLowerCase().contains(q),
          )
          .toList();
    }
    return items;
  }

  bool get _isFiltering =>
      _query.isNotEmpty ||
      _selectedCategorySlug != null ||
      _imageResults != null ||
      _imageSearching;

  Future<void> _pickAndSearchByImage() async {
    final loc = context.read<LocaleStore>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(loc.t('home_camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(loc.t('home_gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageSearching = true;
      _imageError = null;
      _imageResults = null;
    });
    _searchCtrl.clear();
    try {
      final results = await ApiClient.instance.postMultipart(
        '/products/search-by-image/',
        (j) => (j as List).map((e) => Product.fromJson(e)).toList(),
        imageFieldName: 'image',
        imagePath: picked.path,
      );
      setState(() => _imageResults = results);
    } catch (e) {
      setState(() => _imageError = e.toString());
    } finally {
      setState(() => _imageSearching = false);
    }
  }

  void _clearImageSearch() {
    setState(() {
      _imageResults = null;
      _imageError = null;
    });
  }

  void _backToHome() {
    _searchCtrl.clear();
    setState(() => _selectedCategorySlug = null);
    _clearImageSearch();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && OfflineView.isNetworkError(_error) && _products.isEmpty) {
      return Scaffold(body: SafeArea(child: OfflineView(onRetry: _load)));
    }

    final loc = context.watch<LocaleStore>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            children: [
              _searchBar(loc),
              _filterChips(loc),
              if (_error != null && !OfflineView.isNetworkError(_error))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error.toString(),
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
                if (!_isFiltering && _categories.isNotEmpty) ...[
                  _sectionHeader(loc.t('home_collections'), loc.t('home_collections_subtitle')),
                  _collectionsRow(),
                  const SizedBox(height: 24),
                ],
                if (!_isFiltering && _products.isNotEmpty) ...[
                  _sectionHeader(loc.t('home_featured'), loc.t('home_featured_subtitle')),
                  _featuredRow(),
                  const SizedBox(height: 24),
                ],
                _productsSection(loc),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(LocaleStore loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: loc.t('catalog_search_hint'),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8A7357)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8A7357)),
                          onPressed: _searchCtrl.clear,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickAndSearchByImage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.deep,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(LocaleStore loc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ChoiceChip(
              avatar: Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: _topOnly ? AppColors.primary : AppColors.deep,
              ),
              label: Text(
                loc.t('home_top_products'),
                style: TextStyle(color: _topOnly ? AppColors.primary : AppColors.deep),
              ),
              selected: _topOnly,
              onSelected: (_) => _toggleTopOnly(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsSection(LocaleStore loc) {
    final items = _imageResults ?? _filtered;

    if (_imageSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Center(child: CircularProgressIndicator(color: AppColors.deep)),
      );
    }
    if (_imageError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_imageError!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _clearImageSearch, child: Text(loc.t('common_close'))),
          ],
        ),
      );
    }

    final isImageSearch = _imageResults != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isFiltering)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deep),
                  onPressed: _backToHome,
                  tooltip: loc.t('home_back_tooltip'),
                ),
                Expanded(
                  child: Text(
                    isImageSearch
                        ? '${items.length}${loc.t('home_similar_suffix')}'
                        : '${items.length}${loc.t('home_results_suffix')}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
                  ),
                ),
              ],
            ),
          )
        else
          _sectionHeader(loc.t('home_all_products'), '${items.length}${loc.t('home_products_suffix')}'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(loc.t('home_nothing_found'), style: const TextStyle(color: Color(0xFF8A7357))),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => ProductCard(product: items[i]),
            ),
          ),
      ],
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
          final selected = _selectedCategorySlug == c.slug;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleCategory(c.slug),
            child: SizedBox(
              width: 78,
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.deep
                          : AppColors.primary.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chair_rounded,
                      color: selected ? AppColors.primary : AppColors.deep,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.nameUz,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
}

class _Category {
  final String id;
  final String nameUz;
  final String slug;
  _Category({required this.id, required this.nameUz, required this.slug});
  factory _Category.fromJson(Map<String, dynamic> j) => _Category(
        id: j['id'],
        nameUz: j['name_uz'] ?? '',
        slug: j['slug'] ?? '',
      );
}
