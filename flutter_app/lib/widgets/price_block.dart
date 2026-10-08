import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';

/// Narx ko'rinishi — kartada va mahsulot sahifasida BIR XIL (dizayn tizimi).
/// Faqat backend haqiqatan chegirma bersa (`discountActive`) eski narx
/// chizilgan holda va foiz belgisi bilan ko'rsatiladi; aks holda joriy narxning
/// o'zi — bo'sh joy qoldirmasdan. Kelajakda yangi maydonlar (masalan boshqa
/// aksiya turlari) shu yerga qo'shiladi.
class PriceBlock extends StatelessWidget {
  final Variant variant;
  final bool large;
  final bool fromSuffix; // "dan" qo'shimchasi (katalog kartasi)
  const PriceBlock(
      {super.key,
      required this.variant,
      this.large = false,
      this.fromSuffix = false});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final base = variant.basePriceValue;
    final discounted =
        variant.discountActive && variant.effectiveBasePrice != null;
    final current = discounted
        ? (double.tryParse(variant.effectiveBasePrice!) ?? base)
        : base;
    final suffix = fromSuffix ? loc.t('price_from_suffix') : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discounted)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${formatSom(base.toStringAsFixed(0))} ${loc.t('currency_som')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 14 : 11.5,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              if (variant.discountPercent > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: large ? 7 : 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '-${variant.discountPercent.round()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: large ? 12 : 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        Text(
          '${formatSom(current.toStringAsFixed(0))} ${loc.t('currency_som')}$suffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: large
              ? const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                  height: 1.15)
              : AppText.price,
        ),
      ],
    );
  }
}
