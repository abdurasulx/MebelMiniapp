import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../locale_store.dart';
import '../location_store.dart';
import '../models.dart';
import '../theme.dart';
import '../viloyat.dart';
import '../widgets/offline_view.dart';
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
  Object? _error;
  String _search = '';
  bool _topOnly = false;
  String? _appliedViloyat;

  final _searchCtrl = TextEditingController();
  List<Product>? _imageResults;
  bool _imageSearching = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _load();
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
      _appliedViloyat = location.viloyat;
      final params = <String, String>{
        if (location.lat != null && location.lng != null) ...{
          'lat': location.lat!.toString(),
          'lng': location.lng!.toString(),
        } else if (_appliedViloyat != null) 'viloyat': _appliedViloyat!,
        if (_topOnly) 'ordering': 'top',
      };
      final query = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
      final page = await ApiClient.instance.get(
        '/products/$query',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
        auth: true,
      );
      setState(() => _products = page.results);
      if (mounted) context.read<LikesStore>().sync(page.results);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickViloyat() async {
    final location = context.read<LocationStore>();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Barchasi'),
              trailing: location.viloyat == null
                  ? const Icon(Icons.check, color: AppColors.deep)
                  : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded, size: 20),
              title: const Text('GPS orqali aniqlash'),
              onTap: () => Navigator.pop(ctx, '__gps__'),
            ),
            const Divider(height: 1),
            ...viloyatlar.map(
              (v) => ListTile(
                title: Text(v.label),
                trailing: location.viloyat == v.code
                    ? const Icon(Icons.check, color: AppColors.deep)
                    : null,
                onTap: () => Navigator.pop(ctx, v.code),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__gps__') {
      await location.detectFromGps();
    } else {
      await location.setViloyat(selected.isEmpty ? null : selected);
    }
    _load();
  }

  List<Product> get _filtered {
    if (_imageResults != null) return _imageResults!;
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
      _search = '';
    });
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

  void _clearImageSearch() => setState(() {
    _imageResults = null;
    _imageError = null;
  });

  void _backToHome() {
    _searchCtrl.clear();
    setState(() => _search = '');
    _clearImageSearch();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('catalog_title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(child: _searchBar(loc)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _filterChips()),
            ),
            if (_imageResults != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deep),
                          onPressed: _backToHome,
                          tooltip: 'Tozalash',
                        ),
                        Expanded(
                          child: Text(
                            'Rasmga o\'xshash ${_imageResults!.length} ta mahsulot',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
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
            if (_loading || _imageSearching)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.deep),
                ),
              )
            else if (_imageError != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_imageError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        TextButton(onPressed: _clearImageSearch, child: const Text('Yopish')),
                      ],
                    ),
                  ),
                ),
              )
            else if (OfflineView.isNetworkError(_error))
              SliverFillRemaining(child: OfflineView(onRetry: _load))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _error.toString(),
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
                    childAspectRatio: 0.62,
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

  Widget _filterChips() {
    final location = context.watch<LocationStore>();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: location.status == LocationStatus.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.place_rounded, size: 16, color: AppColors.deep),
              label: Text(
                location.viloyatLabelText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: AppColors.deep,
                ),
              ),
              onPressed: _pickViloyat,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: _topOnly ? AppColors.primary : AppColors.deep,
              ),
              label: Text(
                'Top tovarlar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: _topOnly ? AppColors.primary : AppColors.deep,
                ),
              ),
              selected: _topOnly,
              onSelected: (v) {
                setState(() => _topOnly = v);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(LocaleStore loc) {
    return Row(
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
              onChanged: (v) => setState(() {
                _search = v;
                if (v.isNotEmpty) _imageResults = null;
              }),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: loc.t('catalog_search_hint'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8A7357)),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF8A7357)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
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
    );
  }
}
