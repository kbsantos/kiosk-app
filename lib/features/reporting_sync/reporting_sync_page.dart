import 'package:flutter/material.dart';

import '../../core/config/supabase_config.dart';
import 'reporting_sync_result.dart';
import 'reporting_sync_service.dart';
import 'reporting_sync_status.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';

/// Production manual reporting sync page.
///
/// Local kiosk transactions remain the source of truth. Sync is always an
/// explicit staff action; no background or automatic synchronization occurs.
class ReportingSyncPage extends StatefulWidget {
  const ReportingSyncPage({super.key});

  @override
  State<ReportingSyncPage> createState() => _ReportingSyncPageState();
}

class _ReportingSyncPageState extends State<ReportingSyncPage> {
  final _service = ReportingSyncService();
  final _settingsRepository = KioskSettingsRepository();

  bool _loading = false;
  late Future<KioskSettings> _settingsFuture;
  late Future<ReportingSyncProgress> _todayFuture;
  late Future<ReportingSyncProgress> _allFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _todayFuture = _service.getTodayProgress();
    _allFuture = _service.getFullProgress();
    _settingsFuture = _settingsRepository.load();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _sync({required bool all}) async {
    final scope = all ? 'ALL PENDING TRANSACTIONS' : 'TODAY\'S PENDING TRANSACTIONS';
    final description = all
        ? 'This sends every pending or changed local kiosk transaction to the MyCoffeeShop reporting database.'
        : 'This sends only today\'s pending or changed local kiosk transactions to the MyCoffeeShop reporting database.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('SYNC $scope'),
        content: Text(
          '$description\n\n'
          'Already-synced transactions are skipped unless their local order data has changed. '
          'Local kiosk transactions are never modified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('SYNC PENDING'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = all
          ? await _service.fullSync()
          : await _service.syncToday();
      if (!mounted) return;
      await _showResult(result);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('REPORTING SYNC FAILED'),
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
        title: Text(
          result.isSuccess ? 'REPORTING SYNC COMPLETE' : 'REPORTING SYNC FINISHED',
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
        title: const Text('REPORTING SYNC'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_sync_outlined, size: 72, color: gold),
                  const SizedBox(height: 16),
                  const Text(
                    'REPORTING SYNC',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manually send pending kiosk transactions to the MyCoffeeShop reporting database. '
                    'Local kiosk data remains the source of truth.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  _StatusCard(
                    label: 'SUPABASE CONFIGURATION',
                    value: SupabaseConfig.isConfigured ? 'Configured' : 'Not configured',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<KioskSettings>(
                    future: _settingsFuture,
                    builder: (context, snapshot) {
                      final settings = snapshot.data;
                      final configured = settings != null &&
                          settings.storeId.trim().isNotEmpty &&
                          settings.deviceId.trim().isNotEmpty;
                      return _StatusCard(
                        label: 'REPORTING STORE / DEVICE',
                        value: configured
                            ? '${settings.storeId} / ${settings.deviceId}'
                            : 'Missing Store ID or Device / Kiosk Code',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ProgressSection(
                    title: 'TODAY',
                    future: _todayFuture,
                    formatDateTime: _formatDateTime,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _sync(all: false),
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: Text(_loading ? 'SYNCING...' : 'SYNC PENDING TODAY'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 20),
                  _ProgressSection(
                    title: 'ALL LOCAL TRANSACTIONS',
                    future: _allFuture,
                    formatDateTime: _formatDateTime,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _sync(all: true),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('SYNC ALL PENDING'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Manual sync only. No automatic or background sync is enabled.',
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

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.title,
    required this.future,
    required this.formatDateTime,
  });

  final String title;
  final Future<ReportingSyncProgress> future;
  final String Function(DateTime?) formatDateTime;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportingSyncProgress>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _StatusCard(label: title, value: 'Loading...');
        }
        final progress = snapshot.data;
        if (progress == null) {
          return _StatusCard(label: title, value: 'Unavailable');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            const SizedBox(height: 10),
            _StatusCard(label: 'LOCAL TRANSACTIONS', value: '${progress.total}'),
            const SizedBox(height: 10),
            _StatusCard(label: 'PENDING SYNC', value: '${progress.pending}'),
            const SizedBox(height: 10),
            _StatusCard(label: 'SYNCED', value: '${progress.synced}'),
            const SizedBox(height: 10),
            _StatusCard(label: 'LAST SUCCESSFUL SYNC', value: formatDateTime(progress.lastSyncedAt)),
          ],
        );
      },
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
