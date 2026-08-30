import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_product_catalog_page.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  const category = ProductCategory(
    categoryId: 'drinks',
    name: 'Drinks',
    subtitle: 'Cold drinks',
    active: true,
  );

  const secondCategory = ProductCategory(
    categoryId: 'meals',
    name: 'Meals',
    subtitle: 'Rice meals',
    active: true,
  );

  const drink = CatalogProduct(
    productId: 'classic_milk_tea',
    name: 'Classic Milk Tea',
    productType: 'drink',
    categoryId: 'drinks',
    active: true,
    available: true,
    sizes: [ProductSize(sizeId: '22oz', name: '22oz', price: 89)],
    variants: [],
    options: [],
  );

  const meal = CatalogProduct(
    productId: 'liempo',
    name: 'Liempo',
    productType: 'food',
    categoryId: 'meals',
    active: true,
    available: true,
    kitchenPrepared: true,
    sizes: [],
    variants: [],
    options: [],
  );

  const inactive = CatalogProduct(
    productId: 'old_drink',
    name: 'Old Drink',
    productType: 'drink',
    categoryId: 'drinks',
    active: false,
    available: false,
    sizes: [],
    variants: [],
    options: [],
  );

  const catalog = ProductCatalog(
    catalogVersion: 'test',
    categories: [category, secondCategory],
    products: [drink, meal, inactive],
  );

  test('returns all products without filters', () {
    expect(filterCatalogProducts(catalog), hasLength(3));
  });

  test('search matches product name, id and sku', () {
    expect(filterCatalogProducts(catalog, query: 'classic'), [drink]);
    expect(filterCatalogProducts(catalog, query: 'liempo'), [meal]);
  });

  test('category filter limits products', () {
    expect(
      filterCatalogProducts(catalog, categoryId: 'meals'),
      [meal],
    );
  });

  test('active only excludes inactive products', () {
    expect(
      filterCatalogProducts(catalog, activeOnly: true),
      [drink, meal],
    );
  });
}
