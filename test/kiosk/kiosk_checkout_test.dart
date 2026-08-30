import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  test('checkout cart total remains correct before submission', () {
    const product = KioskProduct(
      id: 'iced_americano',
      name: 'Iced Americano',
      price: null,
      category: KioskCategory.coffee,
      sizes: [
        KioskSize(
          id: 'regular',
          name: 'Regular',
          displayVolume: '12oz',
          price: 39,
        ),
      ],
    );

    final cart = KioskCart();
    cart.add(
      product,
      size: product.sizes.single,
      options: const [
        KioskOption(
          id: 'espresso_shot',
          name: 'Espresso Shot',
          price: 20,
        ),
      ],
    );

    expect(cart.itemCount, 1);
    expect(cart.total, 59);
  });

  test('clearing the cart removes the order after confirmation', () {
    const product = KioskProduct(
      id: 'liempo',
      name: 'Liempo',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );

    final cart = KioskCart();
    cart.add(product);

    expect(cart.items, isNotEmpty);

    cart.clear();

    expect(cart.items, isEmpty);
    expect(cart.itemCount, 0);
    expect(cart.total, 0);
  });
}
