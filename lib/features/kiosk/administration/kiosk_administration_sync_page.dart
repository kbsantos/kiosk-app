import 'package:flutter/material.dart';

import '../orders/kiosk_order_repository.dart';
import '../../reporting_sync/reporting_sync_result.dart';
import '../../reporting_sync/reporting_sync_service.dart';
import '../../reporting_sync/automatic_transaction_sync_settings.dart';
import '../../reporting_sync/reporting_sync_status_store.dart';
import '../../reporting_sync/transaction_retention_settings.dart';
import '../../catalog/store_catalog_sync_service.dart';

/// Administrative synchronization tools.
///
/// Historical drink-temperature synchronization updates the local kiosk
/// transaction snapshots. The full transaction sync then sends the current
/// local snapshots to the reporting database.
class KioskAdministrationSyncPage extends StatefulWidget {
  const KioskAdministrationSyncPage({super.key});

  @override
  State<KioskAdministrationSyncPage> createState() =>
      _KioskAdministrationSyncPageState();
}

class _KioskAdministrationSyncPageState
    extends State<KioskAdministrationSyncPage> {
  final KioskOrderRepository _orderRepository = KioskOrderRepository();
  final ReportingSyncService _reportingSyncService = ReportingSyncService();
  final StoreCatalogSyncService _catalogSyncService = StoreCatalogSyncService();
  final AutomaticTransactionSyncSettingsRepository _autoSyncSettingsRepository =
      AutomaticTransactionSyncSettingsRepository();
  AutomaticTransactionSyncSettings _autoSyncSettings =
      const AutomaticTransactionSyncSettings();
  bool _autoSyncSettingsLoading = true;
  bool _autoSyncSettingsSaving = false;
  final TransactionRetentionSettingsRepository _retentionRepository =
      TransactionRetentionSettingsRepository();
  final ReportingSyncStatusStore _syncStatusStore = ReportingSyncStatusStore();

  bool _catalogSyncing = false;
  bool _historicalSyncing = false;
  bool _transactionSyncing = false;
  bool _restoreSyncing = false;
  int _transactionSyncCompleted = 0;
  int _transactionSyncTotal = 0;
  int _transactionSyncChecked = 0;
  int _transactionSyncCheckTotal = 0;
  bool _transactionSyncPreparing = true;
  bool? _masterCatalogExists;

  @override
  void initState() {
    super.initState();
    _checkMasterCatalog();
    _loadAutoSyncSettings();
  }

  static const _syncTimeOptions = <String>[
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
  ];

  Future<void> _loadAutoSyncSettings() async {
    try {
      final settings = await _autoSyncSettingsRepository.load();
      if (mounted) {
        setState(() {
          _autoSyncSettings = settings;
          _autoSyncSettingsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _autoSyncSettingsLoading = false);
    }
  }

  Future<void> _saveAutoSyncSettings(
      AutomaticTransactionSyncSettings settings) async {
    final minutes = settings.schedule
        .map((slot) => slot.hour * 60 + slot.minute)
        .toList()
      ..sort();
    if (minutes.toSet().length != 3 ||
        settings.schedule[0].hour * 60 + settings.schedule[0].minute !=
            minutes[0] ||
        settings.schedule[1].hour * 60 + settings.schedule[1].minute !=
            minutes[1]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Choose three different times in morning-to-evening order.')),
      );
      return;
    }
    setState(() {
      _autoSyncSettings = settings;
      _autoSyncSettingsSaving = true;
    });
    try {
      await _autoSyncSettingsRepository.save(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Automatic transaction sync settings saved.')),
        );
      }
    } catch (error) {
      if (mounted) await _showError('COULD NOT SAVE SYNC SETTINGS', error);
    } finally {
      if (mounted) setState(() => _autoSyncSettingsSaving = false);
    }
  }

  String _formatSyncTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Widget _buildAutomaticSyncSettingsCard() {
    final settings = _autoSyncSettings;
    Widget timeDropdown(
        String label, String value, ValueChanged<String?> onChanged) {
      return DropdownButtonFormField<String>(
        initialValue: _syncTimeOptions.contains(value) ? value : '08:00',
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: _syncTimeOptions
            .map((time) => DropdownMenuItem(
                  value: time,
                  child: Text(_formatSyncTime(time)),
                ))
            .toList(),
        onChanged: _autoSyncSettingsSaving ? null : onChanged,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.schedule, color: Color(0xFFC69214)),
              SizedBox(width: 10),
              Expanded(
                  child: Text('AUTOMATIC TRANSACTION SYNC',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Configure three daily attempts. Settings are saved locally on this kiosk. Scheduled sync runs while the app is running or resumes.',
                style: TextStyle(color: Colors.black54)),
            if (_autoSyncSettingsLoading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable automatic sync'),
                subtitle: Text(settings.enabled
                    ? 'Scheduled uploads are enabled'
                    : 'Only manual sync is available'),
                value: settings.enabled,
                onChanged: _autoSyncSettingsSaving
                    ? null
                    : (enabled) =>
                        _saveAutoSyncSettings(AutomaticTransactionSyncSettings(
                          enabled: enabled,
                          morning: settings.morning,
                          afternoon: settings.afternoon,
                          evening: settings.evening,
                          retryMinutes: settings.retryMinutes,
                          wifiOnly: settings.wifiOnly,
                        )),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: timeDropdown('Morning', settings.morning, (value) {
                  if (value != null) {
                    _saveAutoSyncSettings(AutomaticTransactionSyncSettings(
                        enabled: settings.enabled,
                        morning: value,
                        afternoon: settings.afternoon,
                        evening: settings.evening,
                        retryMinutes: settings.retryMinutes,
                        wifiOnly: settings.wifiOnly));
                  }
                })),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        timeDropdown('Afternoon', settings.afternoon, (value) {
                  if (value != null) {
                    _saveAutoSyncSettings(AutomaticTransactionSyncSettings(
                        enabled: settings.enabled,
                        morning: settings.morning,
                        afternoon: value,
                        evening: settings.evening,
                        retryMinutes: settings.retryMinutes,
                        wifiOnly: settings.wifiOnly));
                  }
                })),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: timeDropdown('Evening', settings.evening, (value) {
                  if (value != null) {
                    _saveAutoSyncSettings(AutomaticTransactionSyncSettings(
                        enabled: settings.enabled,
                        morning: settings.morning,
                        afternoon: settings.afternoon,
                        evening: value,
                        retryMinutes: settings.retryMinutes,
                        wifiOnly: settings.wifiOnly));
                  }
                })),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<int>(
                  initialValue: settings.retryMinutes,
                  decoration: const InputDecoration(
                      labelText: 'Retry interval',
                      border: OutlineInputBorder()),
                  items: <int>[5, 15, 30, 60]
                      .map((minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text('$minutes minutes'),
                          ))
                      .toList(),
                  onChanged: _autoSyncSettingsSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            _saveAutoSyncSettings(
                                AutomaticTransactionSyncSettings(
                                    enabled: settings.enabled,
                                    morning: settings.morning,
                                    afternoon: settings.afternoon,
                                    evening: settings.evening,
                                    retryMinutes: value,
                                    wifiOnly: settings.wifiOnly));
                          }
                        },
                )),
              ]),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sync only over Wi-Fi'),
                subtitle: const Text(
                    'When enabled, scheduled sync waits until Wi-Fi is connected.'),
                value: settings.wifiOnly,
                onChanged: _autoSyncSettingsSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          _saveAutoSyncSettings(
                              AutomaticTransactionSyncSettings(
                                  enabled: settings.enabled,
                                  morning: settings.morning,
                                  afternoon: settings.afternoon,
                                  evening: settings.evening,
                                  retryMinutes: settings.retryMinutes,
                                  wifiOnly: value));
                        }
                      },
              ),
              if (_autoSyncSettingsSaving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 8),
              const Text(
                  'Times use the kiosk device’s local time. Android may delay background work; this scheduler checks while the app is running.',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
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
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
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
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
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
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
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
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
      return;
    }

    setState(() => _historicalSyncing = true);

    try {
      final preview =
          await _orderRepository.syncHistoricalDrinkTemperatures(dryRun: true);

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

      final result = await _orderRepository.syncHistoricalDrinkTemperatures();

      if (!mounted) return;

      await _showMessage(
        title: 'HISTORICAL SYNC COMPLETE',
        message: '${result.updatedItems} drink item(s) updated across '
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

  Future<void> _syncAllTransactions() async {
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
      return;
    }

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

    setState(() {
      _transactionSyncing = true;
      _transactionSyncCompleted = 0;
      _transactionSyncTotal = 0;
      _transactionSyncChecked = 0;
      _transactionSyncCheckTotal = 0;
      _transactionSyncPreparing = true;
    });

    try {
      final result = await _reportingSyncService.syncAllTransactions(
        onPreparationProgress: (checked, total) {
          if (!mounted) return;
          setState(() {
            _transactionSyncPreparing = true;
            _transactionSyncChecked = checked;
            _transactionSyncCheckTotal = total;
          });
        },
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _transactionSyncPreparing = false;
            _transactionSyncCompleted = completed;
            _transactionSyncTotal = total;
          });
        },
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final retention = await _retentionRepository.load();
        if (retention.automaticPurgeEnabled) {
          final removed = await _orderRepository.purgeOldSyncedTransactions(
            olderThan: DateTime.now().subtract(
              Duration(days: retention.retentionDays),
            ),
            statusStore: _syncStatusStore,
          );
          await _retentionRepository.recordPurge(removed);
        }
      }
      await _showReportingResult(result);
    } catch (error) {
      if (!mounted) return;
      await _showError('TRANSACTION SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _transactionSyncing = false);
    }
  }

  Future<void> _restoreMissingTransactions() async {
    if (_catalogSyncing ||
        _historicalSyncing ||
        _transactionSyncing ||
        _restoreSyncing) {
      return;
    }

    setState(() => _restoreSyncing = true);

    try {
      final preview = await _reportingSyncService.previewMissingTransactions();

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

    return Stack(
      children: [
        Scaffold(
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
                                !_catalogSyncing &&
                                !_historicalSyncing &&
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
                        onPressed: (_catalogSyncing ||
                                _historicalSyncing ||
                                _transactionSyncing ||
                                _restoreSyncing)
                            ? null
                            : _syncHistoricalDrinks,
                      ),
                      const SizedBox(height: 16),
                      _buildAutomaticSyncSettingsCard(),
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
                        onPressed: (_catalogSyncing ||
                                _historicalSyncing ||
                                _transactionSyncing ||
                                _restoreSyncing)
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
                        onPressed: (_historicalSyncing ||
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
                                  'correction. Use Sync All Transactions to push '
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
        ),
        if (_transactionSyncing)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      elevation: 12,
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 52,
                              height: 52,
                              child: CircularProgressIndicator(strokeWidth: 5),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'SYNCING TRANSACTIONS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Please wait while locally stored transactions are sent to the reporting database. Keep this screen open.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            if (_transactionSyncPreparing) ...[
                              LinearProgressIndicator(
                                value: _transactionSyncCheckTotal > 0
                                    ? _transactionSyncChecked /
                                        _transactionSyncCheckTotal
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _transactionSyncCheckTotal > 0
                                    ? 'Checking $_transactionSyncChecked of '
                                        '$_transactionSyncCheckTotal local transactions…'
                                    : 'Loading local transactions…',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else if (_transactionSyncTotal > 0) ...[
                              LinearProgressIndicator(
                                value: _transactionSyncCompleted /
                                    _transactionSyncTotal,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_transactionSyncCompleted of '
                                '$_transactionSyncTotal pending transactions processed',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else
                              const Text(
                                'No pending transactions. Finishing…',
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
