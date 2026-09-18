import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/historical_reporting_integrity.dart';

KioskCartItem item({
  required String productId,
  required String productName,
  required String categoryId,
  required int unitPrice,
  int quantity = 1,
  KioskVariant? variant,
  List<KioskOption> options = const [],
}) {
  return KioskCartItem(
    product: KioskProduct(
      id: productId,
      name: productName,
      price: unitPrice,
      category: KioskCategory.fromCatalog(id: categoryId, title: categoryId),
    ),
    quantity: quantity,
    variant: variant,
    options: options,
  );
}

KioskOrder order({
  required String id,
  required KioskOrderStatus status,
  required List<KioskCartItem> items,
  required int total,
  String? catalogVersion = 'db-v10',
}) {
  return KioskOrder(
    id: id,
    orderNumber: id,
    createdAt: DateTime(2026, 9, 19, 10),
    orderType: 'Take Out',
    paymentMethod: 'Cash',
    paymentStatus: 'paid',
    status: status,
    catalogVersion: catalogVersion,
    items: items,
    total: total,
  );
}

void main() {
  test('completed reporting snapshot preserves category, variant and option totals', () {
    final variant = const KioskVariant(id: 'large', name: 'Large', price: 20);
    final option = const KioskOption(id: 'extra-shot', name: 'Extra Shot', price: 15);
    final sale = item(
      productId: 'latte',
      productName: 'Latte',
      categoryId: 'coffee',
      unitPrice: 135,
      quantity: 2,
      variant: variant,
      options: [option],
    );

    final result = HistoricalReportingIntegrity.analyze([
      order(id: 'R-001', status: KioskOrderStatus.completed, items: [sale], total: sale.total),
    ]);

    expect(result.isValid, isTrue);
    expect(result.completedOrders, 1);
    expect(result.itemsSold, 2);
    expect(result.salesTotal, sale.total);
    expect(result.categorySales['coffee'], sale.total);
    expect(result.productSales['latte'], sale.total);
    expect(result.variantSales['large'], sale.total);
    expect(result.optionSales['extra-shot'], 30);
  });

  test('cancelled transactions do not contribute to sales aggregates', () {
    final sale = item(
      productId: 'rice',
      productName: 'Rice Meal',
      categoryId: 'meals',
      unitPrice: 100,
      quantity: 1,
    );
    final cancelled = order(
      id: 'R-002',
      status: KioskOrderStatus.cancelled,
      items: [sale],
      total: sale.total,
    );

    final result = HistoricalReportingIntegrity.analyze([
      order(id: 'R-003', status: KioskOrderStatus.completed, items: [sale], total: sale.total),
      cancelled,
    ]);

    expect(result.isValid, isTrue);
    expect(result.completedOrders, 1);
    expect(result.salesTotal, sale.total);
    expect(result.itemsSold, 1);
  });

  test('historical snapshot flags an order total mismatch without changing the order', () {
    final sale = item(
      productId: 'coffee',
      productName: 'Coffee',
      categoryId: 'coffee',
      unitPrice: 80,
      quantity: 2,
    );
    final original = order(
      id: 'R-004',
      status: KioskOrderStatus.completed,
      items: [sale],
      total: 999,
    );

    final result = HistoricalReportingIntegrity.analyze([original]);

    expect(result.isValid, isFalse);
    expect(result.issues.single.orderId, 'R-004');
    expect(result.issues.single.code, 'order_total_mismatch');
    expect(original.total, 999);
  });

  test('legacy orders without catalog version remain valid for reporting', () {
    final sale = item(
      productId: 'snack',
      productName: 'Snack',
      categoryId: 'accessories',
      unitPrice: 50,
    );

    final result = HistoricalReportingIntegrity.analyze([
      order(
        id: 'R-005',
        status: KioskOrderStatus.completed,
        items: [sale],
        total: sale.total,
        catalogVersion: null,
      ),
    ]);

    expect(result.isValid, isTrue);
    expect(result.legacyCatalogVersionOrders, 1);
    expect(result.salesTotal, 50);
  });
}
