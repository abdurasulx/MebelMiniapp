import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';

/// Vitrina (demo) — faol firma yo'q hududdagi foydalanuvchi ilova imkoniyatlarini
/// ko'rishi uchun test mahsulotlar. Buyurtma/savat YO'Q (backendda ham firmasiz).
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  List<ShowcaseProduct>? _items;
  Object? _error;
  String? _loadedLang;

  Future<void> _load(String lang) async {
    _loadedLang = lang;
    setState(() => _error = null);
    try {
      final page = await ApiClient.instance.get(
        '/showcase/products/?lang=$lang',
        (j) => Paginated<ShowcaseProduct>.fromJson(j, ShowcaseProduct.fromJson),
      );
      if (mounted) setState(() => _items = page.results);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    // Til almashsa nomlar ham shu tilda qayta yuklanadi.
    if (_loadedLang != loc.code) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedLang != loc.code) _load(loc.code);
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('showcase_title'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.accent,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
            child: Text(
              loc.t('showcase_demo_banner'),
              style: const TextStyle(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          Expanded(child: _body(loc)),
        ],
      ),
    );
  }

  Widget _body(LocaleStore loc) {
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: () => _load(loc.code),
          child: Text(loc.t('loc_retry')),
        ),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(loc.t('showcase_empty'),
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.74,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShowcaseCard(product: items[i]),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  final ShowcaseProduct product;
  const _ShowcaseCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ShowcaseDetailScreen(product: product)),
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
              child: ColoredBox(
                color: AppColors.backgroundAlt,
                child: product.imageUrl != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Image.network(product.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const _Placeholder()),
                      )
                    : const _Placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.productName),
                  if (product.priceFrom != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${formatSom(product.priceFrom!.toStringAsFixed(0))} ${loc.t('currency_som')}${loc.t('price_from_suffix')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.price,
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

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => const Center(
        child:
            Icon(Icons.chair_rounded, size: 40, color: AppColors.textDisabled),
      );
}

class ShowcaseDetailScreen extends StatefulWidget {
  final ShowcaseProduct product;
  const ShowcaseDetailScreen({super.key, required this.product});

  @override
  State<ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<ShowcaseDetailScreen> {
  final _page = PageController();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final p = widget.product;
    final images = p.gallery;
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('showcase_title'))),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.accent,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
            child: Text(
              loc.t('showcase_demo_banner'),
              style: const TextStyle(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          SizedBox(
            height: 300,
            child: images.isEmpty
                ? const ColoredBox(
                    color: AppColors.backgroundAlt, child: _Placeholder())
                : PageView.builder(
                    controller: _page,
                    itemCount: images.length,
                    itemBuilder: (_, i) => ColoredBox(
                      color: AppColors.backgroundAlt,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Image.network(images[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppText.pageTitle),
                if (p.priceFrom != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${formatSom(p.priceFrom!.toStringAsFixed(0))} ${loc.t('currency_som')}${loc.t('price_from_suffix')}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(p.description, style: AppText.body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
