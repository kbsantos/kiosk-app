import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  test('cart total includes selected drink add-ons', () {
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
        KioskOption(
          id: 'whipcream',
          name: 'Whipcream',
          price: 30,
        ),
      ],
    );

    expect(cart.items.single.unitPrice, 89);
    expect(cart.total, 89);
  });
}
