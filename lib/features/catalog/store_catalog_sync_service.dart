import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';

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
      '${updated ? 'Catalog refreshed' : 'Catalog already current'}: '
      '$categoryCount categories, $productCount products, '
      '$optionDefinitionCount option definitions, version $catalogVersion.';
}

/// Synchronizes the kiosk's local ProductCatalog from the store-level
/// Supabase master catalog. The local catalog remains the operational copy;
/// this service never publishes local changes to the master.
class StoreCatalogSyncService {
  StoreCatalogSyncService({
    ProductCatalogRepository? repository,
    KioskSettingsRepository? settingsRepository,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository();

  static const _versionKey = 'bigger_brew_store_catalog_master_version_v1';
  static const _catalogRpc = 'get_store_catalog';
  static const _versionRpc = 'get_store_catalog_version';

  final ProductCatalogRepository _repository;
  final KioskSettingsRepository _settingsRepository;

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
    ProductCatalogRepository.validate(catalog);

    // Save a rollback point before replacing the operational local copy.
    final current = await _repository.load();
    await _repository.saveImportRecoveryBackup(current);
    await _repository.saveCatalog(
      catalog,
      auditAction: 'Refresh catalog from store master',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, catalog.catalogVersion);

    return StoreCatalogSyncResult(
      catalogVersion: catalog.catalogVersion,
      categoryCount: catalog.categories.length,
      productCount: catalog.products.length,
      optionDefinitionCount: catalog.optionDefinitions.length,
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, version);

    return StoreCatalogSyncResult(
      catalogVersion: version,
      categoryCount: catalog.categories.length,
      productCount: catalog.products.length,
      optionDefinitionCount: catalog.optionDefinitions.length,
      updated: true,
    );
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
