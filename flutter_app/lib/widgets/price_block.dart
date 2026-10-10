import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';

/// Narx ko'rinishi — kartada va mahsulot sahifasida BIR XIL (dizayn tizimi).
/// Qiymatlar backend `pricing` blokidan keladi (frontend chegirmani hisoblamaydi).
/// Chegirma bo'lsa eski narx chizilgan holda va foiz belgisi bilan, aks holda faqat
/// joriy narx — bo'sh joy qoldirmasdan.
class PriceBlock extends StatelessWidget {
  final PricingInfo pricing;
  final bool large;
  final bool fromSuffix; // "dan" qo'shimchasi (katalog kartasi)
  const PriceBlock(
      {super.key,
      required this.pricing,
      this.large = false,
      this.fromSuffix = false});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final suffix = fromSuffix ? loc.t('price_from_suffix') : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pricing.hasDiscount)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${formatSom(pricing.originalPrice.toStringAsFixed(0))} ${loc.t('currency_som')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 14 : 11.5,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              if (pricing.discountPercent > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: large ? 7 : 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '-${pricing.discountPercent.round()}%',
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
          '${formatSom(pricing.finalPrice.toStringAsFixed(0))} ${loc.t('currency_som')}$suffix',
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

/// "Tasdiqlangan firma" belgisi — faqat backend `is_verified == true` bergan bo'lsa ko'rsatiladi.
class VerifiedBadge extends StatelessWidget {
  final bool compact;
  const VerifiedBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    if (compact) {
      return Tooltip(
        message: loc.t('company_verified'),
        child:
            const Icon(Icons.verified_rounded, size: 16, color: AppColors.info),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: AppColors.info),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              loc.t('company_verified'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}
