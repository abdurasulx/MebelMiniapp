import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'company_detail_screen.dart';

/// Mahsulot tafsiloti — Android'da faqat ko'rish uchun: narx va 3D model
/// (aylantirib ko'rish, AR joylashtirish emas — bu web/iOS'da bor).
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

  @override
  void initState() {
    super.initState();
    _load();
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
    return Scaffold(
      appBar: AppBar(title: Text(p?.nameUz ?? 'Mahsulot')),
      body: p == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red))
                  : const CircularProgressIndicator(color: AppColors.deep),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _media(p),
                const SizedBox(height: 18),
                Text(
                  p.nameUz,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _companyLink(context, p),
                if (p.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
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
                        onSelected: (_) => setState(() => _selectedVariant = v),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  if (_selectedVariant != null) _priceCard(),
                ],
              ],
            ),
    );
  }

  Widget _media(Product p) {
    return Container(
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.primary.withOpacity(0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: p.model3d?.glbUrl != null
          ? ModelViewer(
              src: p.model3d!.glbUrl!,
              alt: p.nameUz,
              autoRotate: true,
              cameraControls: true,
              backgroundColor: Colors.transparent,
            )
          : p.imageUrl != null
          ? Image.network(
              p.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
            )
          : const Center(
              child: Icon(Icons.chair_rounded, size: 64, color: AppColors.deep),
            ),
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
