import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/pricing/kiosk_pricing.dart';

void main() {
  const pricing = KioskPricing();

  test('size price comes from the configured product size', () {
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

    expect(
      pricing.sizePrice(
        product,
        product.sizes.single,
      ),
      29,
    );
  });

  test('resolveUnitPrice uses configured size price', () {
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

    expect(
      pricing.resolveUnitPrice(
        product,
        size: product.sizes.single,
      ),
      29,
    );
  });

  test('resolveUnitPrice falls back to product price', () {
    const product = KioskProduct(
      id: 'liempo',
      name: 'Liempo',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );

    expect(
      pricing.resolveUnitPrice(product),
      85,
    );
  });

  test('option prices are added to the resolved base price', () {
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

    const option = KioskOption(
      id: 'pearls',
      name: 'Pearls',
      price: 10,
    );

    expect(
      pricing.resolveUnitPrice(
        product,
        size: product.sizes.single,
        options: [option],
      ),
      39,
    );
  });
}
