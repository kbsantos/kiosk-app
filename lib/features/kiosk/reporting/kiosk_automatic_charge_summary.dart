import '../orders/kiosk_order.dart';

class KioskAutomaticChargeSummaryLine {
  final String id;
  final String name;
  final int quantity;
  final int amount;

  const KioskAutomaticChargeSummaryLine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
  });
}

/// Reconciles mandatory automatic charges from completed orders.
///
/// Automatic charges are already included in the order/item totals. This
/// summary intentionally reports them separately without adding them again to
/// sales, so EOD reports can show both total sales and the automatic-charge
/// component of those sales without double counting.
class KioskAutomaticChargeSummary {
  final List<KioskAutomaticChargeSummaryLine> lines;
  final int totalQuantity;
  final int totalAmount;

  const KioskAutomaticChargeSummary({
    required this.lines,
    required this.totalQuantity,
    required this.totalAmount,
  });


  static KioskAutomaticChargeSummary fromOrders(
    Iterable<KioskOrder> orders,
  ) {
    final quantities = <String, int>{};
    final amounts = <String, int>{};
    final names = <String, String>{};

    for (final order in orders) {
      if (order.status != KioskOrderStatus.completed) continue;

      for (final item in order.items) {
        for (final option in item.options.where((option) => option.automatic)) {
          quantities[option.id] = (quantities[option.id] ?? 0) + item.quantity;
          amounts[option.id] =
              (amounts[option.id] ?? 0) + option.price * item.quantity;
          names[option.id] = option.name;
        }
      }
    }

    final ids = names.keys.toList()
      ..sort((a, b) {
        final byName = names[a]!.compareTo(names[b]!);
        return byName != 0 ? byName : a.compareTo(b);
      });

    final lines = ids
        .map(
          (id) => KioskAutomaticChargeSummaryLine(
            id: id,
            name: names[id]!,
            quantity: quantities[id] ?? 0,
            amount: amounts[id] ?? 0,
          ),
        )
        .toList(growable: false);

    return KioskAutomaticChargeSummary(
      lines: lines,
      totalQuantity: lines.fold(0, (sum, line) => sum + line.quantity),
      totalAmount: lines.fold(0, (sum, line) => sum + line.amount),
    );
  }
}
