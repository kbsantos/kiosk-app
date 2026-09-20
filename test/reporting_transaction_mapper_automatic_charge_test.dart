import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_transaction_mapper.dart';

void main() {
  test('reporting mapper preserves automatic charge metadata and amount', () {
    const product = KioskProduct(
      id: 'latte',
      name: 'Latte',
      price: 120,
      category: KioskCategory.coffee,
    );
    const charge = KioskOption(
      id: 'paper_straw',
      name: 'Paper Straw',
      price: 2,
      automatic: true,
    );
    const item = KioskCartItem(
      product: product,
      options: [charge],
      quantity: 2,
    );
    final order = KioskOrder(
      id: 'order-automatic-charge',
      orderNumber: 'BB-010',
      createdAt: DateTime(2026, 9, 20, 12),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      items: const [item],
      total: item.total,
    );

    final payload = const ReportingTransactionMapper().mapOrder(
      order: order,
      storeId: 'store-1',
      deviceId: 'device-1',
    );
    final mappedOption = payload.items.single['options'] as List<dynamic>;
    final option = mappedOption.single as Map<String, dynamic>;

    expect(payload.total, 244);
    expect(option['option_id'], 'paper_straw');
    expect(option['option_name'], 'Paper Straw');
    expect(option['price'], 2);
    expect(option['automatic'], true);
  });
}
