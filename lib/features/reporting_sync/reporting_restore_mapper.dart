import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/models/kiosk_models.dart';

/// Converts the database restore payload into a local [KioskOrder].
///
/// The current restore RPC returns the same camelCase shape used by
/// [KioskOrder.toJson]. Legacy snake_case payloads are also accepted.
class ReportingRestoreMapper {
  static KioskOrder fromDatabasePayload(Map<String, dynamic> json) {
    dynamic read(Map<String, dynamic> map, String camel, String snake) =>
        map[camel] ?? map[snake];

    String textValue(
      dynamic value, {
      required String fallback,
    }) {
      final valueText = value?.toString().trim();
      return valueText == null || valueText.isEmpty ? fallback : valueText;
    }

    int intValue(dynamic value, {int fallback = 0}) {
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    DateTime dateValue(dynamic value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    final externalId = textValue(
      read(json, 'id', 'external_transaction_id'),
      fallback: 'RESTORED-${DateTime.now().microsecondsSinceEpoch}',
    );

    final rawItems = json['items'] is List ? json['items'] as List : const [];
    final restoredItems = <KioskCartItem>[];

    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);

      final productId = textValue(
        read(item, 'productId', 'product_id'),
        fallback: 'RESTORED-$externalId-ITEM-$index',
      );
      final productName = textValue(
        read(item, 'productName', 'product_name'),
        fallback: productId,
      );
      final productType = textValue(
        read(item, 'productType', 'product_type'),
        fallback: 'drink',
      );
      final groupId = read(item, 'groupId', 'group_id')?.toString().trim();
      final groupName = read(item, 'groupName', 'group_name')?.toString().trim();

      KioskSize? size;
      final rawSize = item['size'];
      final sizeMap = rawSize is Map
          ? Map<String, dynamic>.from(rawSize)
          : null;
      final sizeIdRaw = (sizeMap != null
              ? read(sizeMap, 'id', 'size_id')
              : read(item, 'sizeId', 'size_id'))
          ?.toString()
          .trim();
      final sizeNameRaw = (sizeMap != null
              ? read(sizeMap, 'name', 'size_name')
              : read(item, 'sizeName', 'size_name'))
          ?.toString()
          .trim();
      if ((sizeIdRaw?.isNotEmpty ?? false) ||
          (sizeNameRaw?.isNotEmpty ?? false)) {
        final sizeId = sizeIdRaw?.isNotEmpty == true
            ? sizeIdRaw!
            : 'RESTORED-$externalId-SIZE-$index';
        final sizeName = sizeNameRaw?.isNotEmpty == true
            ? sizeNameRaw!
            : sizeId;
        final rawVolume = sizeMap != null
            ? read(sizeMap, 'volumeMl', 'size_volume_ml')
            : read(item, 'sizeVolumeMl', 'size_volume_ml');
        final volume = rawVolume == null ? null : intValue(rawVolume);
        size = KioskSize(
          id: sizeId,
          name: sizeName,
          volumeMl: volume,
          displayVolume: sizeMap == null
              ? (volume == null ? null : '${volume}ml')
              : read(sizeMap, 'displayVolume', 'display_volume')?.toString(),
          price: null,
        );
      }

      KioskVariant? variant;
      final rawVariant = item['variant'];
      final variantMap = rawVariant is Map
          ? Map<String, dynamic>.from(rawVariant)
          : null;
      final variantIdRaw = (variantMap != null
              ? read(variantMap, 'id', 'variant_id')
              : read(item, 'variantId', 'variant_id'))
          ?.toString()
          .trim();
      final variantNameRaw = (variantMap != null
              ? read(variantMap, 'name', 'variant_name')
              : read(item, 'variantName', 'variant_name'))
          ?.toString()
          .trim();
      if ((variantIdRaw?.isNotEmpty ?? false) ||
          (variantNameRaw?.isNotEmpty ?? false)) {
        final variantId = variantIdRaw?.isNotEmpty == true
            ? variantIdRaw!
            : 'RESTORED-$externalId-VARIANT-$index';
        final variantName = variantNameRaw?.isNotEmpty == true
            ? variantNameRaw!
            : variantId;
        variant = KioskVariant(
          id: variantId,
          name: variantName,
          price: null,
        );
      }

      final rawOptions = item['options'] is List
          ? item['options'] as List
          : const [];
      final options = <KioskOption>[];
      for (var optionIndex = 0;
          optionIndex < rawOptions.length;
          optionIndex++) {
        final rawOption = rawOptions[optionIndex];
        if (rawOption is! Map) continue;
        final option = Map<String, dynamic>.from(rawOption);
        final optionName = textValue(
          read(option, 'name', 'option_name'),
          fallback: 'Option ${optionIndex + 1}',
        );
        options.add(
          KioskOption(
            id: textValue(
              read(option, 'id', 'option_id'),
              fallback: 'RESTORED-$externalId-OPTION-$index-$optionIndex',
            ),
            name: optionName,
            price: intValue(read(option, 'price', 'price')),
            kitchenPrepared: read(option, 'kitchenPrepared', 'kitchen_prepared') as bool? ?? false,
          ),
        );
      }

      // The reporting database stores the final item unit_price, while the
      // kiosk model derives unitPrice from size/variant + options. Assign the
      // remaining base price to the selected size (or variant) so restoration
      // preserves the original transaction total.
      final storedUnitPrice = intValue(read(item, 'unitPrice', 'unit_price'));
      final optionTotal = options.fold<int>(
        0,
        (sum, option) => sum + option.price,
      );
      final basePrice = storedUnitPrice - optionTotal;

      if (size != null) {
        size = KioskSize(
          id: size.id,
          name: size.name,
          volumeMl: size.volumeMl,
          displayVolume: size.displayVolume,
          price: basePrice,
        );
      } else if (variant != null) {
        variant = KioskVariant(
          id: variant.id,
          name: variant.name,
          price: basePrice,
        );
      }

      final category = KioskCategory.fromId(
            read(item, 'category', 'category')?.toString() ?? '',
          ) ??
          KioskCategory.accessories;

      final temperature = read(item, 'drinkTemperature', 'drink_temperature')?.toString().trim();
      final normalizedTemperature =
          temperature == 'hot' || temperature == 'iced'
              ? temperature
              : null;

      final product = KioskProduct(
        id: productId,
        name: productName,
        price: size == null && variant == null ? storedUnitPrice : null,
        category: category,
        groupId: groupId?.isEmpty == true ? null : groupId,
        groupName: groupName?.isEmpty == true ? null : groupName,
        productType: productType,
        drinkTemperature: normalizedTemperature,
        kitchenPrepared: read(item, 'kitchenPrepared', 'kitchen_prepared') as bool? ?? false,
        sizes: size == null ? const [] : [size],
        variants: variant == null ? const [] : [variant],
      );

      restoredItems.add(
        KioskCartItem(
          product: product,
          size: size,
          variant: variant,
          quantity: intValue(read(item, 'quantity', 'quantity'), fallback: 1),
          options: List.unmodifiable(options),
          drinkTemperature: normalizedTemperature,
        ),
      );
    }

    return KioskOrder(
      id: externalId,
      orderNumber: textValue(
        read(json, 'orderNumber', 'order_number'),
        fallback: externalId,
      ),
      createdAt: dateValue(read(json, 'transactionDate', 'transaction_date') ?? read(json, 'createdAt', 'created_at')),
      orderType: textValue(
        read(json, 'orderType', 'order_type'),
        fallback: 'Take Out',
      ),
      paymentMethod: textValue(
        read(json, 'paymentMethod', 'payment_method'),
        fallback: 'Pay at Counter',
      ),
      paymentStatus: textValue(
        read(json, 'paymentStatus', 'payment_status'),
        fallback: 'pending',
      ),
      orderMode: textValue(
        read(json, 'orderMode', 'order_mode'),
        fallback: 'Customer',
      ),
      status: KioskOrderStatusX.fromValue(
        textValue(read(json, 'status', 'status'), fallback: 'pending'),
      ),
      cancellationReason: read(json, 'cancellationReason', 'cancellation_reason')?.toString(),
      modificationReason: read(json, 'modificationReason', 'modification_reason')?.toString(),
      modifiedAt: read(json, 'modifiedAt', 'modified_at') == null
          ? null
          : DateTime.tryParse(read(json, 'modifiedAt', 'modified_at').toString()),
      items: List.unmodifiable(restoredItems),
      total: intValue(read(json, 'total', 'total')),
    );
  }
}
