import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';

void main() {
  test('loads legacy catalog without categories by deriving referenced categories', () {
    final catalog = ProductCatalog.fromJson({
      'catalogVersion': 'legacy',
      'optionDefinitions': [],
      'products': [
        {
          'productId': 'classic_milktea',
          'name': 'Classic Milktea',
          'productType': 'drink',
          'categoryId': 'milk_tea',
          'active': true,
          'available': true,
          'price': 29,
          'sizes': [],
          'variants': [],
          'options': [],
        },
      ],
    });

    expect(catalog.categories, hasLength(1));
    expect(catalog.categories.first.categoryId, 'milk_tea');
    expect(catalog.categories.first.name, 'Milk Tea');
    expect(catalog.products.first.price, 29);
    expect(catalog.products.first.toJson()['price'], 29);
  });

  test('catalog validation rejects negative commercial prices', () {
    const category = ProductCategory(
      categoryId: 'food',
      name: 'Food',
      subtitle: '',
      active: true,
    );
    const product = CatalogProduct(
      productId: 'bad_price',
      name: 'Bad Price',
      productType: 'food',
      categoryId: 'food',
      active: true,
      available: true,
      price: -1,
      sizes: [],
      variants: [],
      options: [],
    );

    expect(
      () => ProductCatalogRepository.validate(
        const ProductCatalog(
          catalogVersion: 'test',
          categories: [category],
          products: [product],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
  test('category icon is persisted and restored from catalog JSON', () {
    const category = ProductCategory(
      categoryId: 'seasonal',
      name: 'Seasonal Drinks',
      subtitle: 'Limited time',
      active: true,
      icon: '⭐',
    );

    final restored = ProductCategory.fromJson(category.toJson());

    expect(restored.icon, '⭐');
    expect(restored.toJson()['icon'], '⭐');
  });

}
