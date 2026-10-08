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

      final plain = Variant(id: 'a', name: 'o', basePrice: '2000000');
      final discounted = Variant(
        id: 'b',
        name: 'o',
        basePrice: '2000000',
        discountActive: true,
        effectiveBasePrice: '1700000',
        discountPercent: 15,
      );
      await tester.pumpWidget(_app(
        Scaffold(
          body: Column(children: [
            PriceBlock(variant: plain, large: true),
            PriceBlock(variant: discounted, large: true),
            PriceBlock(variant: discounted, fromSuffix: true),
          ]),
        ),
        textScale: scale,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('-15%'), findsNWidgets(2));
    });
  }
}
