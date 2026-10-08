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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LocaleStore>().t('cart_order_placed')),
        ),
      );
      Navigator.of(context).maybePop();
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

  void _confirmClear(CartStore cart, LocaleStore loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('cart_empty_title')),
        content:
            const Text("Savatdagi barcha mahsulotlarni o'chirmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('common_close')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            },
            child: Text(loc.t('cart_empty_title')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final loc = context.watch<LocaleStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('cart_title')),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.deep),
              tooltip: 'Tozalash',
              onPressed: () => _confirmClear(cart, loc),
            ),
        ],
      ),
      body: cart.items.isEmpty ? _empty(loc) : _content(cart, loc),
      bottomNavigationBar: cart.items.isEmpty ? null : _bottomBar(cart, loc),
    );
  }

  Widget _empty(LocaleStore loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.backgroundAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 46,
                color: AppColors.deep,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.t('cart_empty_title'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.deep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('cart_empty_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deep,
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                loc.t('cart_start_shopping'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(CartStore cart, LocaleStore loc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            '${cart.items.length} ${loc.t('cart_items_count')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (int i = 0; i < cart.items.length; i++) _cartTile(cart, i, loc),
        const SizedBox(height: 16),
        _orderSummary(cart, loc),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.errorDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cartTile(CartStore cart, int index, LocaleStore loc) {
    final i = cart.items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            child: SizedBox(
              width: 80,
              height: 80,
              child: ColoredBox(
                color: AppColors.background,
                child: i.imageUrl != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Image.network(
                          i.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.chair_rounded,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      )
                    : const Icon(Icons.chair_rounded,
                        color: AppColors.textDisabled),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        i.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.deep,
                          height: 1.25,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => cart.removeAt(index),
                      tooltip: "O'chirish",
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i.variantName} · ${i.companyName}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatSom(i.subtotal.toStringAsFixed(0))} so\'m',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.deep,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stepBtn(
                            Icons.remove_rounded,
                            () => cart.setQty(index, i.qty - 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${i.qty}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.deep,
                              ),
                            ),
                          ),
                          _stepBtn(
                            Icons.add_rounded,
                            () => cart.setQty(index, i.qty + 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: AppColors.brand),
      ),
    );
  }

  Widget _orderSummary(CartStore cart, LocaleStore loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.t('cart_summary_title'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${loc.t('cart_total')} (${cart.items.length} ${loc.t('cart_items_count')}):',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5),
              ),
              Text(
                '${formatSom(cart.total.toStringAsFixed(0))} so\'m',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.t('cart_delivery'),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  loc.t('cart_delivery_free'),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.t('cart_total'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.deep,
                ),
              ),
              Text(
                '${formatSom(cart.total.toStringAsFixed(0))} so\'m',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                  color: AppColors.deep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(CartStore cart, LocaleStore loc) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.t('cart_total'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatSom(cart.total.toStringAsFixed(0))} so\'m',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deep,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : () => _checkout(cart),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deep,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loc.t('cart_submit'),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
