/// Read-only payload models used to prepare MyKiosk kiosk orders for
/// the Supabase `sync_kiosk_transaction` RPC. No local kiosk data is changed.
class ReportingSyncPayload {
  final String externalTransactionId;
  final String storeId;
  final String deviceId;
  final String orderNumber;
  final DateTime transactionDate;
  final String orderType;
  final String orderMode;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final String? cancellationReason;
  final String? modificationReason;
  final DateTime? modifiedAt;
  final num subtotal;
  final num discount;
  final num total;
  final List<Map<String, dynamic>> items;

  const ReportingSyncPayload({
    required this.externalTransactionId,
    required this.storeId,
    required this.deviceId,
    required this.orderNumber,
    required this.transactionDate,
    required this.orderType,
    required this.orderMode,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.cancellationReason,
    required this.modificationReason,
    required this.modifiedAt,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.items,
  });

  /// Exact argument names expected by `public.sync_kiosk_transaction`.
  Map<String, dynamic> toRpcParams() => {
        'p_external_transaction_id': externalTransactionId,
        'p_store_id': storeId,
        'p_device_id': deviceId,
        'p_order_number': orderNumber,
        'p_transaction_date': transactionDate.toUtc().toIso8601String(),
        'p_order_type': orderType,
        'p_order_mode': orderMode,
        'p_payment_method': paymentMethod,
        'p_payment_status': paymentStatus,
        'p_status': status,
        'p_cancellation_reason': cancellationReason,
        'p_modification_reason': modificationReason,
        'p_modified_at': modifiedAt?.toUtc().toIso8601String(),
        'p_subtotal': subtotal,
        'p_discount': discount,
        'p_total': total,
        'p_items': items,
      };
}
