import '../catalog/store_catalog_sync_service.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';
import 'kiosk_device_recovery_service.dart';
import 'kiosk_device_reprovisioning.dart';
import 'kiosk_device_reprovisioning_audit.dart';

class KioskDeviceReprovisioningResult {
  const KioskDeviceReprovisioningResult({
    required this.target,
    required this.catalogRefreshed,
  });

  final KioskDeviceRecoveryStatus target;
  final bool catalogRefreshed;

  String get summary =>
      'Kiosk identity changed to ${target.deviceCode}. '
      '${catalogRefreshed ? 'The Store Master catalog was refreshed.' : 'The catalog still requires a manual refresh.'}';
}

/// Applies a safe replacement-device identity locally after the target has
/// been verified as an active Store Management device.
class KioskDeviceReprovisioningService {
  KioskDeviceReprovisioningService({
    KioskSettingsRepository? settingsRepository,
    KioskDeviceRecoveryService? recoveryService,
    StoreCatalogSyncService? catalogSyncService,
    KioskDeviceReprovisioningAuditRepository? auditRepository,
  })  : _settingsRepository = settingsRepository ?? KioskSettingsRepository(),
        _recoveryService = recoveryService ?? const KioskDeviceRecoveryService(),
        _catalogSyncService = catalogSyncService ?? StoreCatalogSyncService(),
        _auditRepository = auditRepository ?? KioskDeviceReprovisioningAuditRepository();

  final KioskSettingsRepository _settingsRepository;
  final KioskDeviceRecoveryService _recoveryService;
  final StoreCatalogSyncService _catalogSyncService;
  final KioskDeviceReprovisioningAuditRepository _auditRepository;

  Future<KioskDeviceReprovisioningResult> apply({
    required String targetStoreId,
    required String targetDeviceCode,
  }) async {
    final current = await _settingsRepository.load();
    final plan = KioskDeviceReprovisionPlan(
      currentStoreId: current.storeId,
      currentDeviceCode: current.deviceId,
      targetStoreId: targetStoreId,
      targetDeviceCode: targetDeviceCode,
    );

    if (!plan.isReplacement) {
      throw StateError('The target device is the current kiosk device.');
    }

    final verified = await _recoveryService.verify(
      storeId: plan.normalizedTargetStoreId,
      deviceCode: plan.normalizedTargetDeviceCode,
    );
    if (!plan.canApply(verified.state)) {
      throw StateError(verified.message);
    }

    // The old local catalog remains intact, but its remembered master version
    // is invalid for the newly provisioned device until the master is pulled.
    await _settingsRepository.setReportingIdentity(
      storeId: plan.normalizedTargetStoreId,
      deviceId: plan.normalizedTargetDeviceCode,
    );
    await _catalogSyncService.clearLocalMasterVersion();

    var catalogRefreshed = false;
    try {
      await _catalogSyncService.refreshFromMaster(force: true);
      catalogRefreshed = true;
    } catch (_) {
      // Identity remains changed. A failed refresh must not erase the local
      // catalog or restore the old device identity. With the version cleared,
      // catalog publishing remains protected until a successful refresh.
    }

    try {
      await _auditRepository.append(
        KioskDeviceReprovisioningAuditEntry(
          createdAt: DateTime.now(),
          previousStoreId: current.storeId.trim(),
          previousDeviceCode: current.deviceId.trim(),
          targetStoreId: plan.normalizedTargetStoreId,
          targetDeviceCode: plan.normalizedTargetDeviceCode,
          catalogRefreshed: catalogRefreshed,
        ),
      );
    } catch (_) {
      // Local audit is best effort; it must never undo a verified identity
      // change or turn a successful re-provision into a failure.
    }

    return KioskDeviceReprovisioningResult(
      target: verified,
      catalogRefreshed: catalogRefreshed,
    );
  }
}
