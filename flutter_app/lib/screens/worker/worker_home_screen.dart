import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api_client.dart';
import '../../auth_store.dart';
import '../../models.dart';
import '../product_detail_screen.dart';

/// Usta ish rejimi: faqat o'z firmasining mahsulotlari (va ularning 3D
/// modellari) ko'rinadi — uy loyihalashda butun bozor emas, faqat o'z firmasi
/// mahsulotlaridan foydalaniladi.
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});
  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = context.read<AuthStore>().user?.company;
    if (company == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.instance.get(
        '/products/?company=${company.slug}',
        (j) => Paginated<Product>.fromJson(j, Product.fromJson),
        auth: true,
      );
      setState(() => _products = page.results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<AuthStore>().user?.company;
    return Scaffold(
      appBar: AppBar(title: const Text('Usta paneli')),
      body: company == null
          ? const Center(child: Text('Siz hali biror firmada ishlamayapsiz'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    company.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Faqat shu firma mahsulotlari — uy loyihalashda ishlatiladi.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (!_loading && _products.isEmpty)
                    const Text('Bu firmada hali mahsulot yo\'q'),
                  ..._products.map(
                    (p) => Card(
                      child: ListTile(
                        title: Text(p.nameUz),
                        subtitle:
                            p.model3d?.usdzUrl != null ||
                                p.model3d?.glbUrl != null
                            ? const Text(
                                '3D mavjud',
                                style: TextStyle(fontSize: 12),
                              )
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(productId: p.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
