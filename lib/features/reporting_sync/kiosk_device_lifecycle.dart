import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lifecycle state that can be safely observed by a kiosk.
///
/// The current `devices.is_active` flag is the authoritative operational
/// state. Registration, activation, deactivation, and retirement mutations
/// remain Store Management responsibilities.
enum KioskDeviceLifecycleState {
  invalidConfiguration,
  unavailable,
  notFound,
  inactive,
  active,
}

class KioskDeviceLifecycleStatus {
  const KioskDeviceLifecycleStatus({
    required this.state,
    required this.storeId,
    required this.deviceCode,
    this.deviceUuid,
  });

  final KioskDeviceLifecycleState state;
  final String storeId;
  final String deviceCode;
  final String? deviceUuid;

  bool get isOperational => state == KioskDeviceLifecycleState.active;

  String get title {
    switch (state) {
      case KioskDeviceLifecycleState.invalidConfiguration:
        return 'DEVICE IDENTITY NOT CONFIGURED';
      case KioskDeviceLifecycleState.unavailable:
        return 'DEVICE STATUS UNAVAILABLE';
      case KioskDeviceLifecycleState.notFound:
        return 'DEVICE NOT REGISTERED';
      case KioskDeviceLifecycleState.inactive:
        return 'DEVICE INACTIVE';
      case KioskDeviceLifecycleState.active:
        return 'DEVICE ACTIVE';
    }
  }

  String get message {
    switch (state) {
      case KioskDeviceLifecycleState.invalidConfiguration:
        return 'A valid Store ID and Device / Kiosk Code are required to check device lifecycle status.';
      case KioskDeviceLifecycleState.unavailable:
        return 'The kiosk could not verify device lifecycle status. No lifecycle change is assumed.';
      case KioskDeviceLifecycleState.notFound:
        return 'This Store ID and Device / Kiosk Code are not registered together in Store Management.';
      case KioskDeviceLifecycleState.inactive:
        return 'This device is registered but inactive. Device lifecycle changes must be completed in Store Management before this kiosk is used for reporting synchronization.';
      case KioskDeviceLifecycleState.active:
        return 'This kiosk is registered and active. Device lifecycle changes remain controlled by Store Management.';
    }
  }

  static KioskDeviceLifecycleStatus fromResponse({
    required String storeId,
    required String deviceCode,
    required Map<String, dynamic>? response,
  }) {
    final normalizedStoreId = storeId.trim();
    final normalizedDeviceCode = deviceCode.trim();
    if (normalizedStoreId.isEmpty || normalizedDeviceCode.isEmpty) {
      return KioskDeviceLifecycleStatus(
        state: KioskDeviceLifecycleState.invalidConfiguration,
        storeId: normalizedStoreId,
        deviceCode: normalizedDeviceCode,
      );
    }
    if (response == null || response['found'] != true) {
      return KioskDeviceLifecycleStatus(
        state: KioskDeviceLifecycleState.notFound,
        storeId: normalizedStoreId,
        deviceCode: normalizedDeviceCode,
      );
    }

    final uuid = response['deviceId']?.toString().trim();
    return KioskDeviceLifecycleStatus(
      state: response['isActive'] == true
          ? KioskDeviceLifecycleState.active
          : KioskDeviceLifecycleState.inactive,
      storeId: normalizedStoreId,
      deviceCode: normalizedDeviceCode,
      deviceUuid: uuid == null || uuid.isEmpty ? null : uuid,
    );
  }
}

class KioskDeviceLifecycleAuditEntry {
  const KioskDeviceLifecycleAuditEntry({
    required this.createdAt,
    required this.storeId,
    required this.deviceCode,
    required this.state,
    this.deviceUuid,
  });

  final DateTime createdAt;
  final String storeId;
  final String deviceCode;
  final KioskDeviceLifecycleState state;
  final String? deviceUuid;

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'storeId': storeId,
        'deviceCode': deviceCode,
        'state': state.name,
        'deviceUuid': deviceUuid,
      };

  static KioskDeviceLifecycleAuditEntry fromJson(Map<String, dynamic> json) {
    final stateName = json['state']?.toString();
    final state = KioskDeviceLifecycleState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => KioskDeviceLifecycleState.invalidConfiguration,
    );
    final uuid = json['deviceUuid']?.toString().trim();
    return KioskDeviceLifecycleAuditEntry(
      createdAt: DateTime.parse(json['createdAt'].toString()),
      storeId: json['storeId']?.toString() ?? '',
      deviceCode: json['deviceCode']?.toString() ?? '',
      state: state,
      deviceUuid: uuid == null || uuid.isEmpty ? null : uuid,
    );
  }
}

class KioskDeviceLifecycleAuditRepository {
  static const _key = 'bigger_brew_kiosk.device_lifecycle_audit.v1';
  static const _maxEntries = 20;

  Future<List<KioskDeviceLifecycleAuditEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final entries = <KioskDeviceLifecycleAuditEntry>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          entries.add(KioskDeviceLifecycleAuditEntry.fromJson(decoded));
        }
      } catch (_) {
        // Ignore corrupt historical observations.
      }
    }
    return entries;
  }

  Future<void> append(KioskDeviceLifecycleAuditEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final updated = <KioskDeviceLifecycleAuditEntry>[entry, ...current];
    await prefs.setStringList(
      _key,
      updated
          .take(_maxEntries)
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false),
    );
  }
}
