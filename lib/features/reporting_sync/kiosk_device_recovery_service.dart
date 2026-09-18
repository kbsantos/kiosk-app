import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'kiosk_device_recovery.dart';

class KioskDeviceRecoveryService {
  const KioskDeviceRecoveryService();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  Future<KioskDeviceRecoveryStatus> verify({
    required String storeId,
    required String deviceCode,
  }) async {
    final normalizedStoreId = storeId.trim();
    final normalizedDeviceCode = deviceCode.trim();

    if (!SupabaseConfig.isConfigured ||
        !_uuidPattern.hasMatch(normalizedStoreId) ||
        normalizedDeviceCode.isEmpty) {
      return KioskDeviceRecoveryStatus(
        state: KioskDeviceRecoveryState.invalidConfiguration,
        storeId: normalizedStoreId,
        deviceCode: normalizedDeviceCode,
      );
    }

    final response = await Supabase.instance.client.rpc(
      'get_kiosk_device_recovery_status',
      params: {
        'p_store_id': normalizedStoreId,
        'p_device_code': normalizedDeviceCode,
      },
    );

    final map = response is Map
        ? Map<String, dynamic>.from(response)
        : null;
    return KioskDeviceRecoveryStatus.fromResponse(
      storeId: normalizedStoreId,
      deviceCode: normalizedDeviceCode,
      response: map,
    );
  }
}
