import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  test('drink size can carry independent price', () {
    const size = KioskSize(
      id: 'regular',
      name: 'Regular',
      volumeMl: 355,
      displayVolume: '12oz',
      price: 49,
    );

    const product = KioskProduct(
      id: 'dark_chocolate',
      name: 'Dark Chocolate',
      price: null,
      category: KioskCategory.milkTea,
      sizes: [size],
    );

    expect(product.hasSizes, isTrue);
    expect(product.priceConfigured, isTrue);
    expect(product.sizes.single.price, 49);
  });

  test('cart uses selected size price', () {
    const size = KioskSize(
      id: 'go_big',
      name: 'Go Big',
      volumeMl: 650,
      displayVolume: '22oz',
      price: 69,
    );

    const product = KioskProduct(
      id: 'dark_chocolate',
      name: 'Dark Chocolate',
      price: null,
      category: KioskCategory.milkTea,
      sizes: [size],
    );

    final cart = KioskCart();
    cart.add(product, size: size);

    expect(cart.items.single.size?.id, 'go_big');
    expect(cart.items.single.unitPrice, 69);
    expect(cart.total, 69);
  });
}
