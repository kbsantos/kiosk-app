import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reporting_sync_service.dart';
import 'automatic_transaction_sync_settings.dart';
import '../kiosk/orders/kiosk_order_repository.dart';
import 'reporting_sync_status_store.dart';
import 'transaction_retention_settings.dart';

/// Runs reporting sync at the locally configured daily times while the kiosk
/// app is running. A due slot is retried using the configured interval until
/// it succeeds. Local orders remain the source of truth.
class AutomaticTransactionSyncScheduler with WidgetsBindingObserver {
  AutomaticTransactionSyncScheduler({ReportingSyncService? syncService})
      : _syncService = syncService ?? ReportingSyncService();

  final ReportingSyncService _syncService;
  final AutomaticTransactionSyncSettingsRepository _settingsRepository =
      AutomaticTransactionSyncSettingsRepository();
  final TransactionRetentionSettingsRepository _retentionSettingsRepository =
      TransactionRetentionSettingsRepository();
  final KioskOrderRepository _orderRepository = KioskOrderRepository();
  final ReportingSyncStatusStore _statusStore = ReportingSyncStatusStore();
  Timer? _timer;
  bool _checking = false;
  bool _syncing = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await checkNow();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(checkNow());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }

  Future<void> checkNow() async {
    if (_checking || _syncing) return;
    _checking = true;
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final settings = await _settingsRepository.load();
      if (!settings.enabled) return;
      if (settings.wifiOnly) {
        final connectivity = await Connectivity().checkConnectivity();
        if (!connectivity.contains(ConnectivityResult.wifi)) return;
      }
      final retryInterval = Duration(minutes: settings.retryMinutes);
      for (final slot in settings.schedule) {
        final due =
            DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
        if (now.isBefore(due)) continue;

        final dayKey = '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final slotKey = 'automatic_reporting_sync_${slot.name}_$dayKey';
        if (prefs.getBool(slotKey) == true) continue;

        final attemptKey = '${slotKey}_last_attempt_ms';
        final lastAttempt = prefs.getInt(attemptKey);
        if (lastAttempt != null &&
            now.millisecondsSinceEpoch - lastAttempt <
                retryInterval.inMilliseconds) {
          continue;
        }

        _syncing = true;
        await prefs.setInt(attemptKey, now.millisecondsSinceEpoch);
        try {
          final result = await _syncService.syncAllTransactions();
          if (result.isSuccess) {
            await prefs.setBool(slotKey, true);
            await prefs.remove(attemptKey);
            final retention = await _retentionSettingsRepository.load();
            if (retention.automaticPurgeEnabled) {
              final removed = await _orderRepository.purgeOldSyncedTransactions(
                olderThan: DateTime.now().subtract(
                  Duration(days: retention.retentionDays),
                ),
                statusStore: _statusStore,
              );
              await _retentionSettingsRepository.recordPurge(removed);
              debugPrint('Automatic transaction retention purge removed $removed local transaction(s).');
            }
            debugPrint(
                'Automatic transaction sync (${slot.name}) complete: ${result.summary}.');
          } else {
            debugPrint(
                'Automatic transaction sync (${slot.name}) incomplete: ${result.summary}. Will retry.');
          }
        } catch (error, stackTrace) {
          debugPrint(
              'Automatic transaction sync (${slot.name}) failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        } finally {
          _syncing = false;
        }
        // At most one scheduled attempt at a time; the next due slot will be
        // considered by the next one-minute check.
        break;
      }
    } catch (error, stackTrace) {
      debugPrint('Automatic transaction sync scheduler error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
