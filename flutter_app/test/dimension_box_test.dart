import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furniture_platform_mobile/locale_store.dart';
import 'package:furniture_platform_mobile/models.dart';
import 'package:furniture_platform_mobile/theme.dart';
import 'package:furniture_platform_mobile/widgets/dimension_box.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hajm m³ (ortiqcha nollarsiz)', () {
    expect(DimensionBox.volume(0.51, 1.0, 0.67), '0.342');
    expect(DimensionBox.volume(2, 1, 1), '2');
    expect(DimensionBox.volume(1.2, 0.8, 2.0), '1.92');
  });

  test('standart 1x1x1 (to\'ldirilmagan) variant o\'lchami ko\'rsatilmaydi', () {
    final placeholder = Variant(id: 'v', name: 'o', basePrice: '1');
    expect(DimensionBox.resolve(null, placeholder), isNull);
    final real = Variant(id: 'v', name: 'o', basePrice: '1', width: '0.5', height: '0.9', depth: '0.4');
    final r = DimensionBox.resolve(null, real)!;
    expect((r.w, r.h, r.d), (0.5, 0.9, 0.4));
    expect(DimensionBox.resolve(null, null), isNull);
  });

  for (final width in [320.0, 411.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('DimensionBox ${width}px x$scale — overflow yo\'q (uzun/past/keng shakllar)', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => LocaleStore())],
          child: MaterialApp(
            theme: buildAppTheme(),
            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
              child: w!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  DimensionBox(widthM: 0.51, heightM: 1.0, depthM: 0.67),
                  DimensionBox(widthM: 3.2, heightM: 0.4, depthM: 0.9), // keng va past
                  DimensionBox(widthM: 0.3, heightM: 2.2, depthM: 0.3), // uzun va tor
                ]),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
