import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/kiosk/reporting/kiosk_automatic_charge_summary.dart';

void main() {
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

  KioskOrder order({
    required KioskOrderStatus status,
    required List<KioskOption> options,
    int quantity = 1,
    int total = 125,
  }) {
    return KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-0001',
      createdAt: DateTime(2026, 9, 20, 10),
      orderType: 'Dine In',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: status,
      items: [
        KioskCartItem(
          product: product,
          quantity: quantity,
          options: options,
        ),
      ],
      total: total,
    );
  }

  test('summarizes automatic charges from completed orders only', () {
    final completed = order(
      status: KioskOrderStatus.completed,
      options: const [
        KioskOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          automatic: true,
        ),
      ],
      quantity: 2,
      total: 244,
    );
    final cancelled = order(
      status: KioskOrderStatus.cancelled,
      options: const [
        KioskOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          automatic: true,
        ),
      ],
    );

    final summary = KioskAutomaticChargeSummary.fromOrders(
      [completed, cancelled],
    );

    expect(summary.lines, hasLength(1));
    expect(summary.lines.single.id, 'paper_straw');
    expect(summary.lines.single.quantity, 2);
    expect(summary.lines.single.amount, 4);
    expect(summary.totalQuantity, 2);
    expect(summary.totalAmount, 4);
  });

  test('does not include selectable add-ons in automatic-charge totals', () {
    final completed = order(
      status: KioskOrderStatus.completed,
      options: const [
        KioskOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          automatic: true,
        ),
        KioskOption(
          id: 'extra_shot',
          name: 'Extra Shot',
          price: 20,
        ),
      ],
      total: 142,
    );

    final summary = KioskAutomaticChargeSummary.fromOrders([completed]);

    expect(summary.totalAmount, 2);
    expect(summary.lines.single.name, 'Paper Straw');
  });

  test('multiple automatic charges are grouped by charge id', () {
    final completed = order(
      status: KioskOrderStatus.completed,
      options: const [
        KioskOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          automatic: true,
        ),
        KioskOption(
          id: 'packaging_fee',
          name: 'Packaging Fee',
          price: 5,
          automatic: true,
        ),
      ],
      total: 127,
    );

    final summary = KioskAutomaticChargeSummary.fromOrders([completed]);

    expect(summary.lines.map((line) => line.id), [
      'packaging_fee',
      'paper_straw',
    ]);
    expect(summary.totalQuantity, 2);
    expect(summary.totalAmount, 7);
  });
}
