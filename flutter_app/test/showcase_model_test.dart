import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_platform_mobile/models.dart';

void main() {
  test('ShowcaseProduct.fromJson: nom, narx va galereya', () {
    final p = ShowcaseProduct.fromJson({
      'id': 'abc',
      'name': 'Диван',
      'description': '',
      'image_url': 'https://x/a.png',
      'images': ['https://x/a.png', 'https://x/b.png'],
      'price_from': '1500000.00',
    });
    expect(p.name, 'Диван');
    expect(p.priceFrom, 1500000);
    expect(p.gallery, ['https://x/a.png', 'https://x/b.png']);
  });

  test('ShowcaseProduct: narx va rasm yo\'q bo\'lsa null/bo\'sh', () {
    final p = ShowcaseProduct.fromJson({'id': 1, 'name': 'X', 'images': []});
    expect(p.priceFrom, isNull);
    expect(p.gallery, isEmpty);
    expect(p.description, '');
  });
}
