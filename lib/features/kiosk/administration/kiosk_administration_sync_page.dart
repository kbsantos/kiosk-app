import 'package:flutter/material.dart';

import '../orders/kiosk_order_repository.dart';
import '../../reporting_sync/reporting_sync_result.dart';
import '../../reporting_sync/reporting_sync_service.dart';
import '../../reporting_sync/reporting_sync_operational_status.dart';
import '../../reporting_sync/kiosk_device_recovery.dart';
import '../../reporting_sync/kiosk_device_recovery_service.dart';
import '../../reporting_sync/kiosk_device_reprovisioning_service.dart';
import '../../reporting_sync/kiosk_device_lifecycle.dart';
import '../../reporting_sync/kiosk_device_lifecycle_service.dart';
import '../settings/kiosk_settings_repository.dart';
import '../../catalog/store_catalog_sync_service.dart';
import '../../catalog/catalog_sync_status.dart';
import '../../inventory/inventory_movement_repository.dart';
import '../../inventory/inventory_movement_sync_models.dart';
import '../../inventory/inventory_movement_sync_service.dart';

/// Administrative synchronization tools.
///
/// Historical drink-temperature synchronization updates the local kiosk
/// transaction snapshots. The full transaction sync then sends the current
/// local snapshots to the reporting database.
class KioskAdministrationSyncPage extends StatefulWidget {
  const KioskAdministrationSyncPage({
    super.key,
    this.catalogSyncService,
  });

  final StoreCatalogSyncService? catalogSyncService;

  @override
  State<KioskAdministrationSyncPage> createState() =>
      _KioskAdministrationSyncPageState();
}

class _KioskAdministrationSyncPageState
    extends State<KioskAdministrationSyncPage> {
  final KioskOrderRepository _orderRepository = KioskOrderRepository();
  final ReportingSyncService _reportingSyncService = ReportingSyncService();
  final KioskDeviceRecoveryService _deviceRecoveryService =
      const KioskDeviceRecoveryService();
  final KioskDeviceReprovisioningService _deviceReprovisioningService =
      KioskDeviceReprovisioningService();
  final KioskDeviceLifecycleService _deviceLifecycleService =
      const KioskDeviceLifecycleService();
  final KioskDeviceLifecycleAuditRepository _deviceLifecycleAuditRepository =
      KioskDeviceLifecycleAuditRepository();
  final KioskSettingsRepository _settingsRepository =
      KioskSettingsRepository();
  final InventoryMovementRepository _inventoryMovementRepository =
      const InventoryMovementRepository();
  final InventoryMovementSyncService _inventoryMovementSyncService =
      InventoryMovementSyncService();
  late final StoreCatalogSyncService _catalogSyncService =
      widget.catalogSyncService ?? StoreCatalogSyncService();

  bool _catalogSyncing = false;
  bool _historicalSyncing = false;
  bool _categorySyncing = false;
  bool _transactionSyncing = false;
  bool _restoreSyncing = false;
  bool? _masterCatalogExists;
  CatalogSyncStatusSnapshot? _catalogStatus;
  bool _catalogStatusLoading = false;
  ReportingSyncOperationalStatus? _reportingStatus;
  bool _reportingStatusLoading = false;
  bool _deviceRecoveryLoading = false;
  bool _deviceReprovisioningLoading = false;
  KioskDeviceRecoveryStatus? _deviceRecoveryStatus;
  bool _deviceLifecycleLoading = false;
  KioskDeviceLifecycleStatus? _deviceLifecycleStatus;
  bool _inventorySyncLoading = false;
  bool _inventorySyncing = false;
  InventoryMovementSyncStatus? _inventorySyncStatus;

  @override
  void initState() {
    super.initState();
    _checkMasterCatalog();
    _loadCatalogStatus();
    _loadReportingStatus();
    _loadDeviceLifecycleStatus();
    _loadInventorySyncStatus();
  }

  Future<void> _loadCatalogStatus() async {
    if (_catalogStatusLoading) return;
    if (mounted) setState(() => _catalogStatusLoading = true);

    try {
      final status = await _catalogSyncService.loadCatalogSyncStatus();
      if (!mounted) return;
      setState(() {
        _catalogStatus = status;
        _masterCatalogExists = status.status ==
                CatalogSyncStatus.masterNotInitialized
            ? false
            : status.status == CatalogSyncStatus.masterUnavailable
                ? _masterCatalogExists
                : true;
      });
    } finally {
      if (mounted) setState(() => _catalogStatusLoading = false);
    }
  }

  Future<void> _loadReportingStatus() async {
    if (_reportingStatusLoading) return;
    if (mounted) setState(() => _reportingStatusLoading = true);
    try {
      final status = await _reportingSyncService.getOperationalStatus();
      if (!mounted) return;
      setState(() => _reportingStatus = status);
    } finally {
      if (mounted) setState(() => _reportingStatusLoading = false);
    }
  }

  Future<void> _loadInventorySyncStatus() async {
    if (_inventorySyncLoading) return;
    if (mounted) setState(() => _inventorySyncLoading = true);
    try {
      final movements = await _inventoryMovementRepository.loadMovements();
      final status = await _inventoryMovementSyncService.getStatus(movements);
      if (!mounted) return;
      setState(() => _inventorySyncStatus = status);
    } finally {
      if (mounted) setState(() => _inventorySyncLoading = false);
    }
  }

  Future<void> _syncInventoryMovements() async {
    if (_inventorySyncing) return;
    if (mounted) setState(() => _inventorySyncing = true);
    try {
      final movements = await _inventoryMovementRepository.loadMovements();
      final result = await _inventoryMovementSyncService.syncPending(movements);
      if (!mounted) return;
      await _loadInventorySyncStatus();
      if (!mounted) return;
      final message = result.failed == 0
          ? result.attempted == 0
              ? 'NO PENDING INVENTORY MOVEMENTS.'
              : '${result.succeeded} INVENTORY MOVEMENT(S) SYNCED.'
          : '${result.succeeded} SYNCED, ${result.failed} FAILED. FAILED MOVEMENTS REMAIN PENDING.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _inventorySyncing = false);
    }
  }

  Future<void> _loadDeviceLifecycleStatus() async {
    if (_deviceLifecycleLoading) return;
    if (mounted) setState(() => _deviceLifecycleLoading = true);
    try {
      final settings = await _settingsRepository.load();
      final status = await _deviceLifecycleService.loadStatus(
        storeId: settings.storeId,
        deviceCode: settings.deviceId,
      );
      try {
        await _deviceLifecycleAuditRepository.append(
          KioskDeviceLifecycleAuditEntry(
            createdAt: DateTime.now(),
            storeId: status.storeId,
            deviceCode: status.deviceCode,
            state: status.state,
            deviceUuid: status.deviceUuid,
          ),
        );
      } catch (_) {
        // Local lifecycle observations are best effort.
      }
      if (!mounted) return;
      setState(() => _deviceLifecycleStatus = status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceLifecycleStatus = KioskDeviceLifecycleStatus(
          state: KioskDeviceLifecycleState.unavailable,
          storeId: '',
          deviceCode: '',
        );
      });
    } finally {
      if (mounted) setState(() => _deviceLifecycleLoading = false);
    }
  }

  Future<void> _verifyDeviceIdentity() async {
    if (_deviceRecoveryLoading) return;
    setState(() => _deviceRecoveryLoading = true);
    try {
      final settings = await _settingsRepository.load();
      final status = await _deviceRecoveryService.verify(
        storeId: settings.storeId,
        deviceCode: settings.deviceId,
      );
      if (!mounted) return;
      setState(() => _deviceRecoveryStatus = status);
      await _showMessage(
        title: status.title,
        message: status.message,
      );
    } catch (error) {
      if (mounted) await _showError('DEVICE VERIFICATION FAILED', error);
    } finally {
      if (mounted) setState(() => _deviceRecoveryLoading = false);
    }
  }

  Future<void> _reprovisionDevice() async {
    if (_deviceReprovisioningLoading || _transactionSyncing || _restoreSyncing) {
      return;
    }

    final current = await _settingsRepository.load();
    if (!mounted) return;

    final storeController = TextEditingController(text: current.storeId);
    final deviceController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('RE-PROVISION KIOSK DEVICE'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Use this only when Store Management has already registered '
                    'and activated the replacement device. This changes the local '
                    'kiosk identity and refreshes the catalog from Store Master. '
                    'It does not restore or delete transactions.',
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: storeController,
                  decoration: const InputDecoration(
                    labelText: 'Replacement Store ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deviceController,
                  decoration: const InputDecoration(
                    labelText: 'Replacement Device / Kiosk Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.devices_outlined),
              label: const Text('VERIFY & RE-PROVISION'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final targetStoreId = storeController.text.trim();
      final targetDeviceCode = deviceController.text.trim();
      if (targetStoreId.isEmpty || targetDeviceCode.isEmpty) {
        await _showError(
          'RE-PROVISIONING BLOCKED',
          'Replacement Store ID and Device / Kiosk Code are required.',
        );
        return;
      }

      setState(() => _deviceReprovisioningLoading = true);
      final result = await _deviceReprovisioningService.apply(
        targetStoreId: targetStoreId,
        targetDeviceCode: targetDeviceCode,
      );
      if (!mounted) return;
      await _loadCatalogStatus();
      await _showMessage(
        title: result.catalogRefreshed
            ? 'KIOSK RE-PROVISIONED'
            : 'KIOSK IDENTITY UPDATED',
        message: result.summary,
      );
      await _verifyDeviceIdentity();
    } catch (error) {
      if (mounted) await _showError('RE-PROVISIONING FAILED', error);
    } finally {
      if (mounted) setState(() => _deviceReprovisioningLoading = false);
    }
  }

  Future<void> _checkMasterCatalog() async {
    try {
      final exists = await _catalogSyncService.masterCatalogExists();
      if (mounted) setState(() => _masterCatalogExists = exists);
    } catch (_) {
      if (mounted) setState(() => _masterCatalogExists = null);
    }
  }

  Future<void> _initializeMasterCatalog() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('INITIALIZE STORE MASTER CATALOG'),
        content: const Text(
          'This is a one-time setup operation. The current kiosk catalog will be published as the store master only if no master catalog exists yet. Once initialized, this kiosk will use the database master as the source of truth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('INITIALIZE MASTER'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _catalogSyncing = true);
    try {
      final result = await _catalogSyncService.initializeEmptyMasterFromLocal();
      if (!mounted) return;
      setState(() => _masterCatalogExists = true);
      await _loadCatalogStatus();
      await _showMessage(
        title: 'MASTER CATALOG INITIALIZED',
        message: result.summary,
      );
    } catch (error) {
      if (mounted) await _showError('MASTER INITIALIZATION FAILED', error);
    } finally {
      if (mounted) setState(() => _catalogSyncing = false);
    }
  }

  Future<void> _syncLocalCatalogToMaster() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SYNC LOCAL CATALOG TO MASTER'),
        content: const Text(
          'Publish this kiosk current catalog to the store master?\n\n'
          'Categories, products, sizes, variants, options, and add-ons will '
          'replace the current store master catalog. The operation is allowed '
          'only when this kiosk is synchronized to the current master version. '
          'If Store Management changed the catalog, this sync will be rejected.\n\n'
          'This does not change local transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('SYNC LOCAL CATALOG'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _catalogSyncing = true);
    try {
      final result = await _catalogSyncService.syncLocalCatalogToMaster();
      if (!mounted) return;
      await _loadCatalogStatus();
      await _showMessage(
        title: 'LOCAL CATALOG SYNC COMPLETE',
        message: result.summary,
      );
    } catch (error) {
      if (mounted) await _showError('LOCAL CATALOG SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _catalogSyncing = false);
    }
  }

  Future<void> _refreshProductCatalog() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) {
      return;
    }

    setState(() => _catalogSyncing = true);
    try {
      final changed = await _catalogSyncService.isMasterCatalogChanged();
      if (!mounted) return;

      if (!changed) {
        final result = await _catalogSyncService.refreshFromMaster();
        if (!mounted) return;
        await _showMessage(
          title: 'CATALOG ALREADY CURRENT',
          message: result.summary,
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('REFRESH PRODUCT CATALOG'),
          content: const Text(
            'Download the latest store master catalog to this kiosk?\n\n'
            'This updates the local kiosk copy of categories, products, sizes, variants, options, and add-ons. The database master is not changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('REFRESH CATALOG'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final result = await _catalogSyncService.refreshFromMaster(force: true);
      if (!mounted) return;
      await _loadCatalogStatus();
      await _showMessage(
        title: 'CATALOG REFRESH COMPLETE',
        message: result.summary,
      );
    } catch (error) {
      if (mounted) await _showError('CATALOG REFRESH FAILED', error);
    } finally {
      if (mounted) setState(() => _catalogSyncing = false);
    }
  }

  Future<void> _syncHistoricalDrinks() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) return;

    setState(() => _historicalSyncing = true);

    try {
      final preview = await _orderRepository
          .syncHistoricalDrinkTemperatures(dryRun: true);

      if (!mounted) return;

      if (preview.updatedItems == 0) {
        await _showMessage(
          title: 'HISTORICAL SYNC',
          message:
              'No historical drink temperatures need to be synchronized.\n\n'
              '${preview.totalOrders} local transaction(s) were checked.',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('SYNC HISTORICAL DRINKS'),
          content: Text(
            '${preview.updatedItems} drink item(s) across '
            '${preview.updatedOrders} transaction(s) will be updated.\n\n'
            'The current product catalog temperature will be applied to '
            'historical drink items. Other transaction details remain unchanged.\n\n'
            'After this completes, use SYNC ALL TRANSACTIONS to send the '
            'updated transaction snapshots to the reporting database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.sync),
              label: const Text('SYNC HISTORICAL'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final result =
          await _orderRepository.syncHistoricalDrinkTemperatures();

      if (!mounted) return;

      await _showMessage(
        title: 'HISTORICAL SYNC COMPLETE',
        message:
            '${result.updatedItems} drink item(s) updated across '
            '${result.updatedOrders} transaction(s).\n\n'
            'The changes are now stored locally. Run SYNC ALL TRANSACTIONS '
            'to send the updated snapshots to the reporting database.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showError('HISTORICAL SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _historicalSyncing = false);
    }
  }

  Future<void> _syncHistoricalCategories() async {
    if (_catalogSyncing ||
        _historicalSyncing ||
        _categorySyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
      return;
    }

    setState(() => _categorySyncing = true);

    try {
      final preview = await _orderRepository
          .syncHistoricalTransactionCategories(dryRun: true);

      if (!mounted) return;

      if (preview.updatedItems == 0) {
        await _showMessage(
          title: 'HISTORICAL CATEGORY SYNC',
          message:
              'No historical transaction categories need to be updated.\n\n'
              '${preview.totalOrders} local transaction(s) were checked.\n'
              '${preview.skippedItems} item(s) were skipped because their products are no longer in the current catalog.',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('SYNC HISTORICAL CATEGORIES'),
          content: Text(
            '${preview.updatedItems} transaction item(s) across '
            '${preview.updatedOrders} transaction(s) will be updated.\n\n'
            'The current local product category will be applied to matching '
            'historical transaction items. Product, price, quantity, options, '
            'totals, and other transaction details remain unchanged.\n\n'
            '${preview.skippedItems} item(s) will be left unchanged because '
            'their products are no longer in the current catalog.\n\n'
            'After this completes, use SYNC ALL TRANSACTIONS to send the '
            'corrected local snapshots to the reporting database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.category_outlined),
              label: const Text('UPDATE CATEGORIES'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final result =
          await _orderRepository.syncHistoricalTransactionCategories();

      if (!mounted) return;

      await _showMessage(
        title: 'HISTORICAL CATEGORY SYNC COMPLETE',
        message:
            '${result.updatedItems} transaction item(s) updated across '
            '${result.updatedOrders} transaction(s).\n\n'
            '${result.skippedItems} item(s) were left unchanged because their '
            'products are no longer in the current catalog.\n\n'
            'The corrected snapshots are stored locally. Run SYNC ALL '
            'TRANSACTIONS to send them to the reporting database.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showError('HISTORICAL CATEGORY SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _categorySyncing = false);
    }
  }

  Future<void> _syncAllTransactions() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SYNC ALL TRANSACTIONS'),
        content: const Text(
          'This will send every locally stored kiosk transaction to the '
          'reporting database, including transactions that were previously '
          'synced.\n\n'
          'The reporting operation is idempotent, so existing transactions '
          'are updated rather than duplicated. Local kiosk transactions are '
          'not deleted or otherwise modified by this sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('SYNC ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _transactionSyncing = true);

    try {
      final result = await _reportingSyncService.syncAllTransactions();

      if (!mounted) return;

      await _loadReportingStatus();
      if (!mounted) return;
      await _showReportingResult(result);
    } catch (error) {
      if (!mounted) return;
      await _showError('TRANSACTION SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _transactionSyncing = false);
    }
  }

  Future<void> _restoreMissingTransactions() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing) return;

    setState(() => _restoreSyncing = true);

    try {
      final preview =
          await _reportingSyncService.previewMissingTransactions();

      if (!mounted) return;

      if (preview.missing == 0) {
        final failureDetails = preview.failures.isEmpty
            ? ''
            : '\n\nFailures:\n${preview.failures.map((failure) => '${failure.externalTransactionId}: ${failure.message}').join('\n\n')}';

        await _showMessage(
          title: preview.failures.isEmpty
              ? 'RESTORE CHECK COMPLETE'
              : 'RESTORE CHECK INCOMPLETE',
          message:
              'Reporting database transactions: ${preview.databaseTransactions}\n'
              'Already on kiosk: ${preview.alreadyLocal}\n'
              'Missing from kiosk: 0'
              '$failureDetails',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('RESTORE MISSING TRANSACTIONS'),
          content: Text(
            'Reporting database transactions: ${preview.databaseTransactions}\n'
            'Already on kiosk: ${preview.alreadyLocal}\n'
            'Missing from kiosk: ${preview.missing}\n\n'
            'Only the ${preview.missing} missing transaction(s) will be added. '
            'Existing local transactions will not be overwritten or deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text('RESTORE ${preview.missing}'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final result =
          await _reportingSyncService.restoreMissingTransactions(preview);

      if (!mounted) return;

      final failureDetails = result.failures.isEmpty
          ? ''
          : '\n\nFailures:\n${result.failures.map((failure) => '${failure.externalTransactionId}: ${failure.message}').join('\n\n')}';

      await _showMessage(
        title: result.isSuccess ? 'RESTORE COMPLETE' : 'RESTORE INCOMPLETE',
        message:
            'Reporting database transactions: ${result.databaseTransactions}\n'
            'Already on kiosk: ${result.alreadyLocal}\n'
            'Restored: ${result.restored}\n'
            'Failed: ${result.failed}'
            '$failureDetails',
      );
    } catch (error) {
      if (!mounted) return;
      await _showError('TRANSACTION RESTORE FAILED', error);
    } finally {
      if (mounted) setState(() => _restoreSyncing = false);
    }
  }
  Future<void> _retryPendingReportingSync() async {
    if (_catalogSyncing || _historicalSyncing || _categorySyncing ||
        _transactionSyncing || _restoreSyncing) {
      return;
    }
    setState(() => _transactionSyncing = true);
    try {
      final result = await _reportingSyncService.fullSync();
      if (!mounted) return;
      await _loadReportingStatus();
      if (!mounted) return;
      await _showReportingResult(result);
    } catch (error) {
      if (mounted) await _showError('REPORTING SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _transactionSyncing = false);
    }
  }

  Future<void> _showReportingHistory() async {
    try {
      final history = await _reportingSyncService.getAuditHistory();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('REPORTING SYNC HISTORY'),
          content: SizedBox(
            width: 620,
            child: history.isEmpty
                ? const Text('No manual reporting sync attempts recorded.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final audit = history[index];
                      final failureText = audit.failures.isEmpty
                          ? ''
                          : '\nLast error: ${audit.failures.first.message}';
                      return ListTile(
                        dense: true,
                        title: Text('${audit.succeeded}/${audit.attempted} synced · ${audit.failed} failed'),
                        subtitle: Text(
                          '${audit.completedAt}\n'
                          'Attempted: ${audit.attempted} · '
                          'Succeeded: ${audit.succeeded} · '
                          'Failed: ${audit.failed}$failureText',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) await _showError('SYNC HISTORY FAILED', error);
    }
  }

  Future<void> _showReportingResult(ReportingSyncResult result) {
    final details = result.failures.isEmpty
        ? result.attempted == 0
            ? 'There are no local transactions to synchronize.'
            : 'All transactions were synchronized successfully.'
        : result.failures
            .map(
              (failure) =>
                  '${failure.orderNumber} (${failure.externalTransactionId}):\n'
                  '${failure.message}',
            )
            .join('\n\n');

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          result.isSuccess
              ? 'TRANSACTION SYNC COMPLETE'
              : 'TRANSACTION SYNC INCOMPLETE',
        ),
        content: SingleChildScrollView(
          child: SelectableText('${result.summary}\n\n$details'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessage({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showError(String title, Object error) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(error.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'ADMINISTRATION SYNC',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 72,
                    color: gold,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ADMINISTRATION SYNC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Administrative maintenance for historical transaction data '
                    'and reporting synchronization.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  _CatalogStatusCard(
                    status: _catalogStatus,
                    loading: _catalogStatusLoading,
                    onRefresh: _catalogStatusLoading ? null : _loadCatalogStatus,
                  ),
                  const SizedBox(height: 16),
                  _ReportingStatusCard(
                    status: _reportingStatus,
                    loading: _reportingStatusLoading,
                    busy: _transactionSyncing || _catalogSyncing ||
                        _historicalSyncing || _categorySyncing || _restoreSyncing,
                    onRefresh: _reportingStatusLoading ? null : _loadReportingStatus,
                    onRetry: _reportingStatus == null ||
                            _reportingStatus!.pending == 0 ||
                            _transactionSyncing
                        ? null
                        : _retryPendingReportingSync,
                    onHistory: _showReportingHistory,
                  ),
                  const SizedBox(height: 16),
                  _DeviceRecoveryCard(
                    status: _deviceRecoveryStatus,
                    loading: _deviceRecoveryLoading,
                    reprovisioning: _deviceReprovisioningLoading,
                    onVerify: _deviceRecoveryLoading || _deviceReprovisioningLoading
                        ? null
                        : _verifyDeviceIdentity,
                    onReprovision: _deviceRecoveryLoading || _deviceReprovisioningLoading
                        ? null
                        : _reprovisionDevice,
                  ),
                  const SizedBox(height: 16),
                  _DeviceLifecycleCard(
                    status: _deviceLifecycleStatus,
                    loading: _deviceLifecycleLoading,
                    onRefresh: _deviceLifecycleLoading ? null : _loadDeviceLifecycleStatus,
                  ),
                  const SizedBox(height: 16),
                  _InventorySyncCard(
                    status: _inventorySyncStatus,
                    loading: _inventorySyncLoading,
                    syncing: _inventorySyncing,
                    onRefresh: _inventorySyncLoading || _inventorySyncing
                        ? null
                        : _loadInventorySyncStatus,
                    onSync: _inventorySyncLoading || _inventorySyncing
                        ? null
                        : _syncInventoryMovements,
                  ),
                  const SizedBox(height: 16),
                  if (_masterCatalogExists == false) ...[
                    _SyncCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'INITIALIZE MASTER CATALOG',
                      description:
                          'One-time setup: publish this kiosk current catalog to the store database. This is allowed only when the store has no master catalog yet.',
                      buttonLabel: _catalogSyncing
                          ? 'INITIALIZING MASTER...'
                          : 'INITIALIZE MASTER CATALOG',
                      syncing: _catalogSyncing,
                      onPressed: (_catalogSyncing ||
                              _historicalSyncing ||
                              _transactionSyncing ||
                              _restoreSyncing)
                          ? null
                          : _initializeMasterCatalog,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SyncCard(
                    icon: Icons.cloud_upload_outlined,
                    title: 'SYNC LOCAL CATALOG TO MASTER',
                    description:
                        'Publish this kiosk catalog to the store master. The sync is '
                        'version-checked so newer Store Management changes are never '
                        'silently overwritten.',
                    buttonLabel: _catalogSyncing
                        ? 'SYNCING LOCAL CATALOG...'
                        : 'SYNC LOCAL CATALOG TO MASTER',
                    syncing: _catalogSyncing,
                    onPressed: (_masterCatalogExists == true &&
                            (_catalogStatus?.status == CatalogSyncStatus.inSync ||
                                _catalogStatus?.status ==
                                    CatalogSyncStatus.localChangesPending) &&
                            !_catalogSyncing &&
                            !_historicalSyncing &&
                            !_categorySyncing &&
                            !_transactionSyncing &&
                            !_restoreSyncing)
                        ? _syncLocalCatalogToMaster
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(
                    icon: Icons.cloud_download_outlined,
                    title: 'REFRESH PRODUCT CATALOG',
                    description:
                        'Download the latest store master catalog to this kiosk. '
                        'Categories, products, sizes, variants, options, and add-ons '
                        'are synchronized to the local operational copy. The database '
                        'master is never overwritten by this action.',
                    buttonLabel: _catalogSyncing
                        ? 'REFRESHING CATALOG...'
                        : 'REFRESH PRODUCT CATALOG',
                    syncing: _catalogSyncing,
                    onPressed: (_catalogSyncing ||
                            _historicalSyncing ||
                            _categorySyncing ||
                            _transactionSyncing ||
                            _restoreSyncing)
                        ? null
                        : _refreshProductCatalog,
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(
                    icon: Icons.thermostat_outlined,
                    title: 'HISTORICAL DRINK SYNC',
                    description:
                        'Update historical drink temperatures using the current '
                        'product catalog. Only drink temperature data is changed.',
                    buttonLabel: _historicalSyncing
                        ? 'SYNCING HISTORICAL...'
                        : 'SYNC HISTORICAL DRINKS',
                    syncing: _historicalSyncing,
                    onPressed: (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing)
                        ? null
                        : _syncHistoricalDrinks,
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(
                    icon: Icons.category_outlined,
                    title: 'HISTORICAL CATEGORY SYNC',
                    description:
                        'Update historical local transaction categories using the current '
                        'product category. Only category data is changed.',
                    buttonLabel: _categorySyncing
                        ? 'SYNCING CATEGORIES...'
                        : 'SYNC HISTORICAL CATEGORIES',
                    syncing: _categorySyncing,
                    onPressed: (_catalogSyncing ||
                            _historicalSyncing ||
                            _categorySyncing ||
                            _transactionSyncing ||
                            _restoreSyncing)
                        ? null
                        : _syncHistoricalCategories,
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(
                    icon: Icons.cloud_sync_outlined,
                    title: 'REPORTING TRANSACTION SYNC',
                    description:
                        'Send every locally stored kiosk transaction to the '
                        'reporting database using the configured Store ID and '
                        'Device / Kiosk Code.',
                    buttonLabel: _transactionSyncing
                        ? 'SYNCING ALL TRANSACTIONS...'
                        : 'SYNC ALL TRANSACTIONS',
                    syncing: _transactionSyncing,
                    onPressed: (_catalogSyncing || _historicalSyncing || _categorySyncing || _transactionSyncing || _restoreSyncing)
                        ? null
                        : _syncAllTransactions,
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(
                    icon: Icons.cloud_download_outlined,
                    title: 'RESTORE MISSING TRANSACTIONS',
                    description:
                        'Compare the reporting database with this kiosk and '
                        'restore transactions that are missing locally. '
                        'Existing local transactions are never overwritten.',
                    buttonLabel: _restoreSyncing
                        ? 'RESTORING TRANSACTIONS...'
                        : 'RESTORE MISSING TRANSACTIONS',
                    syncing: _restoreSyncing,
                    onPressed: (_catalogSyncing ||
                            _historicalSyncing ||
                            _categorySyncing ||
                            _transactionSyncing ||
                            _restoreSyncing)
                        ? null
                        : _restoreMissingTransactions,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline, color: gold),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Use Historical Drink Sync when historical catalog temperatures need '
                              'correction. Use Historical Category Sync when '
                              'historical transaction categories need correction. '
                              'Use Sync All Transactions to push '
                              'local transaction snapshots to reporting. Use '
                              'Restore Missing Transactions to recover records '
                              'that exist in reporting but are missing locally.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportingStatusCard extends StatelessWidget {
  const _ReportingStatusCard({
    required this.status,
    required this.loading,
    required this.busy,
    required this.onRefresh,
    required this.onRetry,
    required this.onHistory,
  });

  final ReportingSyncOperationalStatus? status;
  final bool loading;
  final bool busy;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final snapshot = status;
    final state = snapshot?.state;
    final title = switch (state) {
      ReportingSyncOperationalState.synced => 'REPORTING SYNCED',
      ReportingSyncOperationalState.pending => 'REPORTING SYNC PENDING',
      ReportingSyncOperationalState.failed => 'REPORTING SYNC FAILED',
      ReportingSyncOperationalState.noTransactions => 'NO REPORTING TRANSACTIONS',
      null => 'CHECKING REPORTING SYNC',
    };
    final message = snapshot == null
        ? 'Checking local reporting synchronization status.'
        : 'Local transaction history remains authoritative. Cloud sync is manual.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync_outlined, size: 34, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh reporting status',
                  onPressed: onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.black54, height: 1.35)),
            if (snapshot != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('Total: ${snapshot.total}'),
                  Text('Synced: ${snapshot.synced}'),
                  Text('Pending: ${snapshot.pending}'),
                  if (snapshot.failed > 0) Text('Last attempt failed: ${snapshot.failed}'),
                  if (snapshot.lastSyncedAt != null)
                    Text('Last synced: ${snapshot.lastSyncedAt}'),
                  if (snapshot.lastAttemptAt != null)
                    Text('Last attempt: ${snapshot.lastAttemptAt}'),
                ],
              ),
              if (snapshot.lastError != null) ...[
                const SizedBox(height: 10),
                Text('Last error: ${snapshot.lastError}', style: const TextStyle(color: Colors.black54)),
              ],
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY PENDING SYNC'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('VIEW SYNC HISTORY'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRecoveryCard extends StatelessWidget {
  const _DeviceRecoveryCard({
    required this.status,
    required this.loading,
    required this.reprovisioning,
    required this.onVerify,
    required this.onReprovision,
  });

  final KioskDeviceRecoveryStatus? status;
  final bool loading;
  final bool reprovisioning;
  final VoidCallback? onVerify;
  final VoidCallback? onReprovision;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final snapshot = status;
    final title = snapshot?.title ?? 'DEVICE RECOVERY READINESS';
    final message = snapshot?.message ??
        'Verify this kiosk Store ID and Device / Kiosk Code before using recovery tools.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_other_outlined, size: 34, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.black54, height: 1.35)),
            if (snapshot?.deviceUuid != null) ...[
              const SizedBox(height: 10),
              SelectableText('Device UUID: ${snapshot!.deviceUuid}'),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onVerify,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(loading ? 'VERIFYING DEVICE...' : 'VERIFY DEVICE IDENTITY'),
                ),
                FilledButton.icon(
                  onPressed: onReprovision,
                  icon: reprovisioning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_outlined),
                  label: Text(
                    reprovisioning ? 'RE-PROVISIONING...' : 'RE-PROVISION REPLACEMENT DEVICE',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceLifecycleCard extends StatelessWidget {
  const _DeviceLifecycleCard({
    required this.status,
    required this.loading,
    required this.onRefresh,
  });

  final KioskDeviceLifecycleStatus? status;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final snapshot = status;
    final title = snapshot?.title ?? 'CHECKING DEVICE LIFECYCLE';
    final message = snapshot?.message ??
        'Checking this kiosk device against Store Management.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined, size: 34, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.black54, height: 1.35)),
            if (snapshot?.deviceUuid != null) ...[
              const SizedBox(height: 10),
              SelectableText('Device UUID: ${snapshot!.deviceUuid}'),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(loading ? 'CHECKING...' : 'REFRESH DEVICE STATUS'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registration, activation, deactivation, and retirement are controlled by Store Management. This kiosk only verifies and records the observed lifecycle state.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventorySyncCard extends StatelessWidget {
  const _InventorySyncCard({
    required this.status,
    required this.loading,
    required this.syncing,
    required this.onRefresh,
    required this.onSync,
  });

  final InventoryMovementSyncStatus? status;
  final bool loading;
  final bool syncing;
  final VoidCallback? onRefresh;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final state = status?.state;
    final label = loading
        ? 'CHECKING INVENTORY SYNC...'
        : switch (state) {
            InventoryMovementSyncState.synced => 'INVENTORY SYNCED',
            InventoryMovementSyncState.pending => 'INVENTORY SYNC PENDING',
            InventoryMovementSyncState.failed => 'INVENTORY SYNC FAILED',
            InventoryMovementSyncState.unavailable => 'INVENTORY SYNC UNAVAILABLE',
            null => 'CHECKING INVENTORY SYNC',
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh inventory sync status',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status == null
                  ? 'Explicitly synchronize locally recorded inventory movements to the inventory database. Local movements remain authoritative and failed movements remain retryable.'
                  : 'Total: ${status!.total}  •  Synced: ${status!.synced}  •  Pending: ${status!.pending}',
              style: const TextStyle(color: Colors.black54),
            ),
            if (status?.lastSuccessAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last successful sync: ${status!.lastSuccessAt}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (status?.lastError != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last error: ${status!.lastError}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(syncing ? 'SYNCING INVENTORY...' : 'SYNC INVENTORY MOVEMENTS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogStatusCard extends StatelessWidget {
  const _CatalogStatusCard({
    required this.status,
    required this.loading,
    required this.onRefresh,
  });

  final CatalogSyncStatusSnapshot? status;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);
    final snapshot = status;
    final title = snapshot?.title ?? 'CHECKING CATALOG STATUS';
    final message = snapshot?.message ??
        'Checking the local kiosk catalog against the store master.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, size: 34, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh catalog status',
                  onPressed: onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('Kiosk version: ${snapshot.localVersion ?? 'Not recorded'}'),
                  Text('Master version: ${snapshot.masterVersion ?? 'Not available'}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.syncing,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool syncing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 34, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon),
                label: Text(buttonLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
