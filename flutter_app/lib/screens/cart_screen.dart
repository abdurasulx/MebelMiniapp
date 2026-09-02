import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../cart_store.dart';
import '../locale_store.dart';
import '../location_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/phone_verify_dialog.dart';
import 'auth_screen.dart';

/// Savat — web `Cart.jsx` bilan bir xil oqim: bitta buyurtmada faqat bitta
/// kompaniya bo'lishi shart (backend qoidasi), shuning uchun checkout paytida
/// kompaniya bo'yicha guruhlab, har biriga alohida `/orders/` so'rovi yuboriladi.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _placeOrders(CartStore cart) async {
    // Telefon/manzil endi so'ralmaydi — tasdiqlangan profildan (backend
    // `request.user.phone`) va shu yerdagi GPS'dan (`LocationStore`)
    // avtomatik olinadi.
    final location = context.read<LocationStore>();
    if (location.lat == null) await location.detectFromGps();
    for (final group in cart.byCompany.values) {
      await ApiClient.instance.post(
        '/orders/',
        (j) => j,
        body: {
          'latitude': location.lat,
          'longitude': location.lng,
          'items': group
              .map(
                (i) => {
                  'variant': i.variantId,
                  'width': i.width,
                  'height': i.height,
                  'depth': i.depth,
                  'quantity': i.qty,
                },
              )
              .toList(),
        },
      );
    }
    cart.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Buyurtma qabul qilindi')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _checkout(CartStore cart) async {
    final auth = context.read<AuthStore>();
    if (!auth.isAuthenticated) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _placeOrders(cart);
    } on ApiException catch (e) {
      // Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
      // foydalanuvchi uchun backend 403 qaytaradi — shu holatda tasdiqlash
      // oynasini ochib, muvaffaqiyatli bo'lsa buyurtmani qayta yuboramiz.
      if (e.statusCode == 403 && e.message.contains('tasdiqlang')) {
        setState(() => _busy = false);
        final verified = await showPhoneVerifyDialog(
          context,
          initialPhone: auth.user?.phone ?? '',
        );
        if (verified == true && mounted) {
          await auth.refreshUser();
          setState(() => _busy = true);
          try {
            await _placeOrders(cart);
          } catch (e2) {
            setState(() => _error = e2.toString());
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        }
        return;
      }
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('cart_title'))),
      body: cart.items.isEmpty ? _empty(loc) : _content(cart, loc),
    );
  }

  Widget _empty(LocaleStore loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 48,
            color: Color(0xFF8A7357),
          ),
          const SizedBox(height: 10),
          Text(
            loc.t('cart_empty_title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            loc.t('cart_empty_subtitle'),
            style: const TextStyle(color: Color(0xFF8A7357), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _content(CartStore cart, LocaleStore loc) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < cart.items.length; i++) _cartTile(cart, i),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.t('cart_total'),
              style: const TextStyle(color: Color(0xFF8A7357)),
            ),
            Text(
              '${formatSom(cart.total.toStringAsFixed(0))} so\'m',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _busy ? null : () => _checkout(cart),
          child: Text(_busy ? loc.t('cart_submitting') : loc.t('cart_submit')),
        ),
      ],
    );
  }

  Widget _cartTile(CartStore cart, int index) {
    final i = cart.items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: i.imageUrl != null
                ? Image.network(
                    i.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.primary.withOpacity(0.3),
                    child: const Icon(
                      Icons.chair_rounded,
                      color: AppColors.deep,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${i.variantName} · ${i.companyName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A7357),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatSom(i.subtotal.toStringAsFixed(0))} so\'m',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepBtn(
                    Icons.remove_rounded,
                    () => cart.setQty(index, i.qty - 1),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i.qty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _stepBtn(
                    Icons.add_rounded,
                    () => cart.setQty(index, i.qty + 1),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
                onPressed: () => cart.removeAt(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: AppColors.deep),
      ),
    );
  }
}
