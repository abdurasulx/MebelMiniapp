import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
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
  // Backend `/cart-items/`dagi mos yozuv ID'si — muvaffaqiyatli
  // sinxronlangandan keyin to'ldiriladi, keyingi qty o'zgarishi/o'chirish
  // shu ID orqali serverga ham yetkaziladi (qidiruv/asosiy sahifa reytingi
  // uchun "savatda turgan aktivligi" signali, qarang backend apps/cart).
  String? serverId;

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
    this.serverId,
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
    'server_id': serverId,
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
    serverId: j['server_id'],
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
      final item = existing.first;
      item.qty += qty;
      notifyListeners();
      _persist();
      if (item.serverId != null) {
        _syncPatch(item);
      } else {
        _syncAdd(item);
      }
    } else {
      final item = CartItem(
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
        qty: qty,
      );
      _items.add(item);
      notifyListeners();
      _persist();
      _syncAdd(item);
    }
  }

  // Serverga (`/cart-items/`) qo'shish — faqat qidiruv/asosiy sahifa
  // reytingi uchun signal, checkout shu yerga bog'liq emas, shuning uchun
  // xato bo'lsa ham jim o'tkazib yuboriladi (UI'ni bloklamaslik uchun).
  Future<void> _syncAdd(CartItem item) async {
    try {
      final id = await ApiClient.instance.post(
        '/cart-items/',
        (j) => j['id'] as String,
        body: {
          'product': item.productId,
          'variant': item.variantId,
          'width': item.width,
          'height': item.height,
          'depth': item.depth,
          'quantity': item.qty,
        },
      );
      item.serverId = id;
      _persist();
    } catch (_) {}
  }

  Future<void> _syncPatch(CartItem item) async {
    try {
      await ApiClient.instance.patch(
        '/cart-items/${item.serverId}/',
        (j) => null,
        body: {'quantity': item.qty},
      );
    } catch (_) {}
  }

  void setQty(int index, int qty) {
    final item = _items[index];
    item.qty = qty < 1 ? 1 : qty;
    notifyListeners();
    _persist();
    if (item.serverId != null) _syncPatch(item);
  }

  void removeAt(int index) {
    final item = _items.removeAt(index);
    notifyListeners();
    _persist();
    if (item.serverId != null) {
      ApiClient.instance
          .delete('/cart-items/${item.serverId}/', (j) => null)
          .catchError((_) {});
    }
  }

  void clear() {
    _items = [];
    notifyListeners();
    _persist();
    ApiClient.instance
        .delete('/cart-items/clear/', (j) => null)
        .catchError((_) {});
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
