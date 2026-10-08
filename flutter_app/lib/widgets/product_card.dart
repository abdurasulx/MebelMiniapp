import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';
import '../screens/product_detail_screen.dart';
import 'like_button.dart';
import 'price_block.dart';

/// Katalog/Bosh sahifa/Sevimlilarda bir xil ko'rinishdagi mahsulot kartasi
/// (iOS'dagi `ShopProductCard` bilan bir xil dizayn).
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final hasAr = product.model3d?.glbUrl != null;
    final firstVariant =
        product.variants.isNotEmpty ? product.variants.first : null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Rasm hech qachon cho'zilmaydi/kesilmaydi: `contain` + ichki
                  // bo'sh joy — butun mebel ko'rinadi, shaffof fonli rasmlar ham
                  // yumshoq fon ustida toza turadi.
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.card,
                      child: product.cardImageUrl != null
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Image.network(
                                product.cardImageUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : const ColoredBox(
                                            color: AppColors.backgroundAlt),
                                errorBuilder: (_, __, ___) =>
                                    const _ImagePlaceholder(),
                              ),
                            )
                          : const _ImagePlaceholder(),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Row(
                      children: [
                        if (hasAr)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_in_ar_rounded,
                                  size: 12,
                                  color: AppColors.onBrand,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '3D',
                                  style: TextStyle(
                                    color: AppColors.onBrand,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        LikeButton(productId: product.id, product: product),
                      ],
                    ),
                  ),
                  if (product.availableQuantity > 0)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${product.availableQuantity} ${loc.t('unit_pcs')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameUz,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.productName,
                  ),
                  if (product.attributeSummary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.attributeSummary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.brandSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    product.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                  if (firstVariant != null) ...[
                    const SizedBox(height: AppSpacing.sm - 2),
                    PriceBlock(variant: firstVariant, fromSuffix: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.backgroundAlt,
      child: Center(
        child:
            Icon(Icons.chair_rounded, size: 40, color: AppColors.textDisabled),
      ),
    );
  }
}
