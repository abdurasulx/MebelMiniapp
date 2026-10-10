import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../likes_store.dart';
import '../locale_store.dart';
import '../location_store.dart';
import '../models.dart';
import '../category_icons.dart';
import '../theme.dart';
import '../widgets/offline_view.dart';
import '../widgets/product_card.dart';
import 'showcase_screen.dart';
import '../net_image.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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

  LocationStore? _location;
  String? _loadedFor; // qaysi koordinata uchun ro'yxat yuklangan

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _location = context.read<LocationStore>()..addListener(_onLocationChanged);
    _load();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location?.removeListener(_onLocationChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Foydalanuvchi tizim sozlamalaridan joylashuvga ruxsat berib qaytsa —
  /// qo'lda "Qayta urinish" bosmasdan avtomatik qayta aniqlanadi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final loc = _location;
    if (state == AppLifecycleState.resumed &&
        loc != null &&
        !loc.hasFix &&
        loc.status != LocationStatus.loading) {
      loc.detectFromGps();
    }
  }

  /// Joylashuv aniqlanganda (yoki o'zgarganda) ro'yxatni qayta yuklaydi.
  void _onLocationChanged() {
    final loc = _location;
    if (!mounted || loc == null) return;
    if (loc.hasFix && _loadedFor != '${loc.lat},${loc.lng}') {
      _load();
    } else if (!loc.hasFix && _products.isNotEmpty) {
      setState(() => _products = []);
      _loadedFor = null;
    }
  }

  Future<void> _load() async {
    final location = _location;
    // Joylashuvsiz mahsulotlar ko'rsatilmaydi (firmalar xizmat radiusi
    // bor) — GPS aniqlanguncha yoki ruxsat berilmaguncha so'rov yuborilmaydi.
    if (location == null || !location.hasFix) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, String>{
        if (_topOnly) 'ordering': 'top',
        'lat': location.lat!.toString(),
        'lng': location.lng!.toString(),
      };
      final loadedFor = '${location.lat},${location.lng}';
      _loadedFor = loadedFor;
      final query = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
      final productsPage = await ApiClient.instance.get(
        '/products/$query',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
        auth: true,
        cache: true,
        onRefresh: (page) {
          if (!mounted || _loadedFor != loadedFor) return;
          setState(() => _products = page.results);
          context.read<LikesStore>().sync(page.results);
        },
      );
      final categoriesPage = await ApiClient.instance.get(
        '/categories/',
        (j) => Paginated<_Category>.fromJson(j, _Category.fromJson),
        cache: true,
        onRefresh: (page) {
          if (mounted) setState(() => _categories = page.results);
        },
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
      items =
          items.where((p) => p.categorySlug == _selectedCategorySlug).toList();
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
      _imageResults = null;
    });
    _searchCtrl.clear();
    try {
      final results = await ApiClient.instance.postMultipart(
        '/products/search-by-image/',
        (j) => (j as List).map((e) => Product.fromJson(e)).toList(),
        imageFieldName: 'image',
        imagePath: picked.path,
        fields: {
          if (_location?.hasFix ?? false) 'lat': _location!.lat!.toString(),
          if (_location?.hasFix ?? false) 'lng': _location!.lng!.toString(),
        },
      );
      setState(() => _imageResults = results);
    } catch (e) {
      if (mounted) {
        _showImageSearchErrorModal(context, loc);
      }
    } finally {
      if (mounted) {
        setState(() => _imageSearching = false);
      }
    }
  }

  void _clearImageSearch() {
    setState(() {
      _imageResults = null;
    });
  }

  void _showImageSearchErrorModal(BuildContext context, LocaleStore loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.t('image_search_error_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('image_search_error_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      loc.t('common_close'),
                      style: const TextStyle(
                        color: AppColors.deep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickAndSearchByImage();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deep,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      loc.t('auth_resend'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final location = context.watch<LocationStore>();

    if (!location.hasFix) {
      return Scaffold(body: SafeArea(child: _locationGate(loc, location)));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            children: [
              _searchBar(loc),
              _filterChips(loc),
              if (_error != null &&
                  !OfflineView.isNetworkError(_error) &&
                  !_loading)
                _errorBanner(loc),
              if (_loading)
                const _HomeSkeleton()
              else ...[
                if (!_isFiltering && _categories.isNotEmpty) ...[
                  _sectionHeader(loc.t('home_collections'),
                      loc.t('home_collections_subtitle')),
                  _collectionsRow(),
                  const SizedBox(height: 24),
                ],
                if (!_isFiltering && _products.isNotEmpty) ...[
                  _sectionHeader(
                      loc.t('home_featured'), loc.t('home_featured_subtitle')),
                  _featuredRow(),
                  const SizedBox(height: 24),
                ],
                if (!_isFiltering && _products.isEmpty && _error == null)
                  _stateMessage(
                    icon: Icons.storefront_outlined,
                    title: loc.t('showcase_prompt_title'),
                    body: loc.t('showcase_prompt_body'),
                    actionLabel: loc.t('showcase_prompt_button'),
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShowcaseScreen()),
                    ),
                  )
                else
                  _productsSection(loc),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(LocaleStore loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _error.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.errorDark, fontSize: 13),
              ),
            ),
            TextButton(onPressed: _load, child: Text(loc.t('loc_retry'))),
          ],
        ),
      ),
    );
  }

  /// Kategoriya nomi/slug'idagi kalit so'zga qarab ikonka (backend'da ikonka
  /// maydoni yo'q); topilmasa — umumiy mebel ikonkasi.
  IconData _categoryIcon(_Category c) =>
      categoryIcon(slug: c.slug, name: c.nameUz);

  /// Joylashuv hali aniqlanmagan / ruxsat yo'q / GPS o'chiq holati.
  Widget _locationGate(LocaleStore loc, LocationStore location) {
    final checking = location.status == LocationStatus.idle ||
        location.status == LocationStatus.loading ||
        (location.status == LocationStatus.granted && !location.hasFix);
    if (checking) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.deep));
    }
    final gpsOff = location.status == LocationStatus.unavailable;
    return _stateMessage(
      icon: Icons.location_off_outlined,
      title: loc.t(gpsOff ? 'loc_gps_off_title' : 'loc_required_title'),
      body: loc.t(gpsOff ? 'loc_gps_off_body' : 'loc_required_body'),
      actionLabel: loc.t(
        gpsOff || location.permanentlyDenied
            ? 'loc_open_settings'
            : 'loc_allow',
      ),
      onAction: () async {
        if (gpsOff || location.permanentlyDenied) {
          await location.openSettings();
        } else {
          await location.detectFromGps();
        }
      },
      secondaryLabel: loc.t('loc_retry'),
      onSecondary: location.detectFromGps,
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.deep),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deep),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deep,
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            if (secondaryLabel != null)
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
          ],
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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: loc.t('catalog_search_hint'),
                  hintMaxLines: 1,
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary),
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _pickAndSearchByImage,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.onBrand),
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
                style: TextStyle(
                    color: _topOnly ? AppColors.primary : AppColors.deep),
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
      return const _HomeSkeleton(showCategories: false);
    }

    final isImageSearch = _imageResults != null;

    // Qidiruv natijalari sarlavhasi: nima qidirilgani + natijalar soni.
    String? categoryName;
    if (_selectedCategorySlug != null) {
      for (final c in _categories) {
        if (c.slug == _selectedCategorySlug) categoryName = c.nameUz;
      }
    }
    final resultsTitle = isImageSearch
        ? '${items.length}${loc.t('home_similar_suffix')}'
        : (_query.isNotEmpty ? '“$_query”' : (categoryName ?? ''));
    final resultsCount = '${items.length}${loc.t('home_results_suffix')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isFiltering)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.brand),
                  onPressed: _backToHome,
                  tooltip: loc.t('home_back_tooltip'),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sectionTitle.copyWith(fontSize: 16),
                      ),
                      if (!isImageSearch)
                        Text(resultsCount, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          _sectionHeader(loc.t('home_all_products'),
              '${items.length}${loc.t('home_products_suffix')}'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_off_rounded,
                      size: 34, color: AppColors.brand),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  loc.t('home_nothing_found'),
                  textAlign: TextAlign.center,
                  style: AppText.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _backToHome,
                  child: Text(loc.t('home_back_tooltip')),
                ),
              ],
            ),
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
            style: AppText.sectionTitle,
          ),
          Text(
            subtitle,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                      color:
                          selected ? AppColors.brand : AppColors.backgroundAlt,
                      shape: BoxShape.circle,
                    ),
                    // Backend kategoriya rasmini bersa — rasm (qirqilgan doira), aks holda ikonka.
                    child: c.imageUrl != null && c.imageUrl!.isNotEmpty
                        ? ClipOval(
                            child: netImage(
                              c.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                _categoryIcon(c),
                                color: selected
                                    ? AppColors.onBrand
                                    : AppColors.brand,
                                size: 28,
                              ),
                            ),
                          )
                        : Icon(
                            _categoryIcon(c),
                            color:
                                selected ? AppColors.onBrand : AppColors.brand,
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
      height: 268,
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
  final String? imageUrl;
  _Category(
      {required this.id,
      required this.nameUz,
      required this.slug,
      this.imageUrl});
  factory _Category.fromJson(Map<String, dynamic> j) => _Category(
        id: j['id'],
        nameUz: j['name_uz'] ?? '',
        slug: j['slug'] ?? '',
        imageUrl: j['image_url'],
      );
}

/// Yuklanish paytidagi skelet: kategoriya doiralari va mahsulot kartalari o'rnida
/// yumshoq, "nafas oluvchi" bloklar (bo'sh ekran va aylanuvchi indikator o'rniga).
class _HomeSkeleton extends StatefulWidget {
  final bool showCategories;
  const _HomeSkeleton({this.showCategories = true});

  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _box(
      {double? width,
      double height = 12,
      double radius = AppRadius.sm,
      BoxShape shape = BoxShape.rectangle}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showCategories) ...[
              _box(width: 140, height: 18),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => Column(
                    children: [
                      _box(width: 64, height: 64, shape: BoxShape.circle),
                      const SizedBox(height: 6),
                      _box(width: 48, height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            _box(width: 160, height: 18),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
              children: List.generate(
                4,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _box(
                              height: double.infinity, radius: AppRadius.md)),
                      const SizedBox(height: AppSpacing.md),
                      _box(height: 12),
                      const SizedBox(height: 6),
                      _box(width: 70, height: 10),
                      const SizedBox(height: 8),
                      _box(width: 90, height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
