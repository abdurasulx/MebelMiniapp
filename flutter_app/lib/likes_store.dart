import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'models.dart';

/// Sevimlilar holati — serverda saqlanadi, qaysi qurilmadan kirsa ham bir xil
/// (iOS'dagi `LikesStore` bilan bir xil naqsh).
///
/// `LikesScreen` endi bevosita shu ro'yxatdan (`likedProducts`) render
/// qiladi — like/unlike qilinganda (qaerda bo'lmasin: Bosh sahifa, mahsulot
/// sahifasi) darhol shu yerda ham yangilanadi, Sevimlilar tabiga har safar
/// kirilganda serverdan qayta so'ralmaydi (qarang `toggle`/`loadIfNeeded`).
class LikesStore extends ChangeNotifier {
  final Set<String> _likedIds = {};
  List<Product> _likedProducts = [];
  bool _didLoadOnce = false;

  List<Product> get likedProducts => _likedProducts;

  bool isLiked(String productId) => _likedIds.contains(productId);

  /// Mahsulotlar ro'yxati serverdan kelganda ularning `is_liked` bayrog'ini
  /// sinxronlaydi (faqat ID'lar — bu yerda ko'ringan mahsulotlar sevimlilar
  /// ro'yxatining to'liq o'zi emas, shuning uchun `likedProducts`ga
  /// tegilmaydi, qarang `loadIfNeeded`).
  void sync(List<Product> products) {
    for (final p in products) {
      if (p.isLiked) _likedIds.add(p.id);
    }
  }

  void clear() {
    _likedIds.clear();
    _likedProducts.clear();
    _didLoadOnce = false;
    notifyListeners();
  }

  /// Sevimlilar ekrani birinchi marta ochilganda serverdan to'liq ro'yxatni
  /// yuklaydi — keyingi safar tab qayta faol bo'lganda qayta so'ralmaydi,
  /// chunki `toggle()` har bir o'zgarishni shu yerning o'zida darhol
  /// aks ettiradi.
  Future<void> loadIfNeeded() async {
    if (_didLoadOnce) return;
    await reload();
  }

  /// Pastga-tortib-yangilash uchun — `loadIfNeeded`dan farqli, "bir marta
  /// yuklandi" bayrog'iga qaramasdan har doim serverdan qayta so'raydi.
  Future<void> reload() async {
    _didLoadOnce = true;
    try {
      final page = await ApiClient.instance.get(
        '/likes/',
        (j) => Paginated<Like>.fromJson(j, Like.fromJson),
        auth: true,
      );
      _likedProducts = page.results.map((l) => l.productDetail).toList();
      _likedIds
        ..clear()
        ..addAll(page.results.map((l) => l.product));
      notifyListeners();
    } catch (_) {
      // Keyingi safar (masalan tarmoq tiklangach) qayta urinib ko'rish
      // uchun — muvaffaqiyatsiz urinishni "bir marta yuklandi" deb
      // hisoblamaymiz.
      _didLoadOnce = false;
    }
  }

  Future<void> toggle(String productId, {Product? product}) async {
    try {
      final res = await ApiClient.instance.post(
        '/likes/toggle/',
        (j) => j as Map<String, dynamic>,
        body: {'product': productId},
        auth: true,
      );
      if (res['liked'] == true) {
        _likedIds.add(productId);
        if (product != null &&
            !_likedProducts.any((p) => p.id == productId)) {
          _likedProducts = [product, ..._likedProducts];
        }
      } else {
        _likedIds.remove(productId);
        _likedProducts = _likedProducts
            .where((p) => p.id != productId)
            .toList();
      }
      notifyListeners();
    } catch (_) {
      // jim turamiz — UI holati o'zgarmaydi
    }
  }
}
