import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../location_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/offline_view.dart';
import '../widgets/product_card.dart';

/// Bosh sahifa — kolleksiyalar + ommabop mahsulotlar + qidiruv (nom yoki
/// rasm bo'yicha). Brend hero matni endi splash_screen.dart'da — bu yerda
/// bekorchi turmasin deb olib tashlandi.
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
      final location = context.read<LocationStore>();
      final params = <String, String>{
        if (location.lat != null && location.lng != null) ...{
          'lat': location.lat!.toString(),
          'lng': location.lng!.toString(),
        } else if (location.viloyat != null) 'viloyat': location.viloyat!,
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

  List<Product> get _nameMatches {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return _products
        .where(
          (p) =>
              p.nameUz.toLowerCase().contains(q) ||
              p.companyName.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _pickAndSearchByImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galereya'),
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
    _clearImageSearch();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && OfflineView.isNetworkError(_error) && _products.isEmpty) {
      return Scaffold(body: SafeArea(child: OfflineView(onRetry: _load)));
    }

    final searching = _query.isNotEmpty || _imageResults != null || _imageSearching;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            children: [
              _searchBar(),
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
              else if (searching)
                _searchResults()
              else ...[
                if (_categories.isNotEmpty) ...[
                  _sectionHeader('Kolleksiyalar', 'Har xona uchun'),
                  _collectionsRow(),
                  const SizedBox(height: 24),
                ],
                if (_products.isNotEmpty) ...[
                  _sectionHeader('Ommabop mahsulotlar', 'Eng ko\'p tanlangan'),
                  _featuredRow(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  hintText: 'Mahsulot yoki firma qidirish…',
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

  Widget _searchResults() {
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
            TextButton(onPressed: _clearImageSearch, child: const Text('Yopish')),
          ],
        ),
      );
    }

    final items = _imageResults ?? _nameMatches;
    final isImageSearch = _imageResults != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deep),
                onPressed: _backToHome,
                tooltip: 'Bosh sahifaga',
              ),
              Expanded(
                child: Text(
                  isImageSearch
                      ? '${items.length} ta o\'xshash mahsulot topildi'
                      : '${items.length} ta natija',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Hech narsa topilmadi.', style: TextStyle(color: Color(0xFF8A7357))),
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
}

class _Category {
  final String id;
  final String nameUz;
  _Category({required this.id, required this.nameUz});
  factory _Category.fromJson(Map<String, dynamic> j) =>
      _Category(id: j['id'], nameUz: j['name_uz'] ?? '');
}
