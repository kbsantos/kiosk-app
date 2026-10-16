import 'package:shared_preferences/shared_preferences.dart';

class TransactionRetentionSettings {
  const TransactionRetentionSettings({
    this.automaticPurgeEnabled = false,
    this.retentionDays = 90,
  });

  final bool automaticPurgeEnabled;
  final int retentionDays;

  TransactionRetentionSettings copyWith({
    bool? automaticPurgeEnabled,
    int? retentionDays,
  }) =>
      TransactionRetentionSettings(
        automaticPurgeEnabled:
            automaticPurgeEnabled ?? this.automaticPurgeEnabled,
        retentionDays: retentionDays ?? this.retentionDays,
      );
}

class TransactionRetentionSettingsRepository {
  static const _enabledKey = 'transaction_retention_auto_purge_enabled';
  static const _daysKey = 'transaction_retention_days';
  static const lastPurgeAtKey = 'transaction_retention_last_purge_at';
  static const lastPurgeCountKey = 'transaction_retention_last_purge_count';

  Future<TransactionRetentionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(_daysKey) ?? 90;
    return TransactionRetentionSettings(
      automaticPurgeEnabled: prefs.getBool(_enabledKey) ?? false,
      retentionDays: const [30, 60, 90, 180, 365].contains(days) ? days : 90,
    );
  }

  Future<void> save(TransactionRetentionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.automaticPurgeEnabled);
    await prefs.setInt(_daysKey, settings.retentionDays);
  }

  Future<DateTime?> lastPurgeAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(lastPurgeAtKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<int> lastPurgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(lastPurgeCountKey) ?? 0;
  }

  Future<void> recordPurge(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastPurgeAtKey, DateTime.now().toIso8601String());
    await prefs.setInt(lastPurgeCountKey, count);
  }
}
