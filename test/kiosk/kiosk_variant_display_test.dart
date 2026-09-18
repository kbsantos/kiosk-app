import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/product_catalog/kiosk_catalog_adapter.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_transaction_mapper.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  final category = KioskCategory.fromCatalog(
    id: 'snacks',
    title: 'Snacks',
    icon: '🍟',
  );
  const variant = KioskVariant(
    id: 'cheese',
    name: 'Cheese',
    price: 95,
  );
  final product = KioskProduct(
    id: 'french_fries',
    name: 'French Fries',
    category: category,
    price: 90,
    variants: [variant],
  );

  test('displayLabel includes selected variant and options', () {
    final item = KioskCartItem(
      product: product,
      variant: variant,
      options: [
        KioskOption(id: 'ketchup', name: 'Ketchup', price: 5),
      ],
    );

    expect(item.displayLabel, 'French Fries — Cheese — Ketchup');
  });

  test('selected variant survives order JSON round trip', () {
    final item = KioskCartItem(
      product: product,
      variant: variant,
    );
    final order = KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-0001',
      createdAt: DateTime(2026, 8, 23, 10),
      orderType: 'Dine In',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      items: [item],
      total: item.total,
    );

    final restored = KioskOrder.fromJson(order.toJson());
    expect(restored.items.single.variant?.id, 'cheese');
    expect(restored.items.single.variant?.name, 'Cheese');
    expect(restored.items.single.displayLabel, 'French Fries — Cheese');
  });


  test('catalog variant price and active state flow into kiosk ordering and reporting', () {
    const catalogProduct = CatalogProduct(
      productId: 'french_fries',
      name: 'French Fries',
      productType: 'food',
      categoryId: 'snacks',
      active: true,
      available: true,
      price: 90,
      sizes: [],
      variants: [
        ProductVariant(
          variantId: 'cheese',
          name: 'Cheese',
          price: 95,
          active: true,
        ),
        ProductVariant(
          variantId: 'old_flavor',
          name: 'Old Flavor',
          price: 80,
          active: false,
        ),
      ],
      options: [],
    );
    const catalog = ProductCatalog(
      catalogVersion: 'master-2',
      categories: [
        ProductCategory(
          categoryId: 'snacks',
          name: 'Snacks',
          subtitle: '',
          active: true,
        ),
      ],
      products: [catalogProduct],
    );

    const adapter = KioskCatalogAdapter();
    final projected = adapter.productsForCategory(catalog, 'snacks').single;
    expect(projected.variants.map((variant) => variant.variantId), [
      'cheese',
      'old_flavor',
    ]);
    expect(projected.variants.first.price, 95);
    expect(projected.variants.last.active, isFalse);

    final kioskProduct = KioskProduct(
      id: projected.productId,
      name: projected.name,
      category: KioskCategory.fromCatalog(
        id: 'snacks',
        title: 'Snacks',
      ),
      price: projected.price?.toInt(),
      variants: projected.variants
          .map(
            (variant) => KioskVariant(
              id: variant.variantId,
              name: variant.name,
              price: variant.price?.toInt(),
              active: variant.active,
            ),
          )
          .toList(growable: false),
    );
    final cart = KioskCart();
    final selectedVariant = kioskProduct.activeVariants.single;
    cart.add(kioskProduct, variant: selectedVariant);

    final order = KioskOrder(
      id: 'order-variant-flow',
      orderNumber: 'BB-0100',
      createdAt: DateTime(2026, 9, 18, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      items: cart.items,
      total: cart.total,
    );

    expect(order.items.single.variant!.name, 'Cheese');
    expect(order.items.single.variant!.price, 95);
    expect(order.items.single.unitPrice, 95);

    final payload = const ReportingTransactionMapper().mapOrder(
      order: order,
      storeId: '00000000-0000-4000-8000-000000000001',
      deviceId: 'KIOSK-01',
    );
    final item = payload.items.single;
    expect(item['variant_id'], 'cheese');
    expect(item['variant_name'], 'Cheese');
    expect(item['unit_price'], 95);
    expect(item['total'], 95);
  });

}