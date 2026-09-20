import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/data/kiosk_catalog_data.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/kiosk_catalog_adapter.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  test('automatic charge projects by category as a mandatory kiosk option', () {
    const product = CatalogProduct(
      productId: 'iced_coffee',
      name: 'Iced Coffee',
      productType: 'drink',
      categoryId: 'drinks',
      active: true,
      available: true,
      price: 100,
      sizes: [],
      variants: [],
      options: [],
    );
    const charge = CatalogAutomaticCharge(
      chargeId: 'paper_straw',
      name: 'Paper Straw',
      amount: 2,
      active: true,
      scope: 'category',
      categoryIds: ['drinks'],
    );
    final catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: const [
        ProductCategory(categoryId: 'drinks', name: 'Drinks', subtitle: '', active: true),
      ],
      automaticCharges: const [charge],
      products: const [product],
    );

    final result = KioskCatalogData.automaticChargesForProduct(
      catalog,
      KioskCatalogProduct.fromCatalog(product),
    );

    expect(result, hasLength(1));
    expect(result.single.id, 'paper_straw');
    expect(result.single.price, 2);
    expect(result.single.automatic, isTrue);
  });

  test('automatic charge is not projected to non-matching product', () {
    const product = CatalogProduct(
      productId: 'burger',
      name: 'Burger',
      productType: 'food',
      categoryId: 'food',
      active: true,
      available: true,
      price: 150,
      sizes: [],
      variants: [],
      options: [],
    );
    const charge = CatalogAutomaticCharge(
      chargeId: 'paper_straw',
      name: 'Paper Straw',
      amount: 2,
      active: true,
      scope: 'category',
      categoryIds: ['drinks'],
    );
    final catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: const [
        ProductCategory(categoryId: 'food', name: 'Food', subtitle: '', active: true),
      ],
      automaticCharges: const [charge],
      products: const [product],
    );

    final result = KioskCatalogData.automaticChargesForProduct(
      catalog,
      KioskCatalogProduct.fromCatalog(product),
    );

    expect(result, isEmpty);
  });

  test('automatic charge supports product-type scope', () {
    const product = CatalogProduct(
      productId: 'latte',
      name: 'Latte',
      productType: 'drink',
      categoryId: 'drinks',
      active: true,
      available: true,
      price: 120,
      sizes: [],
      variants: [],
      options: [],
    );
    const charge = CatalogAutomaticCharge(
      chargeId: 'cup_fee',
      name: 'Cup Fee',
      amount: 3,
      active: true,
      scope: 'product_type',
      productTypes: ['drink'],
    );
    final catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: const [
        ProductCategory(categoryId: 'drinks', name: 'Drinks', subtitle: '', active: true),
      ],
      automaticCharges: const [charge],
      products: const [product],
    );

    final result = KioskCatalogData.automaticChargesForProduct(
      catalog,
      KioskCatalogProduct.fromCatalog(product),
    );

    expect(result.single.price, 3);
    expect(result.single.automatic, isTrue);
  });

  test('automatic charge contributes to cart total', () {
    const category = KioskCategory.coffee;
    const product = KioskProduct(
      id: 'latte',
      name: 'Latte',
      price: 120,
      category: category,
      available: true,
      productType: 'drink',
      sizes: [],
      variants: [],
      options: [],
    );
    final cart = KioskCart();
    cart.add(
      product,
      options: const [
        KioskOption(id: 'cup_fee', name: 'Cup Fee', price: 3, automatic: true),
      ],
    );

    expect(cart.items.single.options.single.automatic, isTrue);
    expect(cart.items.single.unitPrice, 123);
    expect(cart.total, 123);
  });

  test('automatic option survives kiosk order JSON round trip', () {
    const category = KioskCategory.coffee;
    const product = KioskProduct(
      id: 'iced_coffee',
      name: 'Iced Coffee',
      price: 100,
      category: category,
      available: true,
      productType: 'drink',
      sizes: [],
      variants: [],
      options: [
        KioskCatalogOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          automatic: true,
        ),
      ],
    );
    final cart = KioskCart();
    cart.add(
      product,
      options: const [
        KioskOption(id: 'paper_straw', name: 'Paper Straw', price: 2, automatic: true),
      ],
    );
    final item = cart.items.single;
    expect(item.options.single.automatic, isTrue);
  });
}
