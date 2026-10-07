import 'package:shared_preferences/shared_preferences.dart';

class AutomaticTransactionSyncSettings {
  const AutomaticTransactionSyncSettings({
    this.enabled = true,
    this.morning = '08:00',
    this.afternoon = '14:00',
    this.evening = '22:00',
    this.retryMinutes = 15,
    this.wifiOnly = false,
  });

  final bool enabled;
  final String morning;
  final String afternoon;
  final String evening;
  final int retryMinutes;
  final bool wifiOnly;

  List<({int hour, int minute, String name})> get schedule => [
        _slot(morning, 'morning'),
        _slot(afternoon, 'afternoon'),
        _slot(evening, 'evening'),
      ];

  static ({int hour, int minute, String name}) _slot(String time, String name) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour: hour.clamp(0, 23).toInt(), minute: minute.clamp(0, 59).toInt(), name: name);
  }
}

class AutomaticTransactionSyncSettingsRepository {
  static const _enabledKey = 'automatic_transaction_sync_enabled';
  static const _morningKey = 'automatic_transaction_sync_morning';
  static const _afternoonKey = 'automatic_transaction_sync_afternoon';
  static const _eveningKey = 'automatic_transaction_sync_evening';
  static const _retryKey = 'automatic_transaction_sync_retry_minutes';
  static const _wifiOnlyKey = 'automatic_transaction_sync_wifi_only';

  Future<AutomaticTransactionSyncSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AutomaticTransactionSyncSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      morning: prefs.getString(_morningKey) ?? '08:00',
      afternoon: prefs.getString(_afternoonKey) ?? '14:00',
      evening: prefs.getString(_eveningKey) ?? '22:00',
      retryMinutes: prefs.getInt(_retryKey) ?? 15,
      wifiOnly: prefs.getBool(_wifiOnlyKey) ?? false,
    );
  }

  Future<void> save(AutomaticTransactionSyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setString(_morningKey, settings.morning);
    await prefs.setString(_afternoonKey, settings.afternoon);
    await prefs.setString(_eveningKey, settings.evening);
    await prefs.setInt(_retryKey, settings.retryMinutes);
    await prefs.setBool(_wifiOnlyKey, settings.wifiOnly);
  }
}
