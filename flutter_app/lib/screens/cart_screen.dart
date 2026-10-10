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
import '../net_image.dart';

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
    // Backend qoidasi: bitta buyurtmada bitta firma. Har firma muvaffaqiyatli
    // yuborilgach savatdan olinadi — keyingi firmada xato bo'lsa, qayta urinishda
    // allaqachon yaratilgan buyurtma ikkinchi marta yuborilmaydi.
    for (final entry in cart.byCompany.entries.toList()) {
      await ApiClient.instance.post(
        '/orders/',
        (j) => j,
        body: {
          'latitude': location.lat,
          'longitude': location.lng,
          'items': entry.value
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
      cart.removeCompany(entry.key);
    }
    if (mounted) await _showOrderPlaced();
  }

  /// Faqat backend barcha buyurtmalarni tasdiqlagandan KEYIN ko'rsatiladi.
  Future<void> _showOrderPlaced() async {
    final loc = context.read<LocaleStore>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 32, color: AppColors.success),
        ),
        title: Text(loc.t('cart_order_placed'), textAlign: TextAlign.center),
        content: Text(
          loc.t('cart_order_placed_hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('cart_order_placed_action')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).maybePop();
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
            '${cart.count} ${loc.t('unit_pcs')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._groupedTiles(cart, loc),
        const SizedBox(height: 4),
        _contactCard(loc),
        const SizedBox(height: 12),
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

  /// Mahsulotlar firma bo'yicha guruhlanadi (har firma uchun alohida buyurtma
  /// yaratiladi — foydalanuvchi buni oldindan ko'radi).
  List<Widget> _groupedTiles(CartStore cart, LocaleStore loc) {
    final groups = <String, List<int>>{};
    for (var i = 0; i < cart.items.length; i++) {
      (groups[cart.items[i].companyId] ??= []).add(i);
    }
    final multi = groups.length > 1;
    return [
      if (multi)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc.t('cart_multi_company_note'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35),
                ),
              ),
            ],
          ),
        ),
      for (final entry in groups.entries) ...[
        _companyHeader(cart, entry.value),
        for (final idx in entry.value) _cartTile(cart, idx, loc),
      ],
    ];
  }

  Widget _companyHeader(CartStore cart, List<int> indices) {
    final first = cart.items[indices.first];
    final subtotal =
        indices.fold<double>(0, (sum, i) => sum + cart.items[i].subtotal);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded,
              size: 18, color: AppColors.brand),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              first.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              "${formatSom(subtotal.toStringAsFixed(0))} so'm",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Buyurtma qaysi raqam/joylashuv bilan yuborilishini oldindan ko'rsatadi
  /// (backend telefonni tasdiqlashni talab qiladi — avvalgidek checkout paytida
  /// ham tekshiriladi, bu yerda esa foydalanuvchi oldindan tasdiqlay oladi).
  Widget _contactCard(LocaleStore loc) {
    final auth = context.watch<AuthStore>();
    if (!auth.isAuthenticated) {
      return Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              loc.t('cart_login_hint'),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    final user = auth.user;
    final phone = user?.phone ?? '';
    final verified = (user?.phoneVerified ?? true) && phone.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:
            Border.all(color: verified ? AppColors.border : AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('cart_contact_title'), style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                verified ? Icons.check_circle_rounded : Icons.phone_outlined,
                size: 20,
                color: verified ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phone.isEmpty ? loc.t('cart_phone_unverified') : phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (!verified)
                TextButton(
                  onPressed: () async {
                    final ok = await showPhoneVerifyDialog(context,
                        initialPhone: phone);
                    if (ok == true && mounted) await auth.refreshUser();
                  },
                  child: Text(loc.t('cart_phone_verify')),
                ),
            ],
          ),
          if (!verified && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                loc.t('cart_phone_unverified'),
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(loc.t('cart_location_note'),
                      style: AppText.caption)),
            ],
          ),
        ],
      ),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: i.imageUrl != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: netImage(
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
                // Tor ekranda narx va miqdor tugmalari sig'masa, ikkinchisi pastki
                // qatorga tushadi (Wrap) — overflow bo'lmaydi.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
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
              Flexible(
                child: Text(
                  '${loc.t('cart_total')} (${cart.count} ${loc.t('unit_pcs')}):',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 8),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.t('cart_delivery'),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  loc.t('cart_delivery_note'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
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
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${formatSom(cart.total.toStringAsFixed(0))} so\'m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      color: AppColors.deep,
                    ),
                  ),
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.42,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
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
            ),
          ),
          const SizedBox(width: 12),
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
                        Flexible(
                          child: Text(
                            loc.t('cart_submit'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
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
