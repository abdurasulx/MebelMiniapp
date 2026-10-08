import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furniture_platform_mobile/auth_store.dart';
import 'package:furniture_platform_mobile/likes_store.dart';
import 'package:furniture_platform_mobile/locale_store.dart';
import 'package:furniture_platform_mobile/models.dart';
import 'package:furniture_platform_mobile/theme.dart';
import 'package:furniture_platform_mobile/widgets/product_card.dart';

Product _product(String name, {String company = 'Test firma'}) => Product(
      id: name.hashCode.toString(),
      company: 'c1',
      companyName: company,
      nameUz: name,
      isPublished: true,
      availableQuantity: 12,
      variants: [Variant(id: 'v1', name: 'oddiy', basePrice: '1234567')],
    );

Widget _app(Widget child, {double textScale = 1.0}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleStore()),
      ChangeNotifierProvider(create: (_) => AuthStore()),
      ChangeNotifierProvider(create: (_) => LikesStore()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final names = [
    'Stul',
    "Bambuk uslubidagi to'qilgan juda uzun nomli ajoyib mebel to'plami stul",
    'Zamonaviy yumshoq 3 kishilik burchakli divan-karavat transformer',
  ];

  // Ekran kengliklari (mantiqiy piksel) va matn masshtablari: kichik/standart/katta.
  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('ProductCard grid: ${width}px, text x$scale — overflow yo\'q', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemCount: names.length,
            itemBuilder: (_, i) => ProductCard(
              product: _product(names[i], company: 'Juda uzun nomli mebel ishlab chiqaruvchi firma MCHJ'),
            ),
          ),
          textScale: scale,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(ProductCard), findsWidgets);
      });
    }
  }
}
