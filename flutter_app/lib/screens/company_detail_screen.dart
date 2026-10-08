import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../locale_store.dart';
import '../models.dart';
import 'product_detail_screen.dart';
import '../theme.dart';
import '../widgets/price_block.dart';
import '../widgets/product_card.dart';

/// Firma do'kon sahifasi (marketplace uslubida) — mahsulot sahifasidan firma
/// nomiga bosilganda ochiladi: tavsif, ishonch darajasi, boshqa mahsulotlari
/// va mijoz sharhlari (web'dagi `Shop.jsx` bilan bir xil endpointlar).
class CompanyDetailScreen extends StatefulWidget {
  final String companySlug;
  const CompanyDetailScreen({super.key, required this.companySlug});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  Company? _company;
  List<Product> _products = [];
  List<Review> _reviews = [];
  String? _error;
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _submitBusy = false;
  String? _submitMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final company = await ApiClient.instance.get(
        '/companies/${widget.companySlug}/',
        (j) => Company.fromJson(j),
        // Tizimga kirmagan bo'lsa ham token yo'q holda ishlaydi (qarang
        // ApiClient._send), lekin kirgan bo'lsa `can_review` (baho qoldirish
        // formasini ko'rsatish/yashirish) shu foydalanuvchiga to'g'ri
        // hisoblanishi uchun token yuborilishi kerak.
        auth: true,
      );
      final productsPage = await ApiClient.instance.get(
        '/products/?company=${widget.companySlug}',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
      );
      final reviewsPage = await ApiClient.instance.get(
        '/reviews/?company=${widget.companySlug}',
        (j) => Paginated<Review>.fromJson(j, Review.fromJson),
      );
      setState(() {
        _company = company;
        _products = productsPage.results;
        _reviews = reviewsPage.results;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _submitReview() async {
    final company = _company;
    if (company == null) return;
    setState(() {
      _submitBusy = true;
      _submitMessage = null;
    });
    try {
      await ApiClient.instance.post(
        '/reviews/',
        (j) => j,
        body: {
          'company': company.id,
          'rating': _rating,
          'comment': _commentController.text,
        },
        auth: true,
      );
      setState(() =>
          _submitMessage = context.read<LocaleStore>().t('shop_review_thanks'));
      _commentController.clear();
      await _load();
    } catch (e) {
      setState(() => _submitMessage = e.toString());
    } finally {
      setState(() => _submitBusy = false);
    }
  }

  Widget _stars(int rating, {double size = 15}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? AppColors.accent : AppColors.border,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: AppText.sectionTitle.copyWith(fontSize: 16));

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    final loc = context.watch<LocaleStore>();
    final company = _company;
    return Scaffold(
      appBar:
          AppBar(title: Text(company?.name ?? loc.t('shop_title_fallback'))),
      body: company == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 40, color: AppColors.error),
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: AppColors.errorDark)),
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
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Header(company: company),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle(loc.t('shop_products')),
                const SizedBox(height: AppSpacing.md),
                if (_products.isEmpty)
                  _emptyBlock(
                      Icons.inventory_2_outlined, loc.t('shop_no_products'))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, i) =>
                        ProductCard(product: _products[i]),
                  ),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle(
                  '${loc.t('shop_reviews_prefix')}${_reviews.length}${loc.t('shop_reviews_suffix')}',
                ),
                const SizedBox(height: AppSpacing.md),
                if (_reviews.isEmpty)
                  _emptyBlock(
                      Icons.rate_review_outlined, loc.t('shop_no_reviews'))
                else
                  ..._reviews.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.customerName?.isNotEmpty == true
                                        ? r.customerName!
                                        : loc.t('shop_anonymous_customer'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                ),
                                _stars(r.rating),
                              ],
                            ),
                            if (r.comment?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                r.comment!,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isAuthenticated && company.canReview) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _reviewForm(loc),
                ] else if (isAuthenticated) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(loc.t('shop_review_locked'), style: AppText.caption),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }

  Widget _emptyBlock(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _reviewForm(LocaleStore loc) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('shop_leave_review'),
              style: AppText.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 34,
                    color: i < _rating ? AppColors.accent : AppColors.border,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(labelText: loc.t('shop_comment_label')),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_submitMessage != null) ...[
            Text(_submitMessage!, style: AppText.caption),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitBusy ? null : _submitReview,
              child: _submitBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textDisabled),
                    )
                  : Text(loc.t('shop_leave_review')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Company company;
  const _Header({required this.company});

  @override
  Widget build(BuildContext context) {
    final tier = company.tier;
    final loc = context.watch<LocaleStore>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: company.logoUrl != null
                    ? Container(
                        width: 64,
                        height: 64,
                        color: AppColors.card,
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          company.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.textDisabled),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: AppColors.backgroundAlt,
                        child: const Icon(Icons.storefront_rounded,
                            color: AppColors.brand),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (company.isVerified) ...[
                      const SizedBox(height: 4),
                      const VerifiedBadge(),
                    ],
                    if (tier != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _hexToColor(tier.color)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tier.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: _hexToColor(tier.color),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (tier.rating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 15, color: AppColors.accent),
                                const SizedBox(width: 2),
                                Text(
                                  '${tier.rating!.toStringAsFixed(1)} (${tier.reviewCount})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (company.description?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              company.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (company.address?.isNotEmpty == true ||
              company.mapUrl != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                if (company.address?.isNotEmpty == true)
                  Text(
                    company.address!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                if (company.mapUrl != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(company.mapUrl!),
                        mode: LaunchMode.externalApplication),
                    child: Text(
                      loc.t('shop_view_on_map'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (company.socialLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SocialLinksRow(links: company.socialLinks),
          ],
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

const _socialIcons = {
  'Instagram': Icons.alternate_email,
  'Telegram': Icons.send_rounded,
  'Facebook': Icons.link_rounded,
  'Veb-sayt': Icons.public_rounded,
};

/// Firma profilidagi ijtimoiy tarmoq/veb-sayt havolalari — bosilganda
/// tashqi brauzer/ilovada ochiladi (qarang Company.socialLinks).
class _SocialLinksRow extends StatelessWidget {
  final Map<String, String> links;
  const _SocialLinksRow({required this.links});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: links.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _open(e.value),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_socialIcons[e.key] ?? Icons.link_rounded,
                      size: 15, color: AppColors.brand),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
