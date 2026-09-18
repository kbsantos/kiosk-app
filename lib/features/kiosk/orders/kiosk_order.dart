import '../models/kiosk_models.dart';

enum KioskOrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled,
}

extension KioskOrderStatusX on KioskOrderStatus {
  String get value => name;

  static KioskOrderStatus fromValue(String value) {
    return KioskOrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => KioskOrderStatus.pending,
    );
  }
}

class KioskOrder {
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final String orderType;
  final String paymentMethod;
  final String paymentStatus;
  final String orderMode;
  /// Catalog version used when this transaction snapshot was created.
  /// Nullable for legacy orders created before K25.
  final String? catalogVersion;
  final KioskOrderStatus status;
  final String? cancellationReason;
  final String? modificationReason;
  final DateTime? modifiedAt;
  final List<KioskCartItem> items;
  final int total;

  const KioskOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.orderType,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.orderMode = 'Customer',
    this.catalogVersion,
    required this.status,
    this.cancellationReason,
    this.modificationReason,
    this.modifiedAt,
    required this.items,
    required this.total,
  });

  KioskOrder copyWith({
    KioskOrderStatus? status,
    String? orderType,
    String? paymentMethod,
    String? paymentStatus,
    String? cancellationReason,
    String? orderMode,
    String? modificationReason,
    DateTime? modifiedAt,
    List<KioskCartItem>? items,
    int? total,
  }) {
    return KioskOrder(
      id: id,
      orderNumber: orderNumber,
      createdAt: createdAt,
      orderType: orderType ?? this.orderType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderMode: orderMode ?? this.orderMode,
      catalogVersion: catalogVersion,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      modificationReason: modificationReason ?? this.modificationReason,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      items: items ?? this.items,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'createdAt': createdAt.toIso8601String(),
      'orderType': orderType,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderMode': orderMode,
      'catalogVersion': catalogVersion,
      'status': status.value,
      'cancellationReason': cancellationReason,
      'modificationReason': modificationReason,
      'modifiedAt': modifiedAt?.toIso8601String(),
      'total': total,
      'items': items.map((item) {
        return {
          'productId': item.product.id,
          'productName': item.product.name,
          'productType': item.product.productType,
          'drinkTemperature': item.drinkTemperature,
          'groupId': item.product.groupId,
          'groupName': item.product.groupName,
          'kitchenPrepared': item.product.kitchenPrepared,
          'category': item.product.category.id,
          'categoryName': item.product.category.title,
          'size': item.size == null
              ? null
              : {
                  'id': item.size!.id,
                  'name': item.size!.name,
                  'volumeMl': item.size!.volumeMl,
                  'displayVolume': item.size!.displayVolume,
                  'price': item.size!.price,
                },
          'variant': item.variant == null
              ? null
              : {
                  'id': item.variant!.id,
                  'name': item.variant!.name,
                  'price': item.variant!.price,
                },
          'quantity': item.quantity,
          // Persist the pre-option price so reloading an order cannot treat
          // the final unit price as the new base price and add options again.
          'basePrice': item.basePrice,
          'unitPrice': item.unitPrice,
          'total': item.total,
          'options': item.options
              .map(
                (option) => {
                  'id': option.id,
                  'name': option.name,
                  'price': option.price,
                  'kitchenPrepared': option.kitchenPrepared,
                },
              )
              .toList(),
        };
      }).toList(),
    };
  }

  factory KioskOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);

    final items = rawItems.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final sizeRaw = data['size'];

      KioskSize? size;
      if (sizeRaw != null) {
        final s = Map<String, dynamic>.from(sizeRaw as Map);
        size = KioskSize(
          id: s['id'] as String,
          name: s['name'] as String,
          volumeMl: s['volumeMl'] as int?,
          displayVolume: s['displayVolume'] as String?,
          price: s['price'] as int?,
        );
      }

      KioskVariant? variant;
      final variantRaw = data['variant'];
      if (variantRaw != null) {
        final v = Map<String, dynamic>.from(variantRaw as Map);
        variant = KioskVariant(
          id: v['id'] as String,
          name: v['name'] as String,
          price: v['price'] as int?,
        );
      }

      final categoryId = data['category'] as String? ?? '';
      final category = KioskCategory.fromCatalog(
        id: categoryId,
        title: data['categoryName'] as String? ?? categoryId,
      );

      final productType = data['productType'] as String? ?? 'drink';
      final storedTemperature = data['drinkTemperature'] as String?;
      final effectiveTemperature = _legacyDrinkTemperature(
        productType: productType,
        productId: data['productId'] as String,
        productName: data['productName'] as String,
        groupId: data['groupId'] as String?,
        groupName: data['groupName'] as String?,
        storedTemperature: storedTemperature,
      );

      final rawOptions = (data['options'] as List<dynamic>? ?? const []);
      final options = rawOptions.map((rawOption) {
        final option = Map<String, dynamic>.from(rawOption as Map);
        return KioskOption(
          id: option['id'] as String,
          name: option['name'] as String,
          price: option['price'] as int,
          kitchenPrepared: option['kitchenPrepared'] as bool? ?? false,
        );
      }).toList(growable: false);

      final storedUnitPrice = data['unitPrice'] as int?;
      final storedBasePrice = data['basePrice'] as int?;
      final optionTotal = options.fold<int>(
        0,
        (sum, option) => sum + option.price,
      );
      // Legacy snapshots did not persist basePrice. For a product without a
      // size/variant, recover the base price from the final stored unit price
      // before reconstructing the cart item. This prevents option prices from
      // being added repeatedly on each reload.
      final legacyBasePrice = (storedUnitPrice ?? 0) - optionTotal;
      final basePrice = storedBasePrice ??
          (legacyBasePrice < 0 ? 0 : legacyBasePrice);

      if (size != null && size.price == null) {
        size = KioskSize(
          id: size.id,
          name: size.name,
          volumeMl: size.volumeMl,
          displayVolume: size.displayVolume,
          price: basePrice,
        );
      } else if (variant != null && variant.price == null) {
        variant = KioskVariant(
          id: variant.id,
          name: variant.name,
          price: basePrice,
        );
      }

      final product = KioskProduct(
        id: data['productId'] as String,
        name: data['productName'] as String,
        price: size == null && variant == null ? basePrice : null,
        category: category,
        groupId: data['groupId'] as String?,
        groupName: data['groupName'] as String?,
        productType: productType,
        drinkTemperature: effectiveTemperature,
        kitchenPrepared: data['kitchenPrepared'] as bool? ??
            (category == KioskCategory.riceMeals),
        sizes: size == null ? const [] : [size],
        variants: variant == null ? const [] : [variant],
      );

      return KioskCartItem(
        product: product,
        size: size,
        variant: variant,
        quantity: data['quantity'] as int? ?? 1,
        options: options,
        drinkTemperature: effectiveTemperature,
      );
    }).toList(growable: false);

    return KioskOrder(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      orderType: json['orderType'] as String? ?? 'Take Out',
      paymentMethod: json['paymentMethod'] as String? ?? 'Pay at Counter',
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      orderMode: json['orderMode'] as String? ?? 'Customer',
      catalogVersion: json['catalogVersion'] as String?,
      status: KioskOrderStatusX.fromValue(
        json['status'] as String? ?? 'pending',
      ),
      cancellationReason: json['cancellationReason'] as String?,
      modificationReason: json['modificationReason'] as String?,
      modifiedAt: json['modifiedAt'] == null
          ? null
          : DateTime.tryParse(json['modifiedAt'] as String),
      items: List.unmodifiable(items),
      total: json['total'] as int? ?? 0,
    );
  }

  static String? _legacyDrinkTemperature({
    required String productType,
    required String productId,
    required String productName,
    required String? groupId,
    required String? groupName,
    required String? storedTemperature,
  }) {
    final existing = storedTemperature?.trim().toLowerCase();
    if (existing == 'hot' || existing == 'iced') return existing;

    if (productType.trim().toLowerCase() != 'drink') return null;

    // Legacy orders did not store drinkTemperature. Preserve the existing
    // reporting rule for known hot-coffee items; all other legacy drinks
    // follow the new default of Iced. This makes historical transactions
    // behave consistently with new transactions without changing any
    // explicitly stored Hot/Iced values.
    final id = productId.trim().toLowerCase();
    final name = productName.trim().toLowerCase();
    final group = groupName?.trim().toLowerCase();
    final groupKey = groupId?.trim().toLowerCase();

    final isHotCoffee = name == 'hot coffee' ||
        group == 'hot coffee' ||
        groupKey == 'hot_coffee' ||
        id.startsWith('hot_');

    return isHotCoffee ? 'hot' : 'iced';
  }
}
