import 'package:flutter/material.dart';

import '../orders/kiosk_order_repository.dart';
import '../../reporting_sync/reporting_sync_result.dart';
import '../../reporting_sync/reporting_sync_service.dart';

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

  bool _historicalSyncing = false;
  bool _transactionSyncing = false;
  bool _restoreSyncing = false;

  Future<void> _syncHistoricalDrinks() async {
    if (_historicalSyncing || _transactionSyncing) return;

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

  Future<void> _syncAllTransactions() async {
    if (_historicalSyncing || _transactionSyncing) return;

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

      await _showReportingResult(result);
    } catch (error) {
      if (!mounted) return;
      await _showError('TRANSACTION SYNC FAILED', error);
    } finally {
      if (mounted) setState(() => _transactionSyncing = false);
    }
  }

  Future<void> _restoreMissingTransactions() async {
    if (_historicalSyncing || _transactionSyncing || _restoreSyncing) return;

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
                    onPressed: (_historicalSyncing || _transactionSyncing)
                        ? null
                        : _syncHistoricalDrinks,
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
                    onPressed: (_historicalSyncing || _transactionSyncing)
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
