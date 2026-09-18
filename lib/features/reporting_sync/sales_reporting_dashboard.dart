import '../kiosk/orders/kiosk_order.dart';

class SalesReportingDashboard {
  const SalesReportingDashboard({
    required this.start,
    required this.end,
    required this.completedOrders,
    required this.itemsSold,
    required this.salesTotal,
    required this.averageOrderValue,
    required this.categorySales,
    required this.productSales,
    required this.variantSales,
    required this.optionSales,
    required this.paymentSales,
    required this.hourlySales,
    required this.orderModeSales,
    required this.dailySales,
    required this.monthlySales,
    required this.weeklySales,
    required this.previousPeriodSales,
    required this.salesChange,
    required this.salesChangePercent,
  });

  final DateTime start;
  final DateTime end;
  final int completedOrders;
  final int itemsSold;
  final int salesTotal;
  final double averageOrderValue;
  final Map<String, int> categorySales;
  final Map<String, int> productSales;
  final Map<String, int> variantSales;
  final Map<String, int> optionSales;
  final Map<String, int> paymentSales;
  final Map<int, int> hourlySales;
  final Map<String, int> orderModeSales;
  final Map<DateTime, int> dailySales;
  final Map<String, int> monthlySales;
  final Map<DateTime, int> weeklySales;
  final int previousPeriodSales;
  final int salesChange;
  final double salesChangePercent;

  bool get hasSales => completedOrders > 0;
}

/// Read-only local sales aggregation for the kiosk reporting dashboard.
///
/// This intentionally aggregates the persisted transaction snapshot instead
/// of querying Supabase. Cross-store and cross-device reporting belongs to the
/// reporting database; this dashboard describes the local kiosk data only.
class SalesReportingDashboardCalculator {
  const SalesReportingDashboardCalculator._();

  static SalesReportingDashboard calculate({
    required List<KioskOrder> orders,
    required DateTime start,
    required DateTime end,
  }) {
    var completedOrders = 0;
    var itemsSold = 0;
    var salesTotal = 0;
    final categorySales = <String, int>{};
    final productSales = <String, int>{};
    final variantSales = <String, int>{};
    final optionSales = <String, int>{};
    final paymentSales = <String, int>{};
    final hourlySales = <int, int>{};
    final orderModeSales = <String, int>{};
    final dailySales = <DateTime, int>{};
    final monthlySales = <String, int>{};
    final weeklySales = <DateTime, int>{};
    var previousPeriodSales = 0;

    for (final order in orders) {
      if (order.createdAt.isBefore(start) || !order.createdAt.isBefore(end)) {
        continue;
      }
      if (order.status != KioskOrderStatus.completed) continue;

      completedOrders++;
      itemsSold += order.items.fold(0, (sum, item) => sum + item.quantity);
      salesTotal += order.total;
      final day = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
      dailySales[day] = (dailySales[day] ?? 0) + order.total;
      final monthKey = '${order.createdAt.year.toString().padLeft(4, '0')}-${order.createdAt.month.toString().padLeft(2, '0')}';
      monthlySales[monthKey] = (monthlySales[monthKey] ?? 0) + order.total;
      final daysFromMonday = day.weekday - DateTime.monday;
      final weekStart = day.subtract(Duration(days: daysFromMonday));
      weeklySales[weekStart] = (weeklySales[weekStart] ?? 0) + order.total;
      _add(paymentSales, order.paymentMethod, order.total);
      _add(orderModeSales, order.orderMode, order.total);
      hourlySales[order.createdAt.hour] =
          (hourlySales[order.createdAt.hour] ?? 0) + order.total;

      for (final item in order.items) {
        _add(categorySales, item.product.category.title, item.total);
        _add(productSales, item.product.name, item.total);

        final variantName = item.variant?.name.trim() ?? '';
        if (variantName.isNotEmpty) {
          _add(variantSales, variantName, item.total);
        }

        for (final option in item.options) {
          final optionName = option.name.trim();
          if (optionName.isNotEmpty) {
            _add(optionSales, optionName, option.price * item.quantity);
          }
        }
      }
    }

    final periodLength = end.difference(start);
    if (periodLength > Duration.zero) {
      final previousStart = start.subtract(periodLength);
      for (final order in orders) {
        if (order.createdAt.isBefore(previousStart) ||
            !order.createdAt.isBefore(start)) {
          continue;
        }
        if (order.status != KioskOrderStatus.completed) continue;
        previousPeriodSales += order.total;
      }
    }
    final salesChange = salesTotal - previousPeriodSales;
    final salesChangePercent = previousPeriodSales == 0
        ? 0.0
        : (salesChange / previousPeriodSales) * 100;

    return SalesReportingDashboard(
      start: start,
      end: end,
      completedOrders: completedOrders,
      itemsSold: itemsSold,
      salesTotal: salesTotal,
      averageOrderValue:
          completedOrders == 0 ? 0 : salesTotal / completedOrders,
      categorySales: Map.unmodifiable(categorySales),
      productSales: Map.unmodifiable(productSales),
      variantSales: Map.unmodifiable(variantSales),
      optionSales: Map.unmodifiable(optionSales),
      paymentSales: Map.unmodifiable(paymentSales),
      hourlySales: Map.unmodifiable(hourlySales),
      orderModeSales: Map.unmodifiable(orderModeSales),
      dailySales: Map.unmodifiable(dailySales),
      monthlySales: Map.unmodifiable(monthlySales),
      weeklySales: Map.unmodifiable(weeklySales),
      previousPeriodSales: previousPeriodSales,
      salesChange: salesChange,
      salesChangePercent: salesChangePercent,
    );
  }

  static void _add(Map<String, int> target, String key, int amount) {
    final normalized = key.trim();
    if (normalized.isEmpty) return;
    target[normalized] = (target[normalized] ?? 0) + amount;
  }
}
