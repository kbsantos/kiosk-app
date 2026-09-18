import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/catalog/historical_catalog_recovery.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';

void main() {
  ProductCatalog catalog({
    List<ProductVariant> variants = const [],
    List<ProductOption> options = const [],
    List<CatalogOptionDefinition> definitions = const [],
  }) {
    return ProductCatalog(
      catalogVersion: 'master-1',
      categories: const [
        ProductCategory(
          categoryId: 'coffee',
          name: 'Coffee',
          subtitle: '',
          active: true,
        ),
      ],
      optionDefinitions: definitions,
      products: [
        CatalogProduct(
          productId: 'latte',
          name: 'Latte',
          productType: 'drink',
          categoryId: 'coffee',
          active: true,
          available: true,
          price: 100,
          sizes: const [],
          variants: variants,
          options: options,
        ),
      ],
    );
  }

  KioskOrder orderWith({KioskVariant? variant, List<KioskOption> options = const []}) {
    final product = KioskProduct(
      id: 'latte',
      name: 'Latte',
      price: 100,
      category: KioskCategory.coffee,
      options: const [],
    );
    final item = KioskCartItem(product: product, variant: variant, options: options);
    return KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 9, 19, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      status: KioskOrderStatus.completed,
      items: [item],
      total: item.total,
    );
  }

  test('recovers a missing variant from historical transaction snapshot', () {
    final result = HistoricalCatalogRecovery.recover(
      catalog(),
      [
        orderWith(
          variant: const KioskVariant(
            id: 'oat',
            name: 'Oat Milk',
            price: 20,
          ),
        ),
      ],
    );

    final variant = result.catalog.products.single.variants.single;
    expect(variant.variantId, 'oat');
    expect(variant.name, 'Oat Milk');
    expect(variant.price, 20);
    expect(variant.active, isTrue);
    expect(result.recoveredVariants, 1);
  });

  test('recovers missing option definition and product assignment', () {
    final result = HistoricalCatalogRecovery.recover(
      catalog(),
      [
        orderWith(
          options: const [
            KioskOption(
              id: 'extra_shot',
              name: 'Extra Shot',
              price: 30,
              kitchenPrepared: true,
            ),
          ],
        ),
      ],
    );

    expect(result.recoveredOptionDefinitions, 1);
    expect(result.recoveredProductOptions, 1);
    expect(() => ProductCatalogRepository.validate(result.catalog), returnsNormally);
    expect(result.catalog.optionDefinitions.single.optionId, 'extra_shot');
    expect(result.catalog.optionDefinitions.single.productTypes, ['drink']);
    expect(result.catalog.products.single.options.single.optionId, 'extra_shot');
    expect(result.catalog.products.single.options.single.price, 30);
    expect(result.catalog.products.single.options.single.kitchenPrepared, isTrue);
  });

  test('is idempotent when historical variant and option are already present', () {
    final current = catalog(
      variants: const [
        ProductVariant(variantId: 'oat', name: 'Oat Milk', price: 20, active: true),
      ],
      definitions: const [
        CatalogOptionDefinition(
          optionId: 'extra_shot',
          name: 'Extra Shot',
          productTypes: ['drink'],
          price: 30,
          active: true,
          kitchenPrepared: true,
        ),
      ],
      options: const [
        ProductOption(
          optionId: 'extra_shot',
          name: 'Extra Shot',
          price: 30,
          active: true,
          kitchenPrepared: true,
        ),
      ],
    );

    final result = HistoricalCatalogRecovery.recover(
      current,
      [
        orderWith(
          variant: const KioskVariant(id: 'oat', name: 'Oat Milk', price: 20),
          options: const [
            KioskOption(id: 'extra_shot', name: 'Extra Shot', price: 30, kitchenPrepared: true),
          ],
        ),
      ],
    );

    expect(result.recoveredVariants, 0);
    expect(result.recoveredOptionDefinitions, 0);
    expect(result.recoveredProductOptions, 0);
    expect(result.catalog.toJson(), current.toJson());
  });

  test('does not auto-recover conflicting historical variant definitions', () {
    final result = HistoricalCatalogRecovery.recover(
      catalog(),
      [
        orderWith(
          variant: const KioskVariant(id: 'oat', name: 'Oat Milk', price: 20),
        ),
        KioskOrder(
          id: 'order-2',
          orderNumber: 'BB-002',
          createdAt: DateTime(2026, 9, 19, 11),
          orderType: 'Take Out',
          paymentMethod: 'Cash',
          status: KioskOrderStatus.completed,
          items: [
            KioskCartItem(
              product: KioskProduct(
                id: 'latte',
                name: 'Latte',
                price: 100,
                category: KioskCategory.coffee,
              ),
              variant: const KioskVariant(id: 'oat', name: 'Oat Milk', price: 25),
            ),
          ],
          total: 125,
        ),
      ],
    );

    expect(result.catalog.products.single.variants, isEmpty);
    expect(result.conflicts, contains('variant:latte:oat'));
  });
}
