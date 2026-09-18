import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import 'store_catalog_master_service.dart';
import 'catalog_sync_version_guard.dart';

class StoreCatalogSyncResult {
  const StoreCatalogSyncResult({
    required this.catalogVersion,
    required this.categoryCount,
    required this.productCount,
    required this.optionDefinitionCount,
    required this.updated,
  });

  final String catalogVersion;
  final int categoryCount;
  final int productCount;
  final int optionDefinitionCount;
  final bool updated;

  String get summary =>
      '${updated ? 'Catalog synchronized' : 'Catalog already current'}: '
      '$categoryCount categories, $productCount products, '
      '$optionDefinitionCount option definitions, version $catalogVersion.';
}

/// Synchronizes the kiosk's local ProductCatalog with the store-level
/// Supabase master catalog. The local catalog remains the operational copy,
/// while explicit administration actions can publish it to the master using
/// optimistic version checks.
class StoreCatalogSyncService {
  StoreCatalogSyncService({
    ProductCatalogRepository? repository,
    KioskSettingsRepository? settingsRepository,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository(),
        _masterService = StoreCatalogMasterService(
          repository: repository,
          settingsRepository: settingsRepository,
        );

  static const _versionKey = 'bigger_brew_store_catalog_master_version_v1';
  static const _catalogRpc = 'get_store_catalog';
  static const _versionRpc = 'get_store_catalog_version';
  static const _reportSyncRpc = 'report_kiosk_catalog_sync';

  final ProductCatalogRepository _repository;
  final KioskSettingsRepository _settingsRepository;
  final StoreCatalogMasterService _masterService;

  Future<String?> localMasterVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey);
  }

  Future<String?> getMasterVersion({bool allowMissing = false}) async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);
    try {
      final result = await Supabase.instance.client.rpc(
        _versionRpc,
        params: {'p_store_id': settings.storeId.trim()},
      );
      final version = result?.toString().trim() ?? '';
      if (version.isEmpty) {
        if (allowMissing) return null;
        throw StateError('The store catalog master has no catalog version.');
      }
      return version;
    } catch (error) {
      if (allowMissing && error.toString().contains('No master catalog exists')) {
        return null;
      }
      rethrow;
    }
  }

  Future<bool> isMasterCatalogChanged() async {
    final master = await getMasterVersion();
    final local = await localMasterVersion();
    return local != master;
  }

  /// Checks the store master and refreshes the local operational catalog when
  /// its version has changed. If the master is not initialized yet, or the
  /// kiosk is temporarily offline, the existing local catalog is retained.
  /// This keeps customer ordering available while allowing catalog changes to
  /// propagate automatically once connectivity is available.
  Future<StoreCatalogSyncResult?> refreshIfMasterChanged() async {
    final settings = await _settingsRepository.load();
    try {
      _validateSettings(settings);
      final masterVersion = await getMasterVersion(allowMissing: true);
      if (masterVersion == null) {
        return null;
      }

      final localVersion = await localMasterVersion();
      if (localVersion == masterVersion) {
        // The local version already matches the master. Validate the cached
        // catalog before reporting it as successfully synchronized.
        final local = await _repository.load();
        ProductCatalogRepository.validate(local);
        await _reportSuccessfulSync(settings, masterVersion);
        return null;
      }

      return await refreshFromMaster(force: true);
    } catch (_) {
      // Automatic refresh must never take the customer kiosk offline. The
      // current local catalog remains the last known-good operational copy.
      return null;
    }
  }

  /// Pulls the complete store catalog from the master database and atomically
  /// replaces the kiosk's local catalog only after validation succeeds.
  Future<StoreCatalogSyncResult> refreshFromMaster({bool force = false}) async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);

    final client = Supabase.instance.client;
    final masterVersion = (await client.rpc(
      _versionRpc,
      params: {'p_store_id': settings.storeId.trim()},
    ))?.toString().trim() ?? '';

    if (masterVersion.isEmpty) {
      throw StateError('The store catalog master has no catalog version.');
    }

    final localVersion = await localMasterVersion();
    if (!force && localVersion == masterVersion) {
      final local = await _repository.load();
      ProductCatalogRepository.validate(local);
      await _reportSuccessfulSync(settings, masterVersion);
      return StoreCatalogSyncResult(
        catalogVersion: local.catalogVersion,
        categoryCount: local.categories.length,
        productCount: local.products.length,
        optionDefinitionCount: local.optionDefinitions.length,
        updated: false,
      );
    }

    final raw = await client.rpc(
      _catalogRpc,
      params: {'p_store_id': settings.storeId.trim()},
    );

    if (raw is! Map) {
      throw const FormatException(
        'The store catalog master returned an invalid payload.',
      );
    }

    final json = Map<String, dynamic>.from(raw);
    final catalogJson = Map<String, dynamic>.from(json);
    catalogJson['catalogVersion'] =
        (json['catalogVersion'] ?? masterVersion).toString();
    catalogJson['schemaVersion'] =
        json['schemaVersion'] ?? ProductCatalog.currentSchemaVersion;

    final catalog = CatalogSchemaGuard.decodeAndValidate(
      catalogJson,
      source: 'store catalog master',
    );
    final authoritativeVersion =
        CatalogSyncVersionGuard.ensureCatalogVersionMatchesMaster(
      catalogVersion: catalog.catalogVersion,
      masterVersion: masterVersion,
    );
    final authoritativeCatalog = catalog.copyWith(
      catalogVersion: authoritativeVersion,
    );
    ProductCatalogRepository.validate(authoritativeCatalog);

    // Save a rollback point before replacing the operational local copy.
    final current = await _repository.load();
    await _repository.saveImportRecoveryBackup(current);
    await _repository.saveCatalog(
      authoritativeCatalog,
      auditAction: 'Refresh catalog from store master',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, authoritativeVersion);
    await _reportSuccessfulSync(settings, authoritativeVersion);

    return StoreCatalogSyncResult(
      catalogVersion: authoritativeVersion,
      categoryCount: authoritativeCatalog.categories.length,
      productCount: authoritativeCatalog.products.length,
      optionDefinitionCount: authoritativeCatalog.optionDefinitions.length,
      updated: true,
    );
  }

  /// Publishes the kiosk's current local catalog to an existing store master.
  ///
  /// This is intentionally different from one-time initialization: the kiosk
  /// must first be synchronized to a known master version. If the master has
  /// changed since the kiosk last pulled it, the publish is rejected rather
  /// than overwriting newer Store Management changes. The database RPC also
  /// performs the final optimistic-lock check atomically.
  Future<StoreCatalogSyncResult> syncLocalCatalogToMaster() async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);

    final catalog = await _repository.load();
    CatalogSchemaGuard.ensureSupported(
      catalog.schemaVersion,
      source: 'local kiosk catalog',
    );
    ProductCatalogRepository.validate(catalog);

    final masterVersion = await getMasterVersion();
    final localVersion = CatalogSyncVersionGuard.ensureLocalMatchesMaster(
      localVersion: await localMasterVersion(),
      masterVersion: masterVersion,
    );

    final accepted = await _masterService.publishCatalog(
      catalog,
      expectedVersion: localVersion,
      auditAction: 'Sync local catalog to store master',
    );

    return StoreCatalogSyncResult(
      catalogVersion: accepted.catalogVersion,
      categoryCount: accepted.categories.length,
      productCount: accepted.products.length,
      optionDefinitionCount: accepted.optionDefinitions.length,
      updated: true,
    );
  }

  Future<bool> masterCatalogExists() async {
    return (await getMasterVersion(allowMissing: true)) != null;
  }

  /// One-time initialization helper. It is intentionally only accepted by
  /// the database when the store has no master catalog yet. After the master
  /// exists, this operation cannot overwrite it.
  Future<StoreCatalogSyncResult> initializeEmptyMasterFromLocal() async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);
    final catalog = await _repository.load();
    ProductCatalogRepository.validate(catalog);

    final result = await Supabase.instance.client.rpc(
      'initialize_store_catalog_from_kiosk',
      params: {
        'p_store_id': settings.storeId.trim(),
        'p_device_code': settings.deviceId.trim(),
        'p_catalog': catalog.toJson(),
      },
    );

    final version = result?.toString().trim() ?? '';
    if (version.isEmpty) {
      throw StateError('The database did not return a catalog version.');
    }

    final acceptedCatalog = CatalogSyncVersionGuard.withAuthoritativeVersion(
      catalog,
      version,
    );
    ProductCatalogRepository.validate(acceptedCatalog);
    await _repository.saveCatalog(
      acceptedCatalog,
      auditAction: 'Initialize local catalog from store master',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, version);
    await _reportSuccessfulSync(settings, version);

    return StoreCatalogSyncResult(
      catalogVersion: acceptedCatalog.catalogVersion,
      categoryCount: acceptedCatalog.categories.length,
      productCount: acceptedCatalog.products.length,
      optionDefinitionCount: acceptedCatalog.optionDefinitions.length,
      updated: true,
    );
  }

  /// Reports a successful catalog cache/validation to Store Management.
  /// Reporting is deliberately non-fatal: catalog synchronization must remain
  /// usable even when the reporting migration is not installed yet, or the
  /// kiosk temporarily cannot reach Supabase after a successful local refresh.
  Future<void> _reportSuccessfulSync(
    KioskSettings settings,
    String catalogVersion,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        _reportSyncRpc,
        params: {
          'p_store_id': settings.storeId.trim(),
          'p_device_code': settings.deviceId.trim(),
          'p_catalog_version': catalogVersion.trim(),
        },
      );
    } catch (_) {
      // Sync reporting is observability only. Never roll back a valid local
      // catalog because Store Management status reporting is unavailable.
    }
  }

  void _validateSettings(KioskSettings settings) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY).',
      );
    }

    final storeId = settings.storeId.trim();
    final deviceCode = settings.deviceId.trim();
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );

    if (!uuidPattern.hasMatch(storeId)) {
      throw StateError('Set a valid Store ID UUID in Kiosk Settings.');
    }
    if (deviceCode.isEmpty) {
      throw StateError('Set the Device / Kiosk Code in Kiosk Settings.');
    }
  }
}
