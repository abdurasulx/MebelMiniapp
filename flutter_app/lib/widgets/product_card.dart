import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../screens/product_detail_screen.dart';
import 'like_button.dart';

/// Katalog/Bosh sahifa/Sevimlilarda bir xil ko'rinishdagi mahsulot kartasi
/// (iOS'dagi `ShopProductCard` bilan bir xil dizayn).
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final hasAr = product.model3d?.glbUrl != null;
    final price = product.variants.isNotEmpty
        ? product.variants.first.basePriceValue
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.cardImageUrl != null
                        ? Image.network(
                            product.cardImageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.primary.withOpacity(0.35),
                            child: const Icon(
                              Icons.chair_rounded,
                              size: 42,
                              color: AppColors.deep,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (hasAr)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.deep,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_in_ar_rounded,
                                  size: 11,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '3D',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameUz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  if (product.attributeSummary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.attributeSummary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.deep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    product.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8A7357),
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${formatSom(price.toStringAsFixed(0))} so\'m dan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
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
