import 'package:flutter/material.dart';

import '../../core/config/supabase_config.dart';
import 'reporting_sync_result.dart';
import 'reporting_sync_service.dart';
import 'reporting_sync_status.dart';

/// Temporary DB-10A validation screen.
///
/// DB-10A adds local-only sync acknowledgement tracking. Kiosk orders remain
/// untouched; successful reporting sync metadata is stored separately.
class ReportingSyncTestPage extends StatefulWidget {
  const ReportingSyncTestPage({super.key});

  @override
  State<ReportingSyncTestPage> createState() => _ReportingSyncTestPageState();
}

class _ReportingSyncTestPageState extends State<ReportingSyncTestPage> {
  final _service = ReportingSyncService();

  bool _loading = false;
  late Future<ReportingSyncProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _service.getTodayProgress();
  }

  Future<void> _refreshProgress() async {
    if (!mounted) return;
    setState(() {
      _progressFuture = _service.getTodayProgress();
    });
  }

  Future<void> _syncToday() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SYNC PENDING TRANSACTIONS'),
        content: const Text(
          'This sends only today\'s pending or changed local kiosk '
          'transactions to the MyCoffeeShop Supabase reporting database.\n\n'
          'Already-synced transactions are skipped unless their local order '
          'data has changed. Local kiosk transactions are never modified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SYNC PENDING'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      final result = await _service.syncToday();
      if (!mounted) return;
      await _showResult(result);
      await _refreshProgress();
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('REPORTING SYNC FAILED'),
          content: SelectableText(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResult(ReportingSyncResult result) {
    final details = result.attempted == 0
        ? 'There are no pending transactions to sync.'
        : result.failures.isEmpty
            ? 'All attempted transactions were synced successfully.'
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
        title: Text(result.isSuccess
            ? 'REPORTING SYNC COMPLETE'
            : 'REPORTING SYNC FINISHED'),
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

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Never';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC69214);

    return Scaffold(
      appBar: AppBar(
        title: const Text('REPORTING SYNC TEST'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_sync_outlined,
                    size: 72,
                    color: gold,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'DB-10A SYNC STATUS TRACKING',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Successful reporting syncs are tracked separately from '
                    'local kiosk transactions. A changed transaction becomes '
                    'pending automatically and will be sent again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  _StatusCard(
                    label: 'SUPABASE CONFIGURATION',
                    value: SupabaseConfig.isConfigured
                        ? 'Configured'
                        : 'Not configured',
                  ),
                  const SizedBox(height: 12),
                  _StatusCard(
                    label: 'REPORTING STORE / DEVICE',
                    value: SupabaseConfig.storeId.isNotEmpty &&
                            SupabaseConfig.deviceId.isNotEmpty
                        ? 'Configured'
                        : 'Missing store or device ID',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<ReportingSyncProgress>(
                    future: _progressFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _StatusCard(
                          label: 'TODAY\'S SYNC STATUS',
                          value: 'Loading...',
                        );
                      }
                      final progress = snapshot.data;
                      if (progress == null) {
                        return const _StatusCard(
                          label: 'TODAY\'S SYNC STATUS',
                          value: 'Unavailable',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatusCard(
                            label: 'TODAY\'S LOCAL TRANSACTIONS',
                            value: '${progress.total}',
                          ),
                          const SizedBox(height: 12),
                          _StatusCard(
                            label: 'PENDING SYNC',
                            value: '${progress.pending}',
                          ),
                          const SizedBox(height: 12),
                          _StatusCard(
                            label: 'SYNCED',
                            value: '${progress.synced}',
                          ),
                          const SizedBox(height: 12),
                          _StatusCard(
                            label: 'LAST SUCCESSFUL SYNC',
                            value: _formatDateTime(progress.lastSyncedAt),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _loading ? null : _syncToday,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _loading ? 'SYNCING...' : 'SYNC PENDING TODAY',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DB-10A only. No automatic or background sync is enabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 12),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
