import '../models/kiosk_models.dart';
import '../orders/kiosk_order.dart';

/// Production-copy routing rules.
///
/// An order item belongs on the kitchen copy when the product itself is
/// kitchen-prepared or when at least one selected option is explicitly
/// marked as kitchen-prepared. Whether an option is automatic is unrelated
/// to kitchen routing.
class KioskProductionCopyRules {
  const KioskProductionCopyRules._();

  static bool isKitchenItem(KioskCartItem item) {
    return item.product.kitchenPrepared ||
        item.options.any((option) => option.kitchenPrepared);
  }

  static List<KioskCartItem> kitchenItems(KioskOrder order) {
    return order.items.where(isKitchenItem).toList(growable: false);
  }
}
