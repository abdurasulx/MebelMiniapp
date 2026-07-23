import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../api_client.dart';
import '../models.dart';
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
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (p.model3d?.glbUrl != null)
                  SizedBox(
                    height: 280,
                    child: ModelViewer(
                      src: p.model3d!.glbUrl!,
                      alt: p.nameUz,
                      autoRotate: true,
                      cameraControls: true,
                    ),
                  )
                else if (p.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      p.imageUrl!,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                if (p.companySlug != null)
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CompanyDetailScreen(companySlug: p.companySlug!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.companyName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  )
                else
                  Text(
                    p.companyName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (p.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (p.variants.isNotEmpty) ...[
                  const Text(
                    'Variant (material/rang)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: p.variants.map((v) {
                      final selected = _selectedVariant?.id == v.id;
                      return ChoiceChip(
                        label: Text(v.name),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedVariant = v),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedVariant != null)
                    Card(
                      color: Colors.brown.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Narx (1 m³)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '${formatSom(_selectedVariant!.basePriceValue.toStringAsFixed(0))} so\'m',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
