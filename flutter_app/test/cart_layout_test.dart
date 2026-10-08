import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furniture_platform_mobile/auth_store.dart';
import 'package:furniture_platform_mobile/cart_store.dart';
import 'package:furniture_platform_mobile/likes_store.dart';
import 'package:furniture_platform_mobile/location_store.dart';
import 'package:furniture_platform_mobile/locale_store.dart';
import 'package:furniture_platform_mobile/models.dart';
import 'package:furniture_platform_mobile/screens/cart_screen.dart';
import 'package:furniture_platform_mobile/theme.dart';
import 'package:furniture_platform_mobile/widgets/price_block.dart';

Product _product(String id, String company, String name) => Product(
      id: id,
      company: company,
      companyName:
          'Juda uzun nomli mebel ishlab chiqaruvchi firma $company MCHJ',
      nameUz: name,
      isPublished: true,
      variants: [Variant(id: 'v$id', name: 'oddiy', basePrice: '1234567')],
    );

Widget _app(Widget child, {double textScale = 1.0, CartStore? cart}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleStore()),
      ChangeNotifierProvider(create: (_) => AuthStore()),
      ChangeNotifierProvider(create: (_) => LikesStore()),
      ChangeNotifierProvider(create: (_) => LocationStore()),
      ChangeNotifierProvider<CartStore>.value(value: cart ?? CartStore()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!,
      ),
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('CartScreen (2 firma): ${width}px x$scale — overflow yo\'q',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final cart = CartStore();
        cart.addProduct(
            _product(
                '1', 'A', "Bambuk uslubidagi to'qilgan juda uzun nomli stul"),
            _product('1', 'A', 'x').variants.first,
            qty: 2);
        cart.addProduct(_product('2', 'B', 'Divan'),
            _product('2', 'B', 'x').variants.first);

        await tester
            .pumpWidget(_app(const CartScreen(), textScale: scale, cart: cart));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(CartScreen), findsOneWidget);
      });
    }
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets('PriceBlock chegirma bilan va chegirmasiz: x$scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const plain = PricingInfo(
          originalPrice: 2000000,
          discountPercent: 0,
          discountAmount: 0,
          finalPrice: 2000000);
      const discounted = PricingInfo(
          originalPrice: 2000000,
          discountPercent: 15,
          discountAmount: 300000,
          finalPrice: 1700000);
      await tester.pumpWidget(_app(
        const Scaffold(
          body: Column(children: [
            PriceBlock(pricing: plain, large: true),
            PriceBlock(pricing: discounted, large: true),
            PriceBlock(pricing: discounted, fromSuffix: true),
            VerifiedBadge(),
          ]),
        ),
        textScale: scale,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('-15%'), findsNWidgets(2));
    });
  }

  test(
      'Product.fromJson backend pricing, delivery, tasdiqlangan firma, kategoriya rasmini o\'qiydi',
      () {
    final p = Product.fromJson({
      'id': 'p1',
      'company': 'c1',
      'company_name': 'Mebel House',
      'name_uz': 'Divan',
      'is_published': true,
      'variants': [
        {
          'id': 'v1',
          'name': 'oddiy',
          'base_price': '5000000.00',
          'pricing': {
            'original_price': 5000000.0,
            'discount_percent': 20.0,
            'discount_amount': 1000000.0,
            'final_price': 4000000.0,
          },
        }
      ],
      'pricing': {
        'original_price': 5000000.0,
        'discount_percent': 20.0,
        'discount_amount': 1000000.0,
        'final_price': 4000000.0,
      },
      'company_is_verified': true,
      'delivery': {
        'free': false,
        'price': 30000.0,
        'min_days': 2,
        'max_days': 4
      },
      'category_image_url': 'https://x/c.png',
    });
    expect(p.companyIsVerified, isTrue);
    expect(p.displayPricing!.finalPrice, 4000000.0);
    expect(p.displayPricing!.hasDiscount, isTrue);
    expect(p.variants.first.effectivePriceValue,
        4000000.0); // savat ham backend narxini ishlatadi
    expect(p.delivery!.minDays, 2);
    expect(p.delivery!.free, isFalse);
    expect(p.categoryImageUrl, 'https://x/c.png');
  });

  test('Eski javob (pricing/delivery yo\'q): null va orqaga moslik', () {
    final p = Product.fromJson({
      'id': 'p1',
      'company': 'c1',
      'company_name': 'X',
      'name_uz': 'Y',
      'is_published': true,
      'variants': [
        {
          'id': 'v1',
          'name': 'o',
          'base_price': '1000',
          'discount_active': true,
          'effective_base_price': '800.00',
          'discount_percent': '20.00'
        }
      ],
    });
    expect(p.delivery, isNull);
    expect(p.companyIsVerified, isFalse);
    expect(p.displayPricing!.finalPrice, 800.0);
  });
}
