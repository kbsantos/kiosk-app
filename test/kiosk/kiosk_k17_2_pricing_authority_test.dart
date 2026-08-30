import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/product_catalog/kiosk_catalog_adapter.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  const category = ProductCategory(
    categoryId: 'rice_meals',
    name: 'Rice Meals',
    subtitle: '',
    active: true,
  );

  test('catalog product base price survives the kiosk adapter', () {
    const product = CatalogProduct(
      productId: 'liempo',
      name: 'Liempo',
      productType: 'food',
      categoryId: 'rice_meals',
      active: true,
      available: true,
      price: 85,
      sizes: [],
      variants: [],
      options: [],
    );

    const catalog = ProductCatalog(
      catalogVersion: '4.0.0',
      categories: [category],
      products: [product],
    );

    final adapted = const KioskCatalogAdapter()
        .productsForCategory(catalog, 'rice_meals')
        .single;

    expect(adapted.price, 85);
  });

  test('catalog size prices remain the source for sized drinks', () {
    const product = CatalogProduct(
      productId: 'classic_milktea',
      name: 'Classic Milktea',
      productType: 'drink',
      categoryId: 'rice_meals',
      active: true,
      available: true,
      sizes: [
        ProductSize(sizeId: 'regular', name: 'Regular', price: 29),
        ProductSize(sizeId: 'go_big', name: 'Go Big', price: 39),
        ProductSize(sizeId: 'go_bigger', name: 'Go Bigger', price: 69),
      ],
      variants: [],
      options: [],
    );

    const catalog = ProductCatalog(
      catalogVersion: '4.0.0',
      categories: [category],
      products: [product],
    );

    final adapted = const KioskCatalogAdapter()
        .productsForCategory(catalog, 'rice_meals')
        .single;

    expect(adapted.sizes.map((size) => size.price), [29, 39, 69]);
  });
}
