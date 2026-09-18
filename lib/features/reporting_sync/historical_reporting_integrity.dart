import '../kiosk/orders/kiosk_order.dart';

class HistoricalReportingIssue {
  const HistoricalReportingIssue({
    required this.orderId,
    required this.code,
    required this.message,
  });

  final String orderId;
  final String code;
  final String message;
}

class HistoricalReportingResult {
  const HistoricalReportingResult({
    required this.completedOrders,
    required this.itemsSold,
    required this.salesTotal,
    required this.categorySales,
    required this.productSales,
    required this.variantSales,
    required this.optionSales,
    required this.legacyCatalogVersionOrders,
    required this.issues,
  });

  final int completedOrders;
  final int itemsSold;
  final int salesTotal;
  final Map<String, int> categorySales;
  final Map<String, int> productSales;
  final Map<String, int> variantSales;
  final Map<String, int> optionSales;
  final int legacyCatalogVersionOrders;
  final List<HistoricalReportingIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Validates and aggregates the local transaction snapshot using the same
/// completed-order semantics as the kiosk EOD sales report.
///
/// This class is intentionally read-only. It never repairs, reclassifies, or
/// rewrites historical transactions.
class HistoricalReportingIntegrity {
  const HistoricalReportingIntegrity._();

  static HistoricalReportingResult analyze(List<KioskOrder> orders) {
    var completedOrders = 0;
    var itemsSold = 0;
    var salesTotal = 0;
    var legacyCatalogVersionOrders = 0;
    final categorySales = <String, int>{};
    final productSales = <String, int>{};
    final variantSales = <String, int>{};
    final optionSales = <String, int>{};
    final issues = <HistoricalReportingIssue>[];

    for (final order in orders) {
      if (order.catalogVersion == null || order.catalogVersion!.trim().isEmpty) {
        legacyCatalogVersionOrders++;
      }

      final itemTotal = order.items.fold<int>(
        0,
        (sum, item) => sum + item.total,
      );
      if (itemTotal != order.total) {
        issues.add(
          HistoricalReportingIssue(
            orderId: order.id,
            code: 'order_total_mismatch',
            message:
                'Order total ${order.total} does not match item total $itemTotal.',
          ),
        );
      }

      if (order.status != KioskOrderStatus.completed) continue;

      completedOrders++;
      itemsSold += order.items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      salesTotal += order.total;

      for (final item in order.items) {
        _add(categorySales, item.product.category.id, item.total);
        _add(productSales, item.product.id, item.total);

        final variantId = item.variant?.id.trim() ?? '';
        if (variantId.isNotEmpty) {
          _add(variantSales, variantId, item.total);
        }

        for (final option in item.options) {
          final optionId = option.id.trim();
          if (optionId.isNotEmpty) {
            // Options are intentionally keyed by their own transaction
            // snapshot ID. Their amount is included once per cart item,
            // matching the persisted option price carried by that item.
            _add(optionSales, optionId, option.price * item.quantity);
          }
        }
      }
    }

    return HistoricalReportingResult(
      completedOrders: completedOrders,
      itemsSold: itemsSold,
      salesTotal: salesTotal,
      categorySales: Map.unmodifiable(categorySales),
      productSales: Map.unmodifiable(productSales),
      variantSales: Map.unmodifiable(variantSales),
      optionSales: Map.unmodifiable(optionSales),
      legacyCatalogVersionOrders: legacyCatalogVersionOrders,
      issues: List.unmodifiable(issues),
    );
  }

  static void _add(Map<String, int> target, String key, int amount) {
    final normalized = key.trim();
    if (normalized.isEmpty) return;
    target[normalized] = (target[normalized] ?? 0) + amount;
  }
}
