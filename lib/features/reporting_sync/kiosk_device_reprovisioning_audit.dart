import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class KioskDeviceReprovisioningAuditEntry {
  const KioskDeviceReprovisioningAuditEntry({
    required this.createdAt,
    required this.previousStoreId,
    required this.previousDeviceCode,
    required this.targetStoreId,
    required this.targetDeviceCode,
    required this.catalogRefreshed,
  });

  final DateTime createdAt;
  final String previousStoreId;
  final String previousDeviceCode;
  final String targetStoreId;
  final String targetDeviceCode;
  final bool catalogRefreshed;

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'previousStoreId': previousStoreId,
        'previousDeviceCode': previousDeviceCode,
        'targetStoreId': targetStoreId,
        'targetDeviceCode': targetDeviceCode,
        'catalogRefreshed': catalogRefreshed,
      };

  static KioskDeviceReprovisioningAuditEntry fromJson(
    Map<String, dynamic> json,
  ) {
    return KioskDeviceReprovisioningAuditEntry(
      createdAt: DateTime.parse(json['createdAt'].toString()),
      previousStoreId: json['previousStoreId']?.toString() ?? '',
      previousDeviceCode: json['previousDeviceCode']?.toString() ?? '',
      targetStoreId: json['targetStoreId']?.toString() ?? '',
      targetDeviceCode: json['targetDeviceCode']?.toString() ?? '',
      catalogRefreshed: json['catalogRefreshed'] == true,
    );
  }
}

class KioskDeviceReprovisioningAuditRepository {
  static const _key = 'bigger_brew_kiosk.device_reprovision_audit.v1';
  static const _maxEntries = 20;

  Future<List<KioskDeviceReprovisioningAuditEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final entries = <KioskDeviceReprovisioningAuditEntry>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          entries.add(KioskDeviceReprovisioningAuditEntry.fromJson(decoded));
        }
      } catch (_) {
        // Ignore a corrupt historical audit item and retain valid entries.
      }
    }
    return entries;
  }

  Future<void> append(KioskDeviceReprovisioningAuditEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final updated = <KioskDeviceReprovisioningAuditEntry>[entry, ...current];
    final bounded = updated.take(_maxEntries).map(
          (item) => jsonEncode(item.toJson()),
        ).toList(growable: false);
    await prefs.setStringList(_key, bounded);
  }
}
