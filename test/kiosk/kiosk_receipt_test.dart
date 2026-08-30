import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('receipt source order preserves item, size, add-on and payment data', () {
    const product = KioskProduct(
      id: 'matcha',
      name: 'Iced Matcha Latte',
      price: null,
      category: KioskCategory.coffee,
      sizes: [
        KioskSize(
          id: 'go_big',
          name: 'Go Big',
          displayVolume: '22oz',
          price: 69,
        ),
      ],
    );

    const option = KioskOption(
      id: 'pearl',
      name: 'Pearl',
      price: 10,
    );

    final item = KioskCartItem(
      product: product,
      size: product.sizes.single,
      options: const [option],
      quantity: 1,
    );

    final order = KioskOrder(
      id: 'receipt-1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 16, 10),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      items: [item],
      total: item.total,
    );

    expect(order.orderNumber, 'BB-001');
    expect(order.items.single.product.name, 'Iced Matcha Latte');
    expect(order.items.single.size?.displayVolume, '22oz');
    expect(order.items.single.options.single.name, 'Pearl');
    expect(order.paymentStatus, 'paid');
    expect(order.total, 79);
  });
}
