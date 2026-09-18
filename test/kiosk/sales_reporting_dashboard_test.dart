import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/sales_reporting_dashboard.dart';

KioskOrder _order({
  required String id,
  required DateTime createdAt,
  required KioskOrderStatus status,
  required int total,
  String paymentMethod = 'Cash',
  String orderMode = 'Customer',
  int productPrice = 100,
}) {
  final product = KioskProduct(
    id: 'coffee',
    name: 'Coffee',
    price: productPrice,
    category: KioskCategory.fromCatalog(id: 'drinks', title: 'Drinks'),
  );
  final item = KioskCartItem(product: product, quantity: 1);
  return KioskOrder(
    id: id,
    orderNumber: id,
    createdAt: createdAt,
    orderType: 'Take Out',
    paymentMethod: paymentMethod,
    paymentStatus: 'paid',
    orderMode: orderMode,
    status: status,
    items: [item],
    total: total,
  );
}

void main() {
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 10, 1);

  test('aggregates only completed orders inside the selected range', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 150,
        ),
        _order(
          id: 'B',
          createdAt: DateTime(2026, 9, 11, 11),
          status: KioskOrderStatus.cancelled,
          total: 250,
        ),
        _order(
          id: 'C',
          createdAt: DateTime(2026, 10, 1, 9),
          status: KioskOrderStatus.completed,
          total: 300,
        ),
      ],
      start: start,
      end: end,
    );

    expect(result.completedOrders, 1);
    expect(result.itemsSold, 1);
    expect(result.salesTotal, 150);
    expect(result.averageOrderValue, 150);
  });

  test('aggregates payment, order mode and hourly sales', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 150,
          paymentMethod: 'Cash',
          orderMode: 'Customer',
        ),
        _order(
          id: 'B',
          createdAt: DateTime(2026, 9, 10, 10, 30),
          status: KioskOrderStatus.completed,
          total: 250,
          paymentMethod: 'GCash',
          orderMode: 'Employee',
        ),
      ],
      start: start,
      end: end,
    );

    expect(result.paymentSales['Cash'], 150);
    expect(result.paymentSales['GCash'], 250);
    expect(result.orderModeSales['Customer'], 150);
    expect(result.orderModeSales['Employee'], 250);
    expect(result.hourlySales[10], 400);
  });

  test('uses transaction snapshots for category and product labels', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 125,
          productPrice: 125,
        ),
      ],
      start: start,
      end: end,
    );

    expect(result.categorySales['Drinks'], 125);
    expect(result.productSales['Coffee'], 125);
  });

  test('does not mutate source orders while calculating', () {
    final source = _order(
      id: 'A',
      createdAt: DateTime(2026, 9, 10, 10),
      status: KioskOrderStatus.completed,
      total: 125,
    );
    final before = source.toJson();
    SalesReportingDashboardCalculator.calculate(
      orders: [source],
      start: start,
      end: end,
    );
    expect(source.toJson(), before);
  });

  test('builds daily sales buckets for the selected period', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 100,
        ),
        _order(
          id: 'B',
          createdAt: DateTime(2026, 9, 10, 15),
          status: KioskOrderStatus.completed,
          total: 50,
        ),
        _order(
          id: 'C',
          createdAt: DateTime(2026, 9, 11, 9),
          status: KioskOrderStatus.completed,
          total: 75,
        ),
      ],
      start: start,
      end: end,
    );

    expect(result.dailySales[DateTime(2026, 9, 10)], 150);
    expect(result.dailySales[DateTime(2026, 9, 11)], 75);
  });

  test('compares the selected period with the immediately preceding period', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'P',
          createdAt: DateTime(2026, 8, 25, 10),
          status: KioskOrderStatus.completed,
          total: 80,
        ),
        _order(
          id: 'C',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 120,
        ),
      ],
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result.previousPeriodSales, 80);
    expect(result.salesChange, 40);
    expect(result.salesChangePercent, 50);
  });

  test('reports zero comparison percentage when the previous period is empty', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'C',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 120,
        ),
      ],
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result.previousPeriodSales, 0);
    expect(result.salesChange, 120);
    expect(result.salesChangePercent, 0);
  });

  test('builds weekly sales buckets using Monday as the week start', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 7, 10),
          status: KioskOrderStatus.completed,
          total: 100,
        ),
        _order(
          id: 'B',
          createdAt: DateTime(2026, 9, 13, 10),
          status: KioskOrderStatus.completed,
          total: 50,
        ),
      ],
      start: start,
      end: end,
    );

    expect(result.weeklySales[DateTime(2026, 9, 7)], 150);
  });

  test('provides a stable monthly total map from daily sales', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'A',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 100,
        ),
        _order(
          id: 'B',
          createdAt: DateTime(2026, 9, 25, 10),
          status: KioskOrderStatus.completed,
          total: 50,
        ),
      ],
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result.monthlySales['2026-09'], 150);
  });

  test('comparison ignores cancelled orders', () {
    final result = SalesReportingDashboardCalculator.calculate(
      orders: [
        _order(
          id: 'P',
          createdAt: DateTime(2026, 8, 25, 10),
          status: KioskOrderStatus.cancelled,
          total: 500,
        ),
        _order(
          id: 'C',
          createdAt: DateTime(2026, 9, 10, 10),
          status: KioskOrderStatus.completed,
          total: 120,
        ),
      ],
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    );

    expect(result.previousPeriodSales, 0);
    expect(result.salesChange, 120);
  });
}
