import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_platform_mobile/models.dart';

void main() {
  _renderGalleryTests();
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

void _renderGalleryTests() {
  group('Product.galleryFor (render rasmlari)', () {
    Product make(Map<String, dynamic> extra) => Product.fromJson({
          'id': 'p1',
          'company': 'c',
          'company_name': 'F',
          'name_uz': 'Stol',
          'slug': 'stol',
          'is_published': true,
          'variants': [
            {'id': 'v1', 'name': 'Oq', 'base_price': '1', 'width': '1', 'height': '1', 'depth': '1'},
            {'id': 'v2', 'name': 'Qora', 'base_price': '1', 'width': '1', 'height': '1', 'depth': '1'},
          ],
          'images': [
            {'id': 'i1', 'image_url': 'https://x/real.jpg'},
          ],
          'image_url': 'https://x/hero-render.png',
          ...extra,
        });

    Map<String, dynamic> group(String name, String id, List<String> keys) => {
          'variant': name,
          'slug': name.toLowerCase(),
          'variant_id': id,
          'shots': [
            for (final k in keys)
              {
                'key': k,
                'urls': {
                  '400': {'webp': 'https://x/$name-$k-400.webp'},
                  '1600': {'webp': 'https://x/$name-$k-1600.webp'},
                },
              },
          ],
        };

    test('variant almashganda galereya o\'zgaradi, tartib hero → front', () {
      final p = make({
        'renders': [
          group('Oq', 'v1', ['front', 'hero']),
          group('Qora', 'v2', ['hero']),
        ],
      });
      final oq = p.variants[0];
      final qora = p.variants[1];
      expect(p.galleryFor(oq), [
        'https://x/Oq-hero-1600.webp',
        'https://x/Oq-front-1600.webp',
        'https://x/real.jpg',
      ]);
      expect(p.galleryFor(qora), ['https://x/Qora-hero-1600.webp', 'https://x/real.jpg']);
    });

    test('render bo\'lmasa eski galereya', () {
      final p = make({});
      expect(p.galleryFor(p.variants.first), ['https://x/hero-render.png', 'https://x/real.jpg']);
    });
  });
}
