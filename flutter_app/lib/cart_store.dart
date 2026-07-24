import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Bitta savat elementi — checkout paytida backend `OrderCreateSerializer`ga
/// mos formatda yuboriladi (web `cart.js` bilan bir xil naqsh: qurilmada
/// saqlanadi, buyurtma berilgandagina serverga yuboriladi).
class CartItem {
  final String productId;
  final String productName;
  final String? imageUrl;
  final String companyId;
  final String companyName;
  final String variantId;
  final String variantName;
  final double width;
  final double height;
  final double depth;
  final double unitM3Price;
  int qty;

  CartItem({
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.companyId,
    required this.companyName,
    required this.variantId,
    required this.variantName,
    required this.width,
    required this.height,
    required this.depth,
    required this.unitM3Price,
    this.qty = 1,
  });

  double get subtotal => unitM3Price * width * height * depth * qty;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'image_url': imageUrl,
    'company_id': companyId,
    'company_name': companyName,
    'variant_id': variantId,
    'variant_name': variantName,
    'width': width,
    'height': height,
    'depth': depth,
    'unit_m3_price': unitM3Price,
    'qty': qty,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId: j['product_id'],
    productName: j['product_name'],
    imageUrl: j['image_url'],
    companyId: j['company_id'],
    companyName: j['company_name'],
    variantId: j['variant_id'],
    variantName: j['variant_name'],
    width: (j['width'] as num).toDouble(),
    height: (j['height'] as num).toDouble(),
    depth: (j['depth'] as num).toDouble(),
    unitM3Price: (j['unit_m3_price'] as num).toDouble(),
    qty: j['qty'] ?? 1,
  );
}

/// Savat — qurilmada saqlanadi (`shared_preferences`), buyurtma
/// berilgandagina backend `Order` yaratiladi (`/orders/` — bitta buyurtmada
/// faqat bitta kompaniya bo'lishi shart, shuning uchun checkout'da
/// kompaniya bo'yicha guruhlab, har biriga alohida so'rov yuboriladi).
class CartStore extends ChangeNotifier {
  static const _prefKey = 'fp.cart';

  List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  int get count => _items.fold(0, (s, i) => s + i.qty);
  double get total => _items.fold(0, (s, i) => s + i.subtotal);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _items = list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      // buzilgan mahalliy ma'lumot — e'tiborsiz qoldiriladi
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      jsonEncode(_items.map((i) => i.toJson()).toList()),
    );
  }

  void addProduct(Product product, Variant variant, {int qty = 1}) {
    final existing = _items.where(
      (i) => i.productId == product.id && i.variantId == variant.id,
    );
    if (existing.isNotEmpty) {
      existing.first.qty += qty;
    } else {
      _items.add(
        CartItem(
          productId: product.id,
          productName: product.nameUz,
          imageUrl: product.cardImageUrl,
          companyId: product.company,
          companyName: product.companyName,
          variantId: variant.id,
          variantName: variant.name,
          width: variant.widthValue,
          height: variant.heightValue,
          depth: variant.depthValue,
          unitM3Price: variant.basePriceValue,
        ),
      );
    }
    notifyListeners();
    _persist();
  }

  void setQty(int index, int qty) {
    _items[index].qty = qty < 1 ? 1 : qty;
    notifyListeners();
    _persist();
  }

  void removeAt(int index) {
    _items.removeAt(index);
    notifyListeners();
    _persist();
  }

  void clear() {
    _items = [];
    notifyListeners();
    _persist();
  }

  /// companyId bo'yicha guruhlangan elementlar — checkout paytida har biri
  /// alohida `/orders/` so'roviga aylanadi.
  Map<String, List<CartItem>> get byCompany {
    final map = <String, List<CartItem>>{};
    for (final i in _items) {
      (map[i.companyId] ??= []).add(i);
    }
    return map;
  }
}
