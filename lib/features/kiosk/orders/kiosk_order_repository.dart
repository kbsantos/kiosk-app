import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kiosk_models.dart';
import '../../../product_catalog/product_catalog_repository.dart';
import 'kiosk_order.dart';

class HistoricalDrinkTemperatureSyncResult {
  final int updatedOrders;
  final int updatedItems;
  final int totalOrders;

  const HistoricalDrinkTemperatureSyncResult({
    this.updatedOrders = 0,
    this.updatedItems = 0,
    this.totalOrders = 0,
  });
}

class KioskOrderRepository {
  static const _ordersKey = 'bigger_brew_kiosk.orders.v1';
  static const _sequenceDateKey = 'bigger_brew_kiosk.sequence_date.v1';
  static const _sequenceKey = 'bigger_brew_kiosk.sequence.v1';

  /// Synchronizes historical drink transaction snapshots with the current
  /// catalog's `drinkTemperature`.
  ///
  /// The sync is intentionally based on the current catalog value, not only
  /// on missing transaction values. This allows a transaction that was
  /// created while a product defaulted to Iced to be updated when the
  /// product is later changed to Hot (or vice versa).
  ///
  /// Only `drinkTemperature` is changed. Prices, names, sizes, variants,
  /// options, quantities, totals and other historical transaction details
  /// remain untouched.
  Future<HistoricalDrinkTemperatureSyncResult>
      syncHistoricalDrinkTemperatures({bool dryRun = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawOrders = prefs.getStringList(_ordersKey) ?? const [];
    if (rawOrders.isEmpty) {
      return const HistoricalDrinkTemperatureSyncResult();
    }

    final catalog = await const ProductCatalogRepository().load();
    final temperatureByProductId = <String, String>{};
    for (final product in catalog.products) {
      if (product.productType.trim().toLowerCase() != 'drink') continue;

      final temperature = product.drinkTemperature?.trim().toLowerCase();
      final normalizedTemperature =
          temperature == 'hot' || temperature == 'iced'
              ? temperature!
              : 'iced';
      temperatureByProductId[product.productId] = normalizedTemperature;
    }

    var updatedItems = 0;
    var updatedOrders = 0;
    final nextRawOrders = <String>[];

    for (final rawOrder in rawOrders) {
      Map<String, dynamic> orderJson;
      try {
        orderJson = Map<String, dynamic>.from(
          jsonDecode(rawOrder) as Map,
        );
      } catch (_) {
        // Preserve malformed records exactly as they were.
        nextRawOrders.add(rawOrder);
        continue;
      }

      final rawItems = orderJson['items'];
      var orderChanged = false;

      if (rawItems is List) {
        final nextItems = <dynamic>[];

        for (final rawItem in rawItems) {
          if (rawItem is! Map) {
            nextItems.add(rawItem);
            continue;
          }

          final item = Map<String, dynamic>.from(rawItem);
          final productType =
              (item['productType'] as String? ?? '').trim().toLowerCase();

          if (productType == 'drink') {
            final productId = item['productId'] as String? ?? '';
            final currentCatalogTemperature =
                temperatureByProductId[productId];
            final storedTemperature =
                (item['drinkTemperature'] as String?)?.trim().toLowerCase();

            // When the product still exists in the catalog, synchronize to
            // its current temperature even when the transaction already has
            // a value. This is what lets old default-Iced transactions follow
            // a later catalog change to Hot.
            if (currentCatalogTemperature != null) {
              if (storedTemperature != currentCatalogTemperature) {
                item['drinkTemperature'] = currentCatalogTemperature;
                updatedItems++;
                orderChanged = true;
              }
            } else if (storedTemperature != 'hot' &&
                storedTemperature != 'iced') {
              // Product no longer exists in the catalog: retain the legacy
              // compatibility fallback for records that never had a value.
              item['drinkTemperature'] = 'iced';
              updatedItems++;
              orderChanged = true;
            }
          }

          nextItems.add(item);
        }

        if (orderChanged) {
          orderJson['items'] = nextItems;
          updatedOrders++;
        }
      }

      nextRawOrders.add(jsonEncode(orderJson));
    }

    if (!dryRun && updatedItems > 0) {
      await prefs.setStringList(_ordersKey, nextRawOrders);
    }

    return HistoricalDrinkTemperatureSyncResult(
      updatedOrders: updatedOrders,
      updatedItems: updatedItems,
      totalOrders: rawOrders.length,
    );
  }

  Future<List<KioskOrder>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_ordersKey) ?? const [];

    final orders = <KioskOrder>[];
    for (final value in raw) {
      try {
        orders.add(
          KioskOrder.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        // Ignore malformed historical records rather than breaking the kiosk.
      }
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(orders);
  }

  Future<KioskOrder> createOrder({
    required KioskCart cart,
    required String orderType,
    String paymentMethod = 'Pay at Counter',
    String paymentStatus = 'pending',
    String orderMode = 'Customer',
    KioskOrderStatus status = KioskOrderStatus.pending,
  }) async {
    if (cart.items.isEmpty) {
      throw StateError('Cannot create an order from an empty cart.');
    }

    final now = DateTime.now();
    final orderNumber = await _nextOrderNumber(now);

    final order = KioskOrder(
      id: '${now.microsecondsSinceEpoch}-$orderNumber',
      orderNumber: orderNumber,
      createdAt: now,
      orderType: orderType,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      orderMode: orderMode,
      status: status,
      items: List.unmodifiable(cart.items),
      total: cart.total,
    );

    await _append(order);
    return order;
  }

  Future<void> modifyTransaction(
    String orderId, {
    required List<KioskCartItem> items,
    required String reason,
    String? orderType,
    String? paymentMethod,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('A modification reason is required.');
    }
    if (items.isEmpty) {
      throw StateError('A transaction must contain at least one item.');
    }

    final orders = await getOrders();
    final target = orders.where((order) => order.id == orderId);
    if (target.isEmpty) {
      throw StateError('Order not found: $orderId');
    }

    final order = target.first;
    if (order.status == KioskOrderStatus.cancelled ||
        order.paymentStatus == 'refunded') {
      throw StateError('Cancelled or refunded transactions cannot be modified.');
    }

    final now = DateTime.now();
    final updated = orders
        .map(
          (current) => current.id == orderId
              ? current.copyWith(
                  orderType: orderType,
                  paymentMethod: paymentMethod,
                  items: List.unmodifiable(items),
                  total: items.fold<int>(
                    0,
                    (sum, item) => sum + item.total,
                  ),
                  modificationReason: trimmedReason,
                  modifiedAt: now,
                )
              : current,
        )
        .toList(growable: false);

    await _save(updated);
  }

  Future<void> updateStatus(
    String orderId,
    KioskOrderStatus status,
  ) async {
    final orders = await getOrders();
    final updated = orders
        .map(
          (order) => order.id == orderId
              ? order.copyWith(status: status)
              : order,
        )
        .toList(growable: false);

    await _save(updated);
  }


  Future<void> updatePaymentStatus(
    String orderId,
    String paymentStatus,
  ) async {
    final orders = await getOrders();
    final updated = orders
        .map(
          (order) => order.id == orderId
              ? order.copyWith(paymentStatus: paymentStatus)
              : order,
        )
        .toList(growable: false);

    await _save(updated);
  }

  Future<void> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    final orders = await getOrders();
    final updated = orders
        .map(
          (order) => order.id == orderId
              ? order.copyWith(
                  status: KioskOrderStatus.cancelled,
                  cancellationReason: reason,
                )
              : order,
        )
        .toList(growable: false);

    await _save(updated);
  }

  Future<void> cancelAndRefundEmployeeOrder(
    String orderId, {
    String? reason,
  }) async {
    final orders = await getOrders();
    final target = orders.where((order) => order.id == orderId);
    if (target.isEmpty) {
      throw StateError('Order not found: $orderId');
    }

    final order = target.first;
    if (order.orderMode.toLowerCase() != 'employee') {
      throw StateError('Only employee orders can be cancelled from EOD.');
    }
    if (order.status != KioskOrderStatus.completed) {
      throw StateError('Only completed employee orders can be cancelled.');
    }
    if (order.paymentStatus != 'paid') {
      throw StateError('Only paid employee orders can be cancelled.');
    }

    final updated = orders
        .map(
          (current) => current.id == orderId
              ? current.copyWith(
                  status: KioskOrderStatus.cancelled,
                  paymentStatus: 'refunded',
                  cancellationReason: reason,
                )
              : current,
        )
        .toList(growable: false);

    await _save(updated);
  }

  Future<void> refundPayment(String orderId) async {
    final orders = await getOrders();
    final target = orders.where((order) => order.id == orderId);
    if (target.isEmpty) {
      throw StateError('Order not found: $orderId');
    }

    final order = target.first;
    if (order.status != KioskOrderStatus.cancelled) {
      throw StateError('Only cancelled orders can be refunded.');
    }
    if (order.paymentStatus != 'paid') {
      throw StateError('Only paid orders can be refunded.');
    }

    final updated = orders
        .map(
          (order) => order.id == orderId
              ? order.copyWith(paymentStatus: 'refunded')
              : order,
        )
        .toList(growable: false);

    await _save(updated);
  }

  Future<List<KioskOrder>> getCancelledOrders() async {
    final orders = await getOrders();
    return orders
        .where((order) => order.status == KioskOrderStatus.cancelled)
        .toList(growable: false);
  }

  Future<List<KioskOrder>> getCompletedOrders() async {
    final orders = await getOrders();
    return orders
        .where((order) => order.status == KioskOrderStatus.completed)
        .toList(growable: false);
  }

  Future<List<KioskOrder>> getOrdersForDate(DateTime date) async {
    final orders = await getOrders();

    return orders
        .where(
          (order) =>
              order.createdAt.year == date.year &&
              order.createdAt.month == date.month &&
              order.createdAt.day == date.day,
        )
        .toList(growable: false);
  }

  Future<List<KioskOrder>> getActiveOrders() async {
    final orders = await getOrders();
    return orders
        .where(
          (order) =>
              order.status != KioskOrderStatus.completed &&
              order.status != KioskOrderStatus.cancelled,
        )
        .toList(growable: false);
  }

  Future<void> _append(KioskOrder order) async {
    final orders = await getOrders();
    await _save([order, ...orders]);
  }

  Future<void> _save(List<KioskOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _ordersKey,
      orders.map((order) => jsonEncode(order.toJson())).toList(),
    );
  }

  Future<String> _nextOrderNumber(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _dateKey(now);
    final savedDate = prefs.getString(_sequenceDateKey);

    var sequence = prefs.getInt(_sequenceKey) ?? 0;
    if (savedDate != date) {
      sequence = 0;
      await prefs.setString(_sequenceDateKey, date);
    }

    sequence += 1;
    await prefs.setInt(_sequenceKey, sequence);

    return 'BB-${sequence.toString().padLeft(3, '0')}';
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
