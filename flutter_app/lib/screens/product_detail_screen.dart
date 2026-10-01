import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api_client.dart';
import '../cart_store.dart';
import '../locale_store.dart';
import '../model_cache.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/like_button.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'company_detail_screen.dart';

/// Mahsulot tafsiloti — avval rasmlar galereyasi ko'rsatiladi, 3D model
/// "3D ko'rish" tugmasi orqali talab bo'yicha alohida oynada ochiladi
/// (marketplace uslubi, `IZHAR`/`Uzum` kabi ilovalarga mos).
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  Product? _product;
  Variant? _selectedVariant;
  String? _error;
  int _galleryIndex = 0;
  final _galleryController = PageController();
  late final TabController _tabController;
  late final AnimationController _cartBtnAnimController;
  late final Animation<double> _cartBtnScale;
  bool _justAddedToCart = false;
  Timer? _addedResetTimer;
  List<Product> _recommended = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cartBtnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _cartBtnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _cartBtnAnimController,
        curve: Curves.easeInOut,
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _tabController.dispose();
    _cartBtnAnimController.dispose();
    _addedResetTimer?.cancel();
    super.dispose();
  }

  // Tanlangan variant o'zining alohida (tayyor) 3D modeliga ega bo'lsa —
  // shuni, aks holda mahsulotning umumiy modelini ishlatamiz (web'dagi
  // ProductDetail.jsx: `hasOwnModel`/`activeModel3d` bilan bir xil naqsh —
  // avval bu yerda unutilgan bo'lib, variant darajasidagi yuklangan
  // fayllar Flutter AR'da hech qachon ko'rinmas edi).
  Model3D? get _activeModel3d {
    final vm = _selectedVariant?.model3d;
    if (vm != null && vm.status == 'ready') return vm;
    return _product?.model3d;
  }

  Future<void> _load() async {
    try {
      final p = await ApiClient.instance.get(
        '/products/${widget.productId}/',
        (j) => Product.fromJson(j),
      );
      setState(() {
        _product = p;
        _selectedVariant = p.variants.isNotEmpty ? p.variants.first : null;
      });
      if (_activeModel3d?.glbUrl != null) {
        Model3DCacheManager.instance.prefetch(_activeModel3d!.glbUrl);
      }
      _loadRecommended(p);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// "Sizga yoqishi mumkin" — o'sha kategoriyadagi boshqa mahsulotlar
  /// (marketplace ilovalaridagi kabi, masalan Uzum). Kategoriya bo'lmasa
  /// (kamdan-kam) bo'lim ko'rsatilmaydi.
  Future<void> _loadRecommended(Product p) async {
    if (p.categorySlug == null) return;
    try {
      final page = await ApiClient.instance.get(
        '/products/?category=${p.categorySlug}&exclude=${p.id}',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
      );
      if (mounted) setState(() => _recommended = page.results);
    } catch (_) {
      // Muhim emas — bo'lim shunchaki bo'sh qoladi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final p = _product;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('product_title'))),
        body: Center(
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : const CircularProgressIndicator(color: AppColors.deep),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _gallery(p, loc),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nameUz,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _companyLink(context, p),
                  if (p.companyAddress?.isNotEmpty == true ||
                      p.companyViloyatDisplay != null) ...[
                    const SizedBox(height: 8),
                    _locationRow(p),
                  ],
                  const SizedBox(height: 20),
                  if (p.variants.isNotEmpty) ...[
                    Text(
                      loc.t('product_variant_label'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 0.6,
                        color: Color(0xFF8A7357),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.variants.map((v) {
                        final selected = _selectedVariant?.id == v.id;
                        return ChoiceChip(
                          label: Text(
                            v.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFFECC299)
                                  : const Color(0xFF4C2C24),
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedVariant = v);
                            if (_activeModel3d?.glbUrl != null) {
                              Model3DCacheManager.instance.prefetch(_activeModel3d!.glbUrl);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    if (_selectedVariant != null) _priceCard(loc),
                    if (_selectedVariant != null) ...[
                      const SizedBox(height: 12),
                      _addToCartButton(p, loc),
                    ],
                  ],
                  const SizedBox(height: 28),
                  _sectionTabs(loc),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) => _tabController.index == 0
                        ? _descriptionTab(p, loc)
                        : _characteristicsTab(p, loc),
                  ),
                ],
              ),
            ),
            if (_recommended.isNotEmpty) _recommendedSection(loc),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// "Tavsif" / "Xususiyatlar" — marketplace ilovalaridagi (Uzum va h.k.)
  /// odatiy naqsh. `TabBarView` o'rniga oddiy shart bilan almashtirilishi
  /// sababi: ekran butun sahifa `ListView` ichida (cheksiz balandlik),
  /// `TabBarView` esa chegaralangan balandlik talab qiladi.
  Widget _sectionTabs(LocaleStore loc) {
    return SizedBox(
      width: double.infinity,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.deep,
        unselectedLabelColor: const Color(0xFF8A7357),
        indicatorColor: AppColors.deep,
        dividerColor: AppColors.cardBorder,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        tabs: [
          Tab(text: loc.t('product_tab_description')),
          Tab(text: loc.t('product_tab_characteristics')),
        ],
      ),
    );
  }

  Widget _descriptionTab(Product p, LocaleStore loc) {
    if (p.description?.isNotEmpty != true) {
      return Text(
        loc.t('product_no_description'),
        style: const TextStyle(fontSize: 13, color: Color(0xFF8A7357)),
      );
    }
    return Text(
      p.description!,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B5A48), height: 1.5),
    );
  }

  Widget _characteristicsTab(Product p, LocaleStore loc) {
    final v = _selectedVariant;
    // O'lcham endi variantda qo'lda kiritiladigan (va hozir doim standart
    // 1x1x1 bo'lib qolgan) maydondan emas — 3D model faylining o'zidan
    // (geometriyadan) avtomatik hisoblangan haqiqiy o'lchamdan (`bbox_*`)
    // olinadi, shunda ko'rsatilgan raqam har doim ko'rinayotgan modelga
    // mos keladi. Model hali tayyor bo'lmasa (yuklanmagan/processing),
    // variantning o'z qiymatiga tushamiz.
    final model = _activeModel3d;
    final w = model?.bboxWidthValue ?? v?.widthValue;
    final h = model?.bboxHeightValue ?? v?.heightValue;
    final d = model?.bboxDepthValue ?? v?.depthValue;
    final rows = <(String, String)>[
      if (p.categoryName != null) (loc.t('product_char_category'), p.categoryName!),
      (loc.t('product_char_company'), p.companyName),
      if (v != null) (loc.t('product_char_material'), v.name),
      if (w != null && h != null && d != null)
        (
          loc.t('product_char_size'),
          '${(w * 100).round()}×${(h * 100).round()}×${(d * 100).round()} sm',
        ),
      if (p.colorTag?.isNotEmpty == true) (loc.t('product_char_color'), p.colorTag!),
    ];
    if (rows.isEmpty) {
      return Text(
        loc.t('product_no_characteristics'),
        style: const TextStyle(fontSize: 13, color: Color(0xFF8A7357)),
      );
    }
    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      r.$1,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  /// "Sizga yoqishi mumkin" — o'sha kategoriyadagi boshqa mahsulotlar
  /// gorizontal ro'yxatda (qarang `_loadRecommended`).
  Widget _recommendedSection(LocaleStore loc) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.t('product_recommended'),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                width: 150,
                child: ProductCard(product: _recommended[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery(Product p, LocaleStore loc) {
    final urls = p.galleryUrls;
    // Marketplace ilovalaridagi (Uzum va h.k.) kabi — avval qattiq 320px,
    // keyin kvadrat (1:1) edi, ikkalasi ham tor-uzun ekranda (masalan S20
    // Ultra) hali ham katta ko'rinardi. Endi kenglikning ~0.62 qismi —
    // 4:3ga yaqin nisbat, mazmun uchun ko'proq joy qoladi.
    final galleryHeight = MediaQuery.of(context).size.width * 0.62;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: SizedBox(
            height: galleryHeight,
            width: double.infinity,
            child: urls.isEmpty
                ? Container(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    child: const Center(
                      child: Icon(
                        Icons.chair_rounded,
                        size: 64,
                        color: AppColors.deep,
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _galleryController,
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                    itemBuilder: (_, i) => Image.network(
                      urls[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _circleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _cartCircleButton(context),
              const SizedBox(width: 8),
              LikeButton(productId: p.id, product: p),
              const SizedBox(width: 8),
              _circleButton(
                icon: Icons.ios_share_rounded,
                onTap: () => _share(p, loc),
              ),
            ],
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _galleryIndex ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _galleryIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        if (_activeModel3d?.glbUrl != null)
          Positioned(bottom: 12, right: 12, child: _view3dButton(p, loc)),
      ],
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.deep),
      ),
    );
  }

  Widget _view3dButton(Product p, LocaleStore loc) {
    return GestureDetector(
      onTap: () => _open3d(p, loc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.deep,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              loc.t('product_view_3d'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open3d(Product p, [LocaleStore? locStore]) {
    final loc = locStore ?? context.read<LocaleStore>();
    final model = _activeModel3d;
    if (model?.glbUrl == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => _Model3DViewerSheet(
          product: p,
          glbUrl: model!.glbUrl!,
          loc: loc,
        ),
      ),
    );
  }

  void _share(Product p, LocaleStore loc) {
    SharePlus.instance.share(
      ShareParams(
        text: '${p.nameUz} — ${p.companyName}${loc.t('product_share_suffix')}',
      ),
    );
  }

  Widget _locationRow(Product p) {
    final text = [
      if (p.companyViloyatDisplay != null) p.companyViloyatDisplay!,
      if (p.companyAddress?.isNotEmpty == true) p.companyAddress!,
    ].join(', ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(
          Icons.location_on_rounded,
          size: 15,
          color: Color(0xFF8A7357),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
          ),
        ),
      ],
    );
  }

  Widget _companyLink(BuildContext context, Product p) {
    final content = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 16,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            p.companyName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.secondary,
            ),
          ),
        ),
        if (p.companySlug != null)
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.secondary,
          ),
      ],
    );
    if (p.companySlug == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompanyDetailScreen(companySlug: p.companySlug!),
        ),
      ),
      child: content,
    );
  }

  Widget _cartCircleButton(BuildContext context) {
    final cartCount = context.watch<CartStore>().count;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: AppColors.deep,
            ),
          ),
          if (cartCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.deep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                child: Text(
                  cartCount > 99 ? '99+' : '$cartCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onAddToCart(Product p, LocaleStore loc) {
    HapticFeedback.mediumImpact();
    _cartBtnAnimController.forward().then((_) {
      if (mounted) _cartBtnAnimController.reverse();
    });

    context.read<CartStore>().addProduct(p, _selectedVariant!);

    _addedResetTimer?.cancel();
    setState(() => _justAddedToCart = true);
    _addedResetTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _justAddedToCart = false);
    });

    _showAddedToCartBanner(p, loc);
  }

  void _showAddedToCartBanner(Product p, LocaleStore loc) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final firstPhoto =
        p.imageUrl ?? (p.galleryUrls.isNotEmpty ? p.galleryUrls.first : null);
    final variantName = _selectedVariant?.name;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E1A15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product thumbnail with checkmark
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: firstPhoto != null
                          ? Image.network(
                              firstPhoto,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.chair_rounded,
                                color: AppColors.deep,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.chair_rounded,
                              color: AppColors.deep,
                              size: 24,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF27AE60),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Product Info & Title
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('cart_added_title'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.nameUz + (variantName != null ? ' ($variantName)' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // "Savatga o'tish" Button
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECC299), Color(0xFFDFC0A0)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFECC299).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.t('cart_view_button'),
                        style: const TextStyle(
                          color: AppColors.deep,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.deep,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addToCartButton(Product p, LocaleStore loc) {
    return ScaleTransition(
      scale: _cartBtnScale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _justAddedToCart
              ? const LinearGradient(
                  colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [AppColors.deep, Color(0xFF331C16)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: (_justAddedToCart
                      ? const Color(0xFF27AE60)
                      : AppColors.deep)
                  .withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onAddToCart(p, loc),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _justAddedToCart
                    ? Row(
                        key: const ValueKey('added'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Color(0xFF27AE60),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loc.t('cart_added_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('add'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 19,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loc.t('product_add_to_cart'),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceCard(LocaleStore loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.55),
            AppColors.primary.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.t('product_price_label'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF8A7357),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatSom(_selectedVariant!.basePriceValue.toStringAsFixed(0))} ${loc.t('currency_som')}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedVariant!.availableQuantity > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_selectedVariant!.availableQuantity}${loc.t('product_in_stock_suffix')}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              loc.t('product_out_of_stock_production'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A7357),
              ),
            ),
        ],
      ),
    );
  }
}

class _Model3DViewerSheet extends StatefulWidget {
  final Product product;
  final String glbUrl;
  final LocaleStore loc;

  const _Model3DViewerSheet({
    required this.product,
    required this.glbUrl,
    required this.loc,
  });

  @override
  State<_Model3DViewerSheet> createState() => _Model3DViewerSheetState();
}

class _Model3DViewerSheetState extends State<_Model3DViewerSheet>
    with SingleTickerProviderStateMixin {
  File? _cachedFile;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initModel();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initModel() async {
    // 1. Keshda bormi? (1ms ichida diskdan tekshiradi)
    final cached = await Model3DCacheManager.instance.getCachedFile(widget.glbUrl);
    if (cached != null && mounted) {
      setState(() => _cachedFile = cached);
      return;
    }

    // 2. Keshda bo'lmasa yuklab olamiz
    if (mounted) setState(() => _downloading = true);

    try {
      final file = await Model3DCacheManager.instance.getOrDownload(
        widget.glbUrl,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _downloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Widget _buildFlutterLoader(String loadingText) {
    final pct = (_downloadProgress * 100).toInt().clamp(0, 100);
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 86,
                    height: 86,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.deep),
                      backgroundColor: Color(0x33ECC299),
                    ),
                  ),
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.deep, Color(0xFF2E1A15)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deep.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'V',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              loadingText,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.deep,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 140,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EAE1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _downloadProgress.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.deep],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pct%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF8C6E63),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadingText = widget.loc.t('product_loading_3d');
    final String src = _cachedFile != null
        ? 'file://${_cachedFile!.path}'
        : widget.glbUrl;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.product.nameUz,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _downloading
                  ? _buildFlutterLoader(loadingText)
                  : ModelViewer(
                      key: ValueKey(src),
                      src: src,
                      alt: widget.product.nameUz,
                      autoRotate: true,
                      cameraControls: true,
                      backgroundColor: Colors.transparent,
                      loading: Loading.eager,
                      innerModelViewerHtml: _innerHtml(loadingText),
                      relatedCss: _relatedCss(),
                      relatedJs: _relatedJs(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _innerHtml(String loadingText) => '''
<div slot="progress-bar" style="display:none;"></div>
<div slot="poster" id="vida-poster" class="vida-loader">
  <div class="vida-loader-inner">
    <div class="vida-logo-wrap">
      <div class="vida-spinner"></div>
      <div class="vida-badge">
        <span class="vida-v">V</span>
      </div>
    </div>
    <div class="vida-title">$loadingText</div>
    <div class="vida-progress-wrap">
      <div id="vida-progress-bar" class="vida-progress-bar"></div>
    </div>
    <div id="vida-progress-val" class="vida-progress-val">0%</div>
  </div>
</div>
''';

  static String _relatedCss() => '''
#default-progress-bar { display: none !important; }
model-viewer::part(default-progress-bar) { display: none !important; }
.vida-loader {
  position: absolute;
  top: 0; left: 0; width: 100%; height: 100%;
  display: flex; align-items: center; justify-content: center;
  background: #ffffff;
  z-index: 100;
  transition: opacity 0.35s ease, visibility 0.35s ease;
  pointer-events: none;
  user-select: none;
  -webkit-user-select: none;
}
.vida-loader-inner {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 24px;
}
.vida-logo-wrap {
  position: relative; width: 90px; height: 90px;
  display: flex; align-items: center; justify-content: center;
  margin-bottom: 18px;
}
.vida-spinner {
  position: absolute; top: 0; left: 0; width: 90px; height: 90px;
  border-radius: 50%; box-sizing: border-box;
  border: 3px solid rgba(236, 194, 153, 0.35);
  border-top-color: #4C2C24;
  border-right-color: #ECC299;
  animation: vidaSpin 1.1s cubic-bezier(0.4, 0.1, 0.4, 1) infinite;
}
.vida-badge {
  width: 68px; height: 68px; border-radius: 50%;
  background: linear-gradient(145deg, #4C2C24 0%, #2E1A15 100%);
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 10px 25px rgba(76, 44, 36, 0.28), 0 2px 6px rgba(0,0,0,0.12);
  animation: vidaPulse 2s ease-in-out infinite alternate;
}
.vida-v {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  font-size: 36px; font-weight: 900; color: #ECC299;
  line-height: 1; text-shadow: 0 2px 4px rgba(0, 0, 0, 0.35);
  transform: translateY(-1px);
}
.vida-title {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 15px; font-weight: 700; color: #4C2C24;
  letter-spacing: 0.3px; margin-bottom: 12px;
}
.vida-progress-wrap {
  width: 140px; height: 6px; background: #F3EAE1;
  border-radius: 999px; overflow: hidden;
  box-shadow: inset 0 1px 2px rgba(76, 44, 36, 0.08);
}
.vida-progress-bar {
  width: 0%; height: 100%;
  background: linear-gradient(90deg, #ECC299 0%, #4C2C24 100%);
  border-radius: 999px; transition: width 0.12s ease-out;
}
.vida-progress-val {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 12px; font-weight: 700; color: #8C6E63;
  margin-top: 6px; letter-spacing: 0.5px;
}
@keyframes vidaSpin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
@keyframes vidaPulse {
  0% { transform: scale(0.96); box-shadow: 0 8px 20px rgba(76, 44, 36, 0.22); }
  100% { transform: scale(1.04); box-shadow: 0 12px 28px rgba(76, 44, 36, 0.38); }
}
''';

  static String _relatedJs() => '''
(function() {
  function initVida() {
    var v = document.querySelector('model-viewer');
    var p = document.getElementById('vida-poster');
    var bar = document.getElementById('vida-progress-bar');
    var val = document.getElementById('vida-progress-val');
    if (!v) return;

    v.addEventListener('progress', function(e) {
      var pct = Math.min(100, Math.max(0, Math.round((e.detail.totalProgress || 0) * 100)));
      if (bar) bar.style.width = pct + '%';
      if (val) val.innerText = pct + '%';
    });

    function finish() {
      if (!p) return;
      p.style.opacity = '0';
      p.style.visibility = 'hidden';
      setTimeout(function() {
        if (p && p.parentNode) p.parentNode.removeChild(p);
      }, 400);
    }

    v.addEventListener('load', finish);
    v.addEventListener('poster-dismissed', finish);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVida);
  } else {
    initVida();
  }
})();
''';
}
