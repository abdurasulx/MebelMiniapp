import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/like_button.dart';
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

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  Variant? _selectedVariant;
  String? _error;
  int _galleryIndex = 0;
  final _galleryController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
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
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mahsulot')),
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
            _gallery(p),
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
                  if (p.branchAddress?.isNotEmpty == true ||
                      p.branchViloyatDisplay != null) ...[
                    const SizedBox(height: 8),
                    _locationRow(p),
                  ],
                  if (p.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      p.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B5A48),
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (p.variants.isNotEmpty) ...[
                    const Text(
                      'VARIANT (MATERIAL/RANG)',
                      style: TextStyle(
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
                          label: Text(v.name),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedVariant = v),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    if (_selectedVariant != null) _priceCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gallery(Product p) {
    final urls = p.galleryUrls;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: SizedBox(
            height: 320,
            width: double.infinity,
            child: urls.isEmpty
                ? Container(
                    color: AppColors.primary.withOpacity(0.25),
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
              LikeButton(productId: p.id),
              const SizedBox(width: 8),
              _circleButton(
                icon: Icons.ios_share_rounded,
                onTap: () => _share(p),
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
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        if (p.model3d?.glbUrl != null)
          Positioned(bottom: 12, right: 12, child: _view3dButton(p)),
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

  Widget _view3dButton(Product p) {
    return GestureDetector(
      onTap: () => _open3d(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.deep,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              '3D ko\'rish',
              style: TextStyle(
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

  void _open3d(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => Container(
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
                  p.nameUz,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ModelViewer(
                    src: p.model3d!.glbUrl!,
                    alt: p.nameUz,
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _share(Product p) {
    Share.share(
      '${p.nameUz} — ${p.companyName}\nFurniture Platform ilovasida ko\'ring.',
    );
  }

  Widget _locationRow(Product p) {
    final text = [
      if (p.branchViloyatDisplay != null) p.branchViloyatDisplay!,
      if (p.branchAddress?.isNotEmpty == true) p.branchAddress!,
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
            color: AppColors.primary.withOpacity(0.5),
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

  Widget _priceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.55),
            AppColors.primary.withOpacity(0.25),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NARX (1 M³)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF8A7357),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatSom(_selectedVariant!.basePriceValue.toStringAsFixed(0))} so\'m',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
        ],
      ),
    );
  }
}
