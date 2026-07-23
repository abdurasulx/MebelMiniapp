import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../models.dart';
import 'product_detail_screen.dart';

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
      setState(() => _submitMessage = 'Rahmat! Bahoyingiz saqlandi.');
      _commentController.clear();
      await _load();
    } catch (e) {
      setState(() => _submitMessage = e.toString());
    } finally {
      setState(() => _submitBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    final company = _company;
    return Scaffold(
      appBar: AppBar(title: Text(company?.name ?? 'Do\'kon')),
      body: company == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red))
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(company: company),
                const SizedBox(height: 20),
                const Text(
                  'Mahsulotlar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_products.isEmpty)
                  const Text(
                    'Hozircha mahsulotlar yo\'q',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: _products.length,
                    itemBuilder: (context, i) {
                      final p = _products[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(productId: p.id),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: p.imageUrl != null
                                    ? Image.network(
                                        p.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : Container(
                                        color: Colors.brown.shade50,
                                        child: const Icon(Icons.chair),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.nameUz,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Text(
                  'Mijoz baholari (${_reviews.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (_reviews.isEmpty)
                  const Text(
                    'Hali baho yo\'q',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ..._reviews.map(
                    (r) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.customerName?.isNotEmpty == true
                                      ? r.customerName!
                                      : 'Mijoz',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('⭐' * r.rating),
                              ],
                            ),
                            if (r.comment?.isNotEmpty == true)
                              Text(
                                r.comment!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isAuthenticated) ...[
                  const SizedBox(height: 24),
                  _reviewForm(),
                ],
              ],
            ),
    );
  }

  Widget _reviewForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Baho qoldirish',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButton<int>(
              value: _rating,
              items: [5, 4, 3, 2, 1]
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text('${'⭐' * n} ($n)'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _rating = v ?? 5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            if (_submitMessage != null) ...[
              Text(
                _submitMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _submitBusy ? null : _submitReview,
              child: _submitBusy
                  ? const CircularProgressIndicator()
                  : const Text('Baho qoldirish'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Faqat shu firmadan yakunlangan buyurtmangiz bo\'lsa baho qoldira olasiz.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECC299).withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: company.logoUrl != null
                    ? Image.network(
                        company.logoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFECC299).withOpacity(0.5),
                        child: const Icon(Icons.business),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                              color: _hexToColor(tier.color).withOpacity(0.2),
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
                            Text(
                              '⭐ ${tier.rating!.toStringAsFixed(1)} (${tier.reviewCount})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
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
          if (company.address?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  company.address!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
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
