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
import '../widgets/dimension_box.dart';
import '../widgets/like_button.dart';
import '../widgets/price_block.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'company_detail_screen.dart';
import '../widgets/image_gallery_viewer.dart';

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
  late final AnimationController _cartBtnAnimController;
  late final Animation<double> _cartBtnScale;
  bool _justAddedToCart = false;
  int _qty = 1;
  bool _descExpanded = false;
  Timer? _addedResetTimer;
  List<Product> _recommended = [];

  @override
  void initState() {
    super.initState();
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
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppColors.error),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.errorDark),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _load();
                        },
                        child: Text(loc.t('loc_retry')),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final v = _selectedVariant;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _gallery(p, loc),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nameUz,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25),
                  ),
                  if (v != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _priceSection(v, loc),
                  ],
                  if (p.variants.length > 1) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _sectionTitle(loc.t('product_variant_label')),
                    const SizedBox(height: AppSpacing.sm),
                    _variantChips(p),
                  ],
                  _specsSection(p, loc),
                  _descriptionSection(p, loc),
                  const SizedBox(height: AppSpacing.lg),
                  _companyCard(context, p),
                  const SizedBox(height: AppSpacing.md),
                  _deliveryCard(p, loc),
                ],
              ),
            ),
            if (_recommended.isNotEmpty) _recommendedSection(loc),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: v == null ? null : _purchaseBar(p, v, loc),
    );
  }

  /// Yetkazib berish: firma shartlarini belgilagan bo'lsa narx va muddat,
  /// aks holda (backend `null`) — "firma bilan kelishiladi" (soxta qiymat ko'rsatilmaydi).
  Widget _deliveryCard(Product p, LocaleStore loc) {
    final d = p.delivery;
    final rows = <(String, String, bool)>[];
    if (d != null) {
      rows.add((
        loc.t('delivery_price_label'),
        d.free
            ? loc.t('delivery_free')
            : '${formatSom(d.price.toStringAsFixed(0))} ${loc.t('currency_som')}',
        d.free,
      ));
      if (d.maxDays > 0) {
        final days = d.minDays == d.maxDays
            ? '${d.maxDays}'
            : '${d.minDays}–${d.maxDays}';
        rows.add((
          loc.t('delivery_time_label'),
          '$days${loc.t('delivery_days_suffix')}',
          false
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 22, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t('delivery_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 4),
                if (rows.isEmpty)
                  Text(
                    loc.t('delivery_agreed'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35),
                  )
                else
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text('${r.$1}: ',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          Flexible(
                            child: Text(
                              r.$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: r.$3
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: AppText.sectionTitle.copyWith(fontSize: 16));

  Widget _variantChips(Product p) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: p.variants.map((v) {
        final selected = _selectedVariant?.id == v.id;
        return ChoiceChip(
          label: Text(v.name),
          selected: selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: selected ? AppColors.onBrand : AppColors.textPrimary,
          ),
          onSelected: (_) {
            setState(() {
              _selectedVariant = v;
              // Variant almashganda galereya shu variant rasmlariga o'tadi — boshidan.
              _galleryIndex = 0;
              if (_galleryController.hasClients)
                _galleryController.jumpToPage(0);
            });
            if (_activeModel3d?.glbUrl != null) {
              Model3DCacheManager.instance.prefetch(_activeModel3d!.glbUrl);
            }
          },
        );
      }).toList(),
    );
  }

  /// Narx + mavjudlik. Chegirma bo'lsa `PriceBlock` eski narxni ham ko'rsatadi,
  /// bo'lmasa faqat joriy narx (bo'sh joy qoldirmaydi).
  Widget _priceSection(Variant v, LocaleStore loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PriceBlock(pricing: v.effectivePricing, large: true),
        const SizedBox(height: AppSpacing.sm),
        if (v.availableQuantity > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 15, color: AppColors.success),
                const SizedBox(width: 5),
                Text(
                  '${v.availableQuantity}${loc.t('product_in_stock_suffix')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            loc.t('product_out_of_stock_production'),
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.35),
          ),
      ],
    );
  }

  /// O'lcham chizmasi (quti: eni/bo'yi/chuqurligi + hajm). Kategoriya, firma, material
  /// va rang bu yerda takrorlanmaydi — ular rasm va firma kartasida allaqachon bor.
  /// Haqiqiy o'lcham bo'lmasa bo'lim umuman ko'rsatilmaydi.
  Widget _specsSection(Product p, LocaleStore loc) {
    final size = DimensionBox.resolve(_activeModel3d, _selectedVariant);
    if (size == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(loc.t('dim_title')),
          const SizedBox(height: AppSpacing.sm),
          DimensionBox(widthM: size.w, heightM: size.h, depthM: size.d),
        ],
      ),
    );
  }

  /// Tavsif: uzun bo'lsa 4 qatorda qisqartirilib, "Ko'proq o'qish" bilan ochiladi.
  /// Tavsif bo'lmasa bo'lim umuman ko'rsatilmaydi.
  Widget _descriptionSection(Product p, LocaleStore loc) {
    final text = p.description?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final long = text.length > 220;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(loc.t('product_tab_description')),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            maxLines: long && !_descExpanded ? 4 : null,
            overflow: long && !_descExpanded
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.55),
          ),
          if (long)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(48, 40)),
                onPressed: () => setState(() => _descExpanded = !_descExpanded),
                child: Text(loc.t(
                    _descExpanded ? 'product_read_less' : 'product_read_more')),
              ),
            ),
        ],
      ),
    );
  }

  /// "Sizga yoqishi mumkin" — o'sha kategoriyadagi boshqa mahsulotlar
  /// gorizontal ro'yxatda (qarang `_loadRecommended`).
  Widget _recommendedSection(LocaleStore loc) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _sectionTitle(loc.t('product_recommended')),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 268,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => SizedBox(
                width: 168,
                child: ProductCard(product: _recommended[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery(Product p, LocaleStore loc) {
    final urls = p.galleryFor(_selectedVariant);
    final width = MediaQuery.of(context).size.width;
    // Rasm hech qachon kesilmaydi/cho'zilmaydi (`contain`): butun mebel ko'rinadi.
    // Render kvadrat va allaqachon ichki bo'sh joyli — to'liq kenglikda ko'rsatiladi.
    final height = width.clamp(280.0, 560.0);
    return Stack(
      children: [
        Container(
          height: height,
          width: double.infinity,
          color: AppColors.card,
          child: urls.isEmpty
              ? const Center(
                  child: Icon(Icons.chair_rounded,
                      size: 64, color: AppColors.textDisabled),
                )
              : PageView.builder(
                  controller: _galleryController,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _galleryIndex = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => showImageGallery(
                      context,
                      urls,
                      initialIndex: i,
                      onIndexChanged: (idx) {
                        // Galereyada almashtirilgan rasm sahifadagi
                        // indikator va PageView bilan sinxron turadi.
                        if (_galleryController.hasClients) {
                          _galleryController.jumpToPage(idx);
                        }
                        setState(() => _galleryIndex = idx);
                      },
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: Image.network(
                        urls[i],
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 48, color: AppColors.textDisabled),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: _circleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Row(
            children: [
              _cartCircleButton(context),
              const SizedBox(width: AppSpacing.sm),
              LikeButton(productId: p.id, product: p, size: 40),
              const SizedBox(width: AppSpacing.sm),
              _circleButton(
                icon: Icons.ios_share_rounded,
                tooltip: loc.t('product_share_suffix').trim(),
                onTap: () => _share(p, loc),
              ),
            ],
          ),
        ),
        if (urls.length > 1) ...[
          Positioned(
            bottom: AppSpacing.md,
            left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${_galleryIndex + 1} / ${urls.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.md + 9,
            left: 0,
            right: 0,
            child: IgnorePointer(
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
                          ? AppColors.brand
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (_activeModel3d?.glbUrl != null)
          Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.md,
              child: _view3dButton(p, loc)),
      ],
    );
  }

  Widget _circleButton(
      {required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.brand),
        ),
      ),
    );
  }

  Widget _view3dButton(Product p, LocaleStore loc) {
    return GestureDetector(
      onTap: () => _open3d(p, loc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_rounded,
                size: 16, color: AppColors.onBrand),
            const SizedBox(width: 6),
            Text(
              loc.t('product_view_3d'),
              style: const TextStyle(
                color: AppColors.onBrand,
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

  Widget _companyCard(BuildContext context, Product p) {
    final location = [
      if (p.companyViloyatDisplay?.isNotEmpty == true) p.companyViloyatDisplay!,
      if (p.companyAddress?.isNotEmpty == true) p.companyAddress!,
    ].join(', ');
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: const Icon(Icons.storefront_rounded,
                size: 22, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                    if (p.companyIsVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(compact: true),
                    ],
                  ],
                ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (p.companySlug != null)
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.textSecondary),
        ],
      ),
    );
    if (p.companySlug == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompanyDetailScreen(companySlug: p.companySlug!),
        ),
      ),
      child: card,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 20, color: AppColors.brand),
          ),
          if (cartCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.card, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  cartCount > 99 ? '99+' : '$cartCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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

    context.read<CartStore>().addProduct(p, _selectedVariant!, qty: _qty);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.brandPressed,
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
                        color: AppColors.success,
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
                      colors: [
                        AppColors.backgroundAlt,
                        AppColors.backgroundAlt
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.backgroundAlt.withValues(alpha: 0.3),
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

  /// Pastki qat'iy xarid paneli: miqdor, jami summa va asosiy harakat. Foydalanuvchi
  /// nimani, qancha narxda, necha dona olayotganini doim ko'radi.
  Widget _purchaseBar(Product p, Variant v, LocaleStore loc) {
    final total = v.effectivePriceValue * _qty;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              _qtyStepper(),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _addToCartButton(p, loc, total)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyStepper() {
    Widget btn(IconData icon, bool enabled, VoidCallback onTap, String tip) {
      return IconButton(
        onPressed: enabled ? onTap : null,
        tooltip: tip,
        icon: Icon(icon, size: 20),
        color: AppColors.brand,
        disabledColor: AppColors.textDisabled,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
        padding: EdgeInsets.zero,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, _qty > 1, () => setState(() => _qty--),
              '−'),
          SizedBox(
            width: 28,
            child: Text(
              '$_qty',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
            ),
          ),
          btn(Icons.add_rounded, _qty < 99, () => setState(() => _qty++), '+'),
        ],
      ),
    );
  }

  Widget _addToCartButton(Product p, LocaleStore loc, double total) {
    return ScaleTransition(
      scale: _cartBtnScale,
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () => _onAddToCart(p, loc),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _justAddedToCart ? AppColors.success : AppColors.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _justAddedToCart
                ? Row(
                    key: const ValueKey('added'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          loc.t('cart_added_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('add'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        loc.t('product_add_to_cart'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            height: 1.15),
                      ),
                      Text(
                        '${formatSom(total.toStringAsFixed(0))} ${loc.t('currency_som')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.15),
                      ),
                    ],
                  ),
          ),
        ),
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
    final cached =
        await Model3DCacheManager.instance.getCachedFile(widget.glbUrl);
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
                      backgroundColor: AppColors.backgroundAlt,
                    ),
                  ),
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.deep, AppColors.brandPressed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textDisabled,
                            blurRadius: 16,
                            offset: Offset(0, 6),
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
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _downloadProgress.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
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
                color: AppColors.textSecondary,
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
    final String src =
        _cachedFile != null ? 'file://${_cachedFile!.path}' : widget.glbUrl;

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
