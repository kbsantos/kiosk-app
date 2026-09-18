import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class InventoryMovementSyncStore {
  static const _key = 'bigger_brew_kiosk.inventory_movement_sync.v1';
  static const _lastAttemptKey = 'bigger_brew_kiosk.inventory_movement_sync.last_attempt.v1';
  static const _lastSuccessKey = 'bigger_brew_kiosk.inventory_movement_sync.last_success.v1';
  static const _lastErrorKey = 'bigger_brew_kiosk.inventory_movement_sync.last_error.v1';

  const InventoryMovementSyncStore();

  Future<bool> isSynced(String localMovementId) async {
    final ids = await _loadIds();
    return ids.contains(localMovementId);
  }

  Future<Set<String>> loadSyncedIds() => _loadIds();

  Future<void> markSynced(Iterable<String> ids) async {
    final normalized = ids.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final all = await _loadIds();
    all.addAll(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.toList()..sort()));
  }

  Future<void> recordAttempt({required DateTime at}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAttemptKey, at.toUtc().toIso8601String());
  }

  Future<void> recordSuccess({required DateTime at}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSuccessKey, at.toUtc().toIso8601String());
    await prefs.remove(_lastErrorKey);
  }

  Future<void> recordFailure(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastErrorKey, message);
  }

  Future<DateTime?> lastAttemptAt() async => _readDate(_lastAttemptKey);
  Future<DateTime?> lastSuccessAt() async => _readDate(_lastSuccessKey);

  Future<String?> lastError() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastErrorKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<Set<String>> _loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((value) => value.toString()).where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<DateTime?> _readDate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
