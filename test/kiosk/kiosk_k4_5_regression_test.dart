import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/pricing/kiosk_pricing.dart';

void main() {
  test('drink pricing resolves through its configured size', () {
    const product = KioskProduct(
      id: 'classic_milktea',
      name: 'Classic Milktea',
      price: null,
      category: KioskCategory.milkTea,
      sizes: [
        KioskSize(
          id: 'regular',
          name: 'Regular',
          displayVolume: '12oz',
          price: 29,
        ),
      ],
    );

    const pricing = KioskPricing();

    expect(
      pricing.resolveUnitPrice(
        product,
        size: product.sizes.single,
      ),
      29,
    );
  });

  test('KioskCartItem is available to counter order details', () {
    const product = KioskProduct(
      id: 'liempo',
      name: 'Liempo',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );

    const item = KioskCartItem(
      product: product,
    );

    expect(item.product.name, 'Liempo');
    expect(item.total, 85);
  });
}
