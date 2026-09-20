import '../kiosk/orders/kiosk_order.dart';
import 'reporting_sync_models.dart';

/// Converts an existing [KioskOrder] into the exact payload required by the
/// Supabase reporting RPC. This class is read-only and never writes to the
/// kiosk repository or SharedPreferences.
class ReportingTransactionMapper {
  const ReportingTransactionMapper();

  ReportingSyncPayload mapOrder({
    required KioskOrder order,
    required String storeId,
    required String deviceId,
  }) {
    final items = order.items.map((item) {
      return <String, dynamic>{
        'product_id': item.product.id,
        'product_name': item.product.name,
        'product_type': item.product.productType,
        'group_id': item.product.groupId,
        'group_name': item.product.groupName,
        'category': item.product.category.id,
        'size_id': item.size?.id,
        'size_name': item.size?.name,
        'size_volume_ml': item.size?.volumeMl,
        'variant_id': item.variant?.id,
        'variant_name': item.variant?.name,
        'drink_temperature': item.drinkTemperature,
        'kitchen_prepared': item.product.kitchenPrepared,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total': item.total,
        'options': item.options
            .map(
              (option) => <String, dynamic>{
                'option_id': option.id,
                'option_name': option.name,
                'price': option.price,
                'kitchen_prepared': option.kitchenPrepared,
                'automatic': option.automatic,
              },
            )
            .toList(growable: false),
      };
    }).toList(growable: false);

    return ReportingSyncPayload(
      externalTransactionId: order.id,
      storeId: storeId,
      deviceId: deviceId,
      orderNumber: order.orderNumber,
      transactionDate: order.createdAt,
      orderType: order.orderType,
      orderMode: order.orderMode,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      status: order.status.value,
      cancellationReason: order.cancellationReason,
      modificationReason: order.modificationReason,
      modifiedAt: order.modifiedAt,
      // The current kiosk order model stores a final order total only.
      // Keep the mapper faithful to local data: no discount is inferred.
      subtotal: order.total,
      discount: 0,
      total: order.total,
      items: items,
    );
  }
}
