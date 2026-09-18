import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import 'catalog_sync_version_guard.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';

/// Database-master catalog writer used by catalog administration screens.
///
/// The kiosk remains a local operational cache, but catalog mutations are
/// committed to the store master first. The local copy is updated only after
/// the database accepts the complete catalog.
class StoreCatalogMasterService {
  StoreCatalogMasterService({
    ProductCatalogRepository? repository,
    KioskSettingsRepository? settingsRepository,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository();

  final ProductCatalogRepository _repository;
  final KioskSettingsRepository _settingsRepository;

  static const _versionKey = 'bigger_brew_store_catalog_master_version_v1';
  static const _versionRpc = 'get_store_catalog_version';
  static const _publishRpc = 'publish_store_catalog_from_kiosk';

  Future<ProductCatalog> loadMasterCatalog() async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);
    final client = Supabase.instance.client;

    final version = (await client.rpc(
      _versionRpc,
      params: {'p_store_id': settings.storeId.trim()},
    ))?.toString().trim() ?? '';
    if (version.isEmpty) {
      throw StateError(
        'No store master catalog exists yet. Initialize the master catalog '
        'from Administration Sync first.',
      );
    }

    final raw = await client.rpc(
      'get_store_catalog',
      params: {'p_store_id': settings.storeId.trim()},
    );
    if (raw is! Map) {
      throw const FormatException('The store master catalog returned an invalid payload.');
    }

    final json = Map<String, dynamic>.from(raw);
    json['catalogVersion'] = (json['catalogVersion'] ?? version).toString();
    json['schemaVersion'] =
        json['schemaVersion'] ?? ProductCatalog.currentSchemaVersion;
    final catalog = CatalogSchemaGuard.decodeAndValidate(
      json,
      source: 'store master catalog',
    );
    ProductCatalogRepository.validate(catalog);

    return catalog;
  }

  /// Commits the complete catalog to the store master using an optimistic
  /// version check, then replaces the local operational copy.
  Future<ProductCatalog> publishCatalog(
    ProductCatalog catalog, {
    String auditAction = 'Publish catalog to store master',
    String? expectedVersion,
  }) async {
    final settings = await _settingsRepository.load();
    _validateSettings(settings);
    CatalogSchemaGuard.ensureSupported(
      catalog.schemaVersion,
      source: 'catalog',
    );
    ProductCatalogRepository.validate(catalog);

    final client = Supabase.instance.client;
    final currentVersion = (await client.rpc(
      _versionRpc,
      params: {'p_store_id': settings.storeId.trim()},
    ))?.toString().trim() ?? '';
    if (currentVersion.isEmpty) {
      throw StateError(
        'No store master catalog exists yet. Initialize the master catalog '
        'from Administration Sync first.',
      );
    }

    if (expectedVersion != null) {
      CatalogSyncVersionGuard.ensureLocalMatchesMaster(
        localVersion: expectedVersion,
        masterVersion: currentVersion,
      );
    }

    final result = await client.rpc(
      _publishRpc,
      params: {
        'p_store_id': settings.storeId.trim(),
        'p_device_code': settings.deviceId.trim(),
        'p_expected_version': expectedVersion?.trim() ?? currentVersion,
        'p_catalog': catalog.toJson(),
      },
    );
    final newVersion = result?.toString().trim() ?? '';
    if (newVersion.isEmpty) {
      throw StateError('The database did not return the new catalog version.');
    }

    final accepted = catalog.copyWith(catalogVersion: newVersion);
    ProductCatalogRepository.validate(accepted);

    await _repository.saveCatalog(
      accepted,
      auditAction: auditAction,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, newVersion);
    return accepted;
  }

  /// Applies one catalog mutation to the current Store Master snapshot and
  /// publishes the resulting complete catalog. The accepted catalog is also
  /// written to the kiosk's local operational cache by [publishCatalog].
  Future<ProductCatalog> mutateCatalog(
    ProductCatalog Function(ProductCatalog catalog) mutation, {
    String auditAction = 'Update store master catalog',
  }) async {
    final master = await loadMasterCatalog();
    final updated = mutation(master);
    CatalogSchemaGuard.ensureSupported(
      updated.schemaVersion,
      source: 'catalog',
    );
    ProductCatalogRepository.validate(updated);

    return publishCatalog(
      updated,
      expectedVersion: master.catalogVersion,
      auditAction: auditAction,
    );
  }

  Future<ProductCatalog> refreshLocalFromMaster() async {
    final catalog = await loadMasterCatalog();
    final current = await _repository.load();
    await _repository.saveImportRecoveryBackup(current);
    await _repository.saveCatalog(
      catalog,
      auditAction: 'Refresh catalog from store master',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, catalog.catalogVersion);
    return catalog;
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
