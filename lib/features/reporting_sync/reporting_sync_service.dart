import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/orders/kiosk_order_repository.dart';
import '../kiosk/models/kiosk_models.dart';
import 'reporting_sync_result.dart';
import 'reporting_sync_status.dart';
import 'reporting_sync_status_store.dart';
import 'reporting_transaction_mapper.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';

/// Manual, reporting-only synchronization service.
///
/// Local SharedPreferences remains the kiosk source of truth. This service only
/// reads local [KioskOrder] records and sends their current snapshot to the
/// Supabase `sync_kiosk_transaction` RPC.
class ReportingRestorePreview {
  const ReportingRestorePreview({
    required this.databaseTransactions,
    required this.alreadyLocal,
    required this.missingOrders,
    this.failures = const [],
  });

  final int databaseTransactions;
  final int alreadyLocal;
  final List<KioskOrder> missingOrders;
  final List<ReportingRestoreFailure> failures;

  int get missing => missingOrders.length;
}

class ReportingRestoreResult {
  const ReportingRestoreResult({
    required this.databaseTransactions,
    required this.alreadyLocal,
    required this.restored,
    required this.failed,
    this.failures = const [],
  });

  final int databaseTransactions;
  final int alreadyLocal;
  final int restored;
  final int failed;
  final List<ReportingRestoreFailure> failures;

  bool get isSuccess => failed == 0;

  String get summary =>
      '$restored transaction(s) restored, $alreadyLocal already on the kiosk, '
      '$failed failed.';
}

class ReportingRestoreFailure {
  const ReportingRestoreFailure({
    required this.externalTransactionId,
    required this.message,
  });

  final String externalTransactionId;
  final String message;
}

class ReportingSyncService {
  ReportingSyncService({
    KioskOrderRepository? orderRepository,
    ReportingTransactionMapper? mapper,
    ReportingSyncStatusStore? statusStore,
    KioskSettingsRepository? settingsRepository,
  })  : _orderRepository = orderRepository ?? KioskOrderRepository(),
        _mapper = mapper ?? const ReportingTransactionMapper(),
        _statusStore = statusStore ?? ReportingSyncStatusStore(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository();

  static const _rpcName = 'sync_kiosk_transaction';

  final KioskOrderRepository _orderRepository;
  final ReportingTransactionMapper _mapper;
  final ReportingSyncStatusStore _statusStore;
  final KioskSettingsRepository _settingsRepository;

  /// Syncs orders created on the kiosk's local calendar date.
  Future<ReportingSyncResult> syncToday({
    DateTime? date,
    bool includeAlreadySynced = false,
  }) async {
    final targetDate = date ?? DateTime.now();
    final orders = await _orderRepository.getOrdersForDate(targetDate);
    return _syncPendingOrders(orders, includeAlreadySynced: includeAlreadySynced);
  }

  /// Syncs every locally stored kiosk order.
  ///
  /// Existing cloud records are updated through the RPC's UPSERT behavior, so
  /// repeated manual full syncs do not create duplicate transactions.
  Future<ReportingSyncResult> fullSync({
    bool includeAlreadySynced = false,
  }) async {
    final orders = await _orderRepository.getOrders();
    return _syncPendingOrders(orders, includeAlreadySynced: includeAlreadySynced);
  }

  /// Sends every locally stored transaction to reporting.
  ///
  /// This is intentionally a full, idempotent resync for the EOD workflow.
  /// Already-synced transactions are included so the reporting database is
  /// refreshed from the kiosk's complete local transaction history.
  Future<ReportingSyncResult> syncAllTransactions() async {
    final orders = await _orderRepository.getOrders();
    return _syncOrders(orders);
  }

  /// Reads reporting transactions for this kiosk and identifies only those
  /// whose external transaction ID is missing locally. No local data is
  /// changed.
  Future<ReportingRestorePreview> previewMissingTransactions() async {
    final settings = await _settingsRepository.load();
    _validateConfiguration(settings);

    final result = await Supabase.instance.client.rpc(
      'get_kiosk_transactions_for_restore',
      params: {
        'p_store_id': settings.storeId.trim(),
        'p_device_code': settings.deviceId.trim(),
      },
    );

    if (result == null) {
      throw StateError('The reporting database returned no restore payload.');
    }

    final rawTransactions = result is List ? result : const [];
    final localOrders = await _orderRepository.getOrders();
    final localIds = localOrders.map((order) => order.id).toSet();

    var alreadyLocal = 0;
    final failures = <ReportingRestoreFailure>[];
    final missingOrders = <KioskOrder>[];

    for (final raw in rawTransactions) {
      try {
        if (raw is! Map) {
          throw const FormatException('Invalid transaction payload.');
        }

        final json = Map<String, dynamic>.from(raw);
        final externalId =
            json['external_transaction_id']?.toString().trim() ?? '';
        if (externalId.isEmpty) {
          throw const FormatException(
            'Transaction payload is missing external_transaction_id.',
          );
        }

        if (localIds.contains(externalId)) {
          alreadyLocal++;
          continue;
        }

        final order = _restoreOrderFromDatabase(json);
        missingOrders.add(order);
        localIds.add(externalId);
      } catch (error) {
        final id = raw is Map
            ? (raw['id'] ?? raw['external_transaction_id'] ?? 'unknown')
                .toString()
            : 'unknown';
        failures.add(
          ReportingRestoreFailure(
            externalTransactionId: id,
            message: error.toString(),
          ),
        );
      }
    }

    return ReportingRestorePreview(
      databaseTransactions: rawTransactions.length,
      alreadyLocal: alreadyLocal,
      missingOrders: List.unmodifiable(missingOrders),
      failures: List.unmodifiable(failures),
    );
  }

  /// Restores the missing transactions from a previously generated preview.
  /// Existing local transactions are never overwritten.
  Future<ReportingRestoreResult> restoreMissingTransactions(
    ReportingRestorePreview preview,
  ) async {
    final restored = await _orderRepository.restoreOrders(preview.missingOrders);

    return ReportingRestoreResult(
      databaseTransactions: preview.databaseTransactions,
      alreadyLocal: preview.alreadyLocal,
      restored: restored,
      failed: preview.failures.length,
      failures: preview.failures,
    );
  }

  KioskOrder _restoreOrderFromDatabase(Map<String, dynamic> json) {
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
      json['external_transaction_id'],
      fallback: textValue(
        json['id'],
        fallback: 'RESTORED-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    final rawItems = json['items'] is List ? json['items'] as List : const [];
    final restoredItems = <KioskCartItem>[];

    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);

      final productId = textValue(
        item['product_id'],
        fallback: 'RESTORED-$externalId-ITEM-$index',
      );
      final productName = textValue(
        item['product_name'],
        fallback: productId,
      );
      final productType = textValue(
        item['product_type'],
        fallback: 'drink',
      );
      final groupId = item['group_id']?.toString().trim();
      final groupName = item['group_name']?.toString().trim();

      KioskSize? size;
      final sizeIdRaw = item['size_id']?.toString().trim();
      final sizeNameRaw = item['size_name']?.toString().trim();
      if ((sizeIdRaw?.isNotEmpty ?? false) ||
          (sizeNameRaw?.isNotEmpty ?? false)) {
        final sizeId = sizeIdRaw?.isNotEmpty == true
            ? sizeIdRaw!
            : 'RESTORED-$externalId-SIZE-$index';
        final sizeName = sizeNameRaw?.isNotEmpty == true
            ? sizeNameRaw!
            : sizeId;
        final volume = item['size_volume_ml'] == null
            ? null
            : intValue(item['size_volume_ml']);
        size = KioskSize(
          id: sizeId,
          name: sizeName,
          volumeMl: volume,
          displayVolume: volume == null ? null : '${volume}ml',
          price: null,
        );
      }

      KioskVariant? variant;
      final variantIdRaw = item['variant_id']?.toString().trim();
      final variantNameRaw = item['variant_name']?.toString().trim();
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
          option['option_name'],
          fallback: 'Option ${optionIndex + 1}',
        );
        options.add(
          KioskOption(
            id: textValue(
              option['option_id'],
              fallback: 'RESTORED-$externalId-OPTION-$index-$optionIndex',
            ),
            name: optionName,
            price: intValue(option['price']),
            kitchenPrepared: option['kitchen_prepared'] as bool? ?? false,
            automatic: option['automatic'] as bool? ?? false,
          ),
        );
      }

      // The reporting database stores the final item unit_price, while the
      // kiosk model derives unitPrice from size/variant + options. Assign the
      // remaining base price to the selected size (or variant) so restoration
      // preserves the original transaction total.
      final storedUnitPrice = intValue(item['unit_price']);
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
            item['category']?.toString() ?? '',
          ) ??
          KioskCategory.accessories;

      final temperature = item['drink_temperature']?.toString().trim();
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
        kitchenPrepared: item['kitchen_prepared'] as bool? ?? false,
        sizes: size == null ? const [] : [size],
        variants: variant == null ? const [] : [variant],
      );

      restoredItems.add(
        KioskCartItem(
          product: product,
          size: size,
          variant: variant,
          quantity: intValue(item['quantity'], fallback: 1),
          options: List.unmodifiable(options),
          drinkTemperature: normalizedTemperature,
        ),
      );
    }

    return KioskOrder(
      id: externalId,
      orderNumber: textValue(
        json['order_number'],
        fallback: externalId,
      ),
      createdAt: dateValue(json['transaction_date'] ?? json['created_at']),
      orderType: textValue(
        json['order_type'],
        fallback: 'Take Out',
      ),
      paymentMethod: textValue(
        json['payment_method'],
        fallback: 'Pay at Counter',
      ),
      paymentStatus: textValue(
        json['payment_status'],
        fallback: 'pending',
      ),
      orderMode: textValue(
        json['order_mode'],
        fallback: 'Customer',
      ),
      status: KioskOrderStatusX.fromValue(
        textValue(json['status'], fallback: 'pending'),
      ),
      cancellationReason: json['cancellation_reason']?.toString(),
      modificationReason: json['modification_reason']?.toString(),
      modifiedAt: json['modified_at'] == null
          ? null
          : DateTime.tryParse(json['modified_at'].toString()),
      items: List.unmodifiable(restoredItems),
      total: intValue(json['total']),
    );
  }

  /// Returns local reporting sync progress without changing any kiosk order.
  Future<ReportingSyncProgress> getTodayProgress({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final orders = await _orderRepository.getOrdersForDate(targetDate);
    return _statusStore.getProgress(orders);
  }

  Future<ReportingSyncProgress> getFullProgress() async {
    final orders = await _orderRepository.getOrders();
    return _statusStore.getProgress(orders);
  }

  Future<ReportingSyncResult> _syncPendingOrders(
    List<KioskOrder> orders, {
    required bool includeAlreadySynced,
  }) async {
    final toSync = <KioskOrder>[];
    for (final order in orders) {
      final alreadySynced =
          await _statusStore.isCurrentSnapshotSynced(order);
      if (includeAlreadySynced || !alreadySynced) {
        toSync.add(order);
      }
    }
    return _syncOrders(toSync);
  }

  Future<ReportingSyncResult> _syncOrders(List<KioskOrder> orders) async {
    final settings = await _settingsRepository.load();
    _validateConfiguration(settings);

    var succeeded = 0;
    final failures = <ReportingSyncFailure>[];

    for (final order in orders) {
      try {
        final deviceId = await _resolveDeviceUuid(
          storeId: settings.storeId.trim(),
          deviceCode: settings.deviceId.trim(),
        );

        final payload = _mapper.mapOrder(
          order: order,
          storeId: settings.storeId.trim(),
          deviceId: deviceId,
        );

        await Supabase.instance.client.rpc(
          _rpcName,
          params: payload.toRpcParams(),
        );

        // Record the acknowledgement separately from the order itself. If
        // this metadata write fails, the next manual sync safely retries the
        // RPC because the database operation is idempotent.
        await _statusStore.markSynced(order);
        succeeded++;
      } catch (error) {
        failures.add(
          ReportingSyncFailure(
            externalTransactionId: order.id,
            orderNumber: order.orderNumber,
            message: error.toString(),
          ),
        );
      }
    }

    return ReportingSyncResult(
      attempted: orders.length,
      succeeded: succeeded,
      failures: List.unmodifiable(failures),
    );
  }

  Future<String> _resolveDeviceUuid({
    required String storeId,
    required String deviceCode,
  }) async {
    // The devices table is protected by RLS. Resolve the kiosk through a
    // narrowly scoped SECURITY DEFINER RPC instead of selecting the table
    // directly with the kiosk's public Supabase client.
    final result = await Supabase.instance.client.rpc(
      'resolve_kiosk_device',
      params: {
        'p_store_id': storeId,
        'p_device_code': deviceCode,
      },
    );

    final id = result?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError(
        'No active kiosk device was found for Store ID '
        '$storeId and Device / Kiosk Code $deviceCode. '
        'Create or activate this device in the Supabase devices table.',
      );
    }

    return id;
  }

  void _validateConfiguration(KioskSettings settings) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY).',
      );
    }

    final storeId = settings.storeId.trim();
    final deviceId = settings.deviceId.trim();
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );

    if (!uuidPattern.hasMatch(storeId)) {
      throw StateError(
        'Reporting sync is not configured. Set a valid Store ID UUID '
        'in Kiosk Settings.',
      );
    }

    if (deviceId.isEmpty) {
      throw StateError(
        'Reporting sync is not configured. Set the Device / Kiosk Code '
        'in Kiosk Settings.',
      );
    }
  }
}
